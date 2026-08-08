//
//  applesilicon_hardware_reader.m
//  MenuMeters
//
//  Created by Yuji on 1/25/21.
//  Updated for modern Apple Silicon (M1–M4): prefer PMU die sensors over missing
//  legacy "SOC MTR Temp Sensor*" names, and expose composite CPU die readings.
//

#import <Foundation/Foundation.h>
#import "applesilicon_hardware_reader.h"

// Based on https://github.com/fermion-star/apple_sensors and IOHIDEventSystemClient.

#include <IOKit/hidsystem/IOHIDEventSystemClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
CFTypeRef _Nullable IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define IOHIDEventFieldBase(type)   (type << 16)
#define kIOHIDEventTypeTemperature  15

// Synthetic sensor names shown in prefs / used as defaults.
NSString * const kAppleSiliconCompositeCPUDieMax = @"CPU Die (max)";
NSString * const kAppleSiliconCompositeCPUDieAvg = @"CPU Die (avg)";

static const float kInvalidTempC = -273.15F;

static dispatch_once_t once = 0;
static IOHIDEventSystemClientRef eventSystem;

static void initEventSystem(void) {
	dispatch_once(&once, ^{
		eventSystem = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
	});
}

/// Plausible silicon die temperature (°C). Rejects dead/uninitialized sensors.
static BOOL isPlausibleTempC(float t) {
	return (t > -20.0F && t < 125.0F);
}

/// Sensors that reflect SoC / CPU die temperature on Apple Silicon.
/// Prefer PMU tdie* (M3/M4) and legacy SOC MTR / CPU-named sensors (M1/M2).
static BOOL isCPUDieLikeSensorName(NSString *name) {
	if (!name.length) return NO;
	NSString *lower = [name lowercaseString];
	// Explicit exclusions
	if ([lower containsString:@"nand"]) return NO;
	if ([lower containsString:@"battery"]) return NO;
	if ([lower containsString:@"tcal"]) return NO; // PMU calibration, not live die
	// Preferred matches
	if ([lower containsString:@"tdie"]) return YES;
	if ([lower containsString:@"soc mtr"]) return YES;
	if ([lower containsString:@"soc "]) return YES;
	if ([lower hasPrefix:@"cpu"] || [lower containsString:@" cpu"]) return YES;
	if ([lower hasPrefix:@"tc0"] || [lower hasPrefix:@"tc1"]) return YES; // rare HID aliases
	return NO;
}

/// Snapshot of all HID temperature sensors: name → latest °C (plausible only).
/// When multiple services share a Product name, keep the hottest reading.
static NSDictionary<NSString *, NSNumber *> *AppleSiliconTemperatureSnapshot(void) {
	initEventSystem();
	if (!eventSystem) {
		return @{};
	}

	NSDictionary *match = @{@"PrimaryUsagePage": @(0xff00), @"PrimaryUsage": @(5)};
	IOHIDEventSystemClientSetMatching(eventSystem, (__bridge CFDictionaryRef)match);
	NSArray *services = CFBridgingRelease(IOHIDEventSystemClientCopyServices(eventSystem));
	if (!services) {
		return @{};
	}

	NSMutableDictionary<NSString *, NSNumber *> *temps = [NSMutableDictionary dictionary];
	for (id scx in services) {
		IOHIDServiceClientRef sc = (__bridge IOHIDServiceClientRef)scx;
		NSString *name = CFBridgingRelease(IOHIDServiceClientCopyProperty(sc, CFSTR("Product")));
		if (!name.length) {
			continue;
		}
		IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypeTemperature, 0, 0);
		if (!event) {
			continue;
		}
		float t = (float)IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
		CFRelease(event);
		if (!isPlausibleTempC(t)) {
			continue;
		}
		NSNumber *existing = temps[name];
		// Duplicate Product names exist (multiple PMU die instances); keep the max.
		if (!existing || t > existing.floatValue) {
			temps[name] = @(t);
		}
	}
	return temps;
}

static float compositeDieMax(NSDictionary<NSString *, NSNumber *> *snapshot) {
	float maxT = kInvalidTempC;
	BOOL any = NO;
	for (NSString *name in snapshot) {
		if (!isCPUDieLikeSensorName(name)) continue;
		float t = snapshot[name].floatValue;
		if (!any || t > maxT) {
			maxT = t;
			any = YES;
		}
	}
	return any ? maxT : kInvalidTempC;
}

static float compositeDieAvg(NSDictionary<NSString *, NSNumber *> *snapshot) {
	double sum = 0;
	NSUInteger n = 0;
	for (NSString *name in snapshot) {
		if (!isCPUDieLikeSensorName(name)) continue;
		sum += snapshot[name].floatValue;
		n++;
	}
	if (n == 0) return kInvalidTempC;
	return (float)(sum / (double)n);
}

NSArray *AppleSiliconTemperatureSensorNames(void) {
	NSDictionary *snapshot = AppleSiliconTemperatureSnapshot();
	NSMutableArray *names = [NSMutableArray array];

	// Synthetic CPU die readings first so prefs default / UI put them up top.
	if (isPlausibleTempC(compositeDieMax(snapshot))) {
		[names addObject:kAppleSiliconCompositeCPUDieMax];
		[names addObject:kAppleSiliconCompositeCPUDieAvg];
	}

	NSArray *physical = [[snapshot allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	[names addObjectsFromArray:physical];
	return names;
}

float AppleSiliconTemperatureForName(NSString *productName) {
	if (!productName.length) {
		return kInvalidTempC;
	}

	NSDictionary *snapshot = AppleSiliconTemperatureSnapshot();

	if ([productName isEqualToString:kAppleSiliconCompositeCPUDieMax]) {
		return compositeDieMax(snapshot);
	}
	if ([productName isEqualToString:kAppleSiliconCompositeCPUDieAvg]) {
		return compositeDieAvg(snapshot);
	}

	NSNumber *t = snapshot[productName];
	if (t) {
		return t.floatValue;
	}

	// Case-insensitive fallback (prefs / older defaults).
	for (NSString *key in snapshot) {
		if ([key caseInsensitiveCompare:productName] == NSOrderedSame) {
			return [snapshot[key] floatValue];
		}
	}

	return kInvalidTempC;
}

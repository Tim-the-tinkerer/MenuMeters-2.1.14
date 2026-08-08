//
//  MenuMeterGPUStats.m
//
//  GPU utilization from IOAccelerator "PerformanceStatistics"
//  (works on Apple Silicon AGX and modern Intel/AMD GPUs).
//

#import "MenuMeterGPUStats.h"

@implementation MenuMeterGPUStats {
	NSString *_gpuName;
	NSString *_gpuDescription;
	double _deviceUtil;
	double _rendererUtil;
	double _tilerUtil;
	uint64_t _memInUse;
	uint64_t _memAlloc;
	BOOL _available;
	io_iterator_t _accelIterator;
}

- (instancetype)init {
	self = [super init];
	if (!self) return nil;

	_gpuName = @"GPU";
	_gpuDescription = @"";
	_deviceUtil = 0;
	_rendererUtil = 0;
	_tilerUtil = 0;
	_memInUse = 0;
	_memAlloc = 0;
	_available = NO;
	_accelIterator = IO_OBJECT_NULL;

	// Discover accelerators once; re-query properties each sample.
	kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
													IOServiceMatching("IOAccelerator"),
													&_accelIterator);
	if (kr == KERN_SUCCESS && _accelIterator) {
		[self sample];
	}
	return self;
}

- (void)dealloc {
	if (_accelIterator) {
		IOObjectRelease(_accelIterator);
		_accelIterator = IO_OBJECT_NULL;
	}
}

- (NSString *)gpuName { return _gpuName ?: @"GPU"; }
- (NSString *)gpuDescription { return _gpuDescription ?: @""; }
- (double)deviceUtilization { return _deviceUtil; }
- (double)rendererUtilization { return _rendererUtil; }
- (double)tilerUtilization { return _tilerUtil; }
- (uint64_t)memoryInUse { return _memInUse; }
- (uint64_t)memoryAllocated { return _memAlloc; }
- (BOOL)gpuAvailable { return _available; }

static double clamp01(double v) {
	if (v < 0) return 0;
	if (v > 1) return 1;
	return v;
}

static double percentField(NSDictionary *ps, NSArray<NSString *> *keys) {
	for (NSString *key in keys) {
		id val = ps[key];
		if ([val isKindOfClass:[NSNumber class]]) {
			double d = [val doubleValue];
			// Values may already be 0–100 or occasionally 0–1
			if (d > 1.0) d /= 100.0;
			return clamp01(d);
		}
	}
	return -1;
}

static uint64_t bytesField(NSDictionary *ps, NSArray<NSString *> *keys) {
	for (NSString *key in keys) {
		id val = ps[key];
		if ([val isKindOfClass:[NSNumber class]]) {
			return [val unsignedLongLongValue];
		}
	}
	return 0;
}

- (void)sample {
	// Re-match each sample so we pick up GPUs that appeared later (eGPU rare case).
	io_iterator_t iter = IO_OBJECT_NULL;
	kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
													IOServiceMatching("IOAccelerator"),
													&iter);
	if (kr != KERN_SUCCESS || !iter) {
		_available = NO;
		_deviceUtil = _rendererUtil = _tilerUtil = 0;
		return;
	}

	double bestDevice = -1;
	double bestRenderer = -1;
	double bestTiler = -1;
	uint64_t bestMemInUse = 0;
	uint64_t bestMemAlloc = 0;
	NSString *bestName = nil;
	NSString *bestDesc = nil;
	BOOL found = NO;

	io_registry_entry_t service;
	while ((service = IOIteratorNext(iter))) {
		// model name
		CFTypeRef modelRef = IORegistryEntryCreateCFProperty(service, CFSTR("model"),
															 kCFAllocatorDefault, kNilOptions);
		NSString *model = nil;
		if (modelRef) {
			if (CFGetTypeID(modelRef) == CFStringGetTypeID()) {
				model = [(__bridge NSString *)modelRef copy];
			} else if (CFGetTypeID(modelRef) == CFDataGetTypeID()) {
				// Sometimes "model" is CFData (C string)
				const char *bytes = (const char *)CFDataGetBytePtr((CFDataRef)modelRef);
				if (bytes) model = [NSString stringWithUTF8String:bytes];
			}
			CFRelease(modelRef);
		}

		// Optional core count from GPUConfigurationVariable
		NSString *desc = nil;
		CFTypeRef cfgRef = IORegistryEntryCreateCFProperty(service, CFSTR("GPUConfigurationVariable"),
														   kCFAllocatorDefault, kNilOptions);
		if (cfgRef && CFGetTypeID(cfgRef) == CFDictionaryGetTypeID()) {
			NSDictionary *cfg = (__bridge NSDictionary *)cfgRef;
			NSNumber *cores = cfg[@"num_cores"];
			NSNumber *gen = cfg[@"gpu_gen"];
			if (cores) {
				if (gen) {
					desc = [NSString stringWithFormat:@"%@ cores (gen %@)", cores, gen];
				} else {
					desc = [NSString stringWithFormat:@"%@ cores", cores];
				}
			}
		}
		if (cfgRef) CFRelease(cfgRef);

		CFTypeRef psRef = IORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"),
														  kCFAllocatorDefault, kNilOptions);
		if (psRef && CFGetTypeID(psRef) == CFDictionaryGetTypeID()) {
			NSDictionary *ps = (__bridge NSDictionary *)psRef;
			double device = percentField(ps, @[
				@"Device Utilization %",
				@"Device Utilization",
				@"GPU Activity(%)"
			]);
			double renderer = percentField(ps, @[@"Renderer Utilization %", @"Renderer Utilization"]);
			double tiler = percentField(ps, @[@"Tiler Utilization %", @"Tiler Utilization"]);
			uint64_t memInUse = bytesField(ps, @[
				@"In use system memory",
				@"In use system memory (driver)",
				@"vramUsedBytes",
				@"vramFreeBytes" // not ideal
			]);
			// If only free is available don't treat as in-use
			if (ps[@"vramUsedBytes"]) {
				memInUse = [ps[@"vramUsedBytes"] unsignedLongLongValue];
			}
			uint64_t memAlloc = bytesField(ps, @[
				@"Alloc system memory",
				@"vramTotalBytes"
			]);

			// Prefer the accelerator with highest device util as the "primary" GPU reading
			// (discrete vs integrated: show the active one).
			double score = (device >= 0 ? device : 0);
			if (!found || score >= bestDevice) {
				found = YES;
				if (device >= 0) bestDevice = device;
				if (renderer >= 0) bestRenderer = renderer;
				if (tiler >= 0) bestTiler = tiler;
				if (memInUse > 0) bestMemInUse = memInUse;
				if (memAlloc > 0) bestMemAlloc = memAlloc;
				if (model.length) bestName = model;
				if (desc.length) bestDesc = desc;
			}
		}
		if (psRef) CFRelease(psRef);

		// Name fallback from class
		if (!bestName) {
			io_name_t className;
			if (IOObjectGetClass(service, className) == KERN_SUCCESS) {
				bestName = [NSString stringWithUTF8String:className];
			}
		}

		IOObjectRelease(service);
	}
	IOObjectRelease(iter);

	_available = found;
	if (found) {
		// Prefer Device Utilization; fall back to renderer/tiler.
		if (bestDevice >= 0) _deviceUtil = bestDevice;
		else if (bestRenderer >= 0) _deviceUtil = bestRenderer;
		else if (bestTiler >= 0) _deviceUtil = bestTiler;
		else _deviceUtil = 0;

		_rendererUtil = bestRenderer >= 0 ? bestRenderer : _deviceUtil;
		_tilerUtil = bestTiler >= 0 ? bestTiler : 0;
		_memInUse = bestMemInUse;
		_memAlloc = bestMemAlloc;
		if (bestName.length) _gpuName = bestName;
		if (bestDesc.length) _gpuDescription = bestDesc;
	} else {
		_deviceUtil = _rendererUtil = _tilerUtil = 0;
		_memInUse = _memAlloc = 0;
	}
}

@end

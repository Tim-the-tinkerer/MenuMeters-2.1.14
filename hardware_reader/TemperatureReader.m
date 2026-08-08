//
//  TemperatureReader.m
//  MenuMeters
//
//  Created by Yuji on 1/31/21.
//  Updated: Apple Silicon default is CPU die aggregate (not NAND / missing SOC MTR).
//

#import "TemperatureReader.h"
#if TARGET_CPU_X86_64
#import "smc_reader.h"
#elif TARGET_CPU_ARM64
#import "applesilicon_hardware_reader.h"
#endif

@implementation TemperatureReader

+(NSArray*)sensorNames
{
#if TARGET_CPU_X86_64
    static dispatch_once_t once;
    static NSArray*sensorNames;
    dispatch_once(&once, ^{
    if (kIOReturnSuccess == SMCOpen()) {
        UInt32 count;
        NSMutableArray*a=[NSMutableArray array];
        SMCReadKeysCount(&count);
        for(int i=0;i<count;i++){
            SMCKeyValue val;
            SMCReadKeyAtIndex(i, &val);
            SMCCode key=val.key;
            char s[5]={key.code[3],key.code[2],key.code[1],key.code[0],0};
            NSString*name=[NSString stringWithUTF8String:s];
            if([name hasPrefix:@"T"]&&val.info.dataType.type ==SMC_DATATYPE_SP78.type){
                [a addObject:name];
            }
        }
        SMCClose();
        sensorNames=a;
    }else{
        sensorNames=nil;
    }
    });
    return sensorNames;
#elif TARGET_CPU_ARM64
    // Do not cache forever: sensor set can differ across boots / OS updates.
    return AppleSiliconTemperatureSensorNames();
#endif
}

+(NSString*)defaultSensor
{
    static NSString*foo=nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        foo=[self defaultSensorRealWork];
    });
    return foo;
}

+(NSString*)defaultSensorRealWork
{
#if TARGET_CPU_X86_64
    NSString* candidate = @"TC0P";
    NSArray *names = [self sensorNames];
    if(!names.count)
        return candidate;
    if([names containsObject:candidate])
        return candidate;
    for(NSString*sensor in names){
        if([sensor hasPrefix:@"TC"])
            return sensor;
    }
    return names[0];
#elif TARGET_CPU_ARM64
    // Prefer composite CPU die reading. Legacy "SOC MTR Temp Sensor0" is missing
    // on many M3/M4 machines; falling back alphabetically picked NAND (wrong).
    NSArray *names = [self sensorNames];
    if ([names containsObject:kAppleSiliconCompositeCPUDieMax]) {
        return kAppleSiliconCompositeCPUDieMax;
    }
    // Prefer any physical die-like sensor if composites unavailable.
    NSArray *preferredSubstrings = @[@"tdie", @"SOC MTR", @"SOC ", @"CPU"];
    for (NSString *sub in preferredSubstrings) {
        for (NSString *sensor in names) {
            if ([sensor rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
                // Skip obvious non-CPU
                NSString *lower = sensor.lowercaseString;
                if ([lower containsString:@"nand"] || [lower containsString:@"tcal"]) continue;
                return sensor;
            }
        }
    }
    if (names.count)
        return names[0];
    return kAppleSiliconCompositeCPUDieMax;
#endif
}

+(NSString*)displayNameForSensor:(NSString*)name
{
#if TARGET_CPU_X86_64
    static NSMutableDictionary*dict=nil;
    if(!dict){
        dict=[NSMutableDictionary dictionary];
        NSDictionary*rawDict=SMCHumanReadableDescriptions();
        for(NSString*key in [self sensorNames]){
            NSString*s=rawDict[key];
            if(s){
                s=[s stringByReplacingOccurrencesOfString:@"(DegC)" withString:@""];
                s=[s stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"(%@)",key] withString:@""];
                dict[key]=[NSString stringWithFormat:@"%@: %@",key,s];
            }else{
                dict[key]=key;
            }
        }
    }
    return dict[name] ?: name;
#elif TARGET_CPU_ARM64
    if ([name isEqualToString:kAppleSiliconCompositeCPUDieMax]) {
        return @"CPU Die (max) — hottest SoC die sensor (matches most monitors)";
    }
    if ([name isEqualToString:kAppleSiliconCompositeCPUDieAvg]) {
        return @"CPU Die (avg) — average of SoC die sensors";
    }
    return name;
#endif
}

+(float)temperatureOfSensorWithName:(NSString*)name
{
#if TARGET_CPU_X86_64
    float_t celsius = -273.15F;
    if (kIOReturnSuccess == SMCOpen()) {
        SMCKeyValue value;
        if (kIOReturnSuccess == SMCReadKey(toSMCCode([name UTF8String]), &value)) {
            celsius = SP78_TO_CELSIUS(value.bytes);
        }
        SMCClose();
    }
    return celsius;
#elif TARGET_CPU_ARM64
	return AppleSiliconTemperatureForName(name);
#endif
}
@end

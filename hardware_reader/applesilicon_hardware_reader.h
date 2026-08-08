//
//  applesilicon_hardware_reader.h
//  MenuMeters
//
//  Created by Yuji on 1/25/21.
//

#ifndef applesilicon_hardware_reader_h
#define applesilicon_hardware_reader_h

#import <Foundation/Foundation.h>

// Synthetic sensors that aggregate PMU die / SOC temperature sensors.
extern NSString * const kAppleSiliconCompositeCPUDieMax;
extern NSString * const kAppleSiliconCompositeCPUDieAvg;

extern NSArray *AppleSiliconTemperatureSensorNames(void);
extern float AppleSiliconTemperatureForName(NSString *name);

#endif /* applesilicon_hardware_reader_h */

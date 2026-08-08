//
//  MenuMeterCPUStats.h
//
// 	Reader object for CPU information and load
//
//	Copyright (c) 2002-2014 Alex Harper
//
// 	This file is part of MenuMeters.
//
// 	MenuMeters is free software; you can redistribute it and/or modify
// 	it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
// 	MenuMeters is distributed in the hope that it will be useful,
// 	but WITHOUT ANY WARRANTY; without even the implied warranty of
// 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// 	GNU General Public License for more details.
//
// 	You should have received a copy of the GNU General Public License
// 	along with MenuMeters; if not, write to the Free Software
// 	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach-o/arch.h>
#import <mach/mach.h>
#import <mach/mach_error.h>
#import "MenuMeterCPU.h"
#import "LocalizedStrings.h"

@interface MenuMeterCPULoad : NSObject
@property(nonatomic) double system;
@property(nonatomic) double user;
@end

@interface MenuMeterCPUStats : NSObject {

	// CPU name
	NSString							*cpuName;
	// CPU clock speed
	NSString							*clockSpeed;
	// Mach host
	host_name_port_t 					machHost;
	// Default processor set
	processor_set_name_port_t			processorSet;
	// Previous processor tick data
	processor_cpu_load_info_t 			priorCPUTicks;
	// Localized float display
	NSNumberFormatter					*twoDigitFloatFormatter;
	// Apple Silicon Performance / Efficiency topology
	// host_processor_info indices: [0, efficiencyCoreCount) = E, then P cores.
	uint32_t							performanceCoreCount;
	uint32_t							efficiencyCoreCount;
	BOOL								hasHybridCores;

} // MenuMeterCPUStats

// CPU info
- (NSString *)cpuName;
- (NSString *)cpuSpeed;
- (uint32_t)numberOfCPUs;
- (uint32_t)numberOfCores;
- (uint32_t)performanceCoreCount;
- (uint32_t)efficiencyCoreCount;
- (BOOL)hasHybridCores;
// Index of first Performance core in host_processor_info ordering (E cores first).
- (uint32_t)performanceCoreStartIndex;
- (NSString *)processorDescription;
- (NSString *)coreDescription;

// Load info
- (NSString *)currentProcessorTasks;
- (NSString *)loadAverage;
- (NSArray *)currentLoadBySorting:(BOOL)sorted;
// Average system/user load over a contiguous core range (inclusive of start, count cores).
- (void)averageLoadFromLoadArray:(NSArray *)loadInfo
					  startIndex:(uint32_t)start
						   count:(uint32_t)count
					returnSystem:(double *)system
					  returnUser:(double *)user;
- (float_t)cpuProximityTemperature;
- (NSString*)cpuPowerLimitStatus;

@end

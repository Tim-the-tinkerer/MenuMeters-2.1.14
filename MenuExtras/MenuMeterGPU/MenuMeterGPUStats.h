//
//  MenuMeterGPUStats.h
//
//  Reader for GPU utilization via IOAccelerator PerformanceStatistics
//

#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>

@interface MenuMeterGPUStats : NSObject

// Human-readable GPU name (e.g. "Apple M4 Pro")
- (NSString *)gpuName;
// Core / config summary when available
- (NSString *)gpuDescription;
// 0.0–1.0 device utilization (best available: Device / Renderer / Tiler)
- (double)deviceUtilization;
- (double)rendererUtilization;
- (double)tilerUtilization;
// Bytes of GPU-related system memory in use / allocated (unified memory on AS)
- (uint64_t)memoryInUse;
- (uint64_t)memoryAllocated;
// YES if at least one accelerator was found
- (BOOL)gpuAvailable;

// Refresh PerformanceStatistics from IOKit (call each sample)
- (void)sample;

@end

//
//  MenuMeterGPUExtra.h
//
//  Menu bar GPU meter
//

#import <Cocoa/Cocoa.h>
#import "MenuMeters.h"
#import "MenuMeterDefaults.h"
#import "MenuMeterGPU.h"
#import "MenuMeterGPUStats.h"
#import "MenuMeterWorkarounds.h"

@interface MenuMeterGPUExtra : NSMenuExtra {
	NSMenu *extraMenu;
	MenuMeterDefaults *ourPrefs;
	MenuMeterGPUStats *gpuStats;
	NSMutableArray *loadHistory; // NSNumber 0–1
	NSColor *gpuColor;
	NSColor *fgMenuThemeColor;
	float percentWidth;
}

@end

//
//  MenuMeterGPUExtra.m
//
//  Menu bar GPU meter — utilization % / graph / thermometer
//

#import "MenuMeterGPUExtra.h"

@interface MenuMeterGPUExtra (PrivateMethods)
- (void)configFromPrefs:(NSNotification *)notification;
- (void)updateMenuContent;
@end

@implementation MenuMeterGPUExtra

- (instancetype)init {
	self = [super initWithBundleID:kGPUMenuBundleID];
	if (!self) return nil;

	ourPrefs = [MenuMeterDefaults sharedMenuMeterDefaults];
	if (!ourPrefs) {
		NSLog(@"MenuMeterGPU unable to connect to preferences. Abort.");
		return nil;
	}

	gpuStats = [[MenuMeterGPUStats alloc] init];
	loadHistory = [NSMutableArray array];
	if (!gpuStats || !loadHistory) {
		NSLog(@"MenuMeterGPU unable to load stats gatherer. Abort.");
		return nil;
	}

	extraMenu = [[NSMenu alloc] initWithTitle:@""];
	if (!extraMenu) return nil;
	[extraMenu setAutoenablesItems:NO];

	// Static titles + live value placeholders
	// 0: GPU:
	// 1:   name
	// 2:   description
	// 3: Utilization:
	// 4:   device
	// 5:   renderer
	// 6:   tiler
	// 7: Memory:
	// 8:   in use
	// 9:   allocated
	// 10: separator + standard entries
	NSMenuItem *item = [extraMenu addItemWithTitle:@"GPU:" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;

	item = [extraMenu addItemWithTitle:@"Utilization:" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;

	item = [extraMenu addItemWithTitle:@"Memory:" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;
	item = [extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	item.enabled = NO;
	item.indentationLevel = 1;

	[extraMenu addItem:[NSMenuItem separatorItem]];
	[self addStandardMenuEntriesTo:extraMenu];

	[self configFromPrefs:nil];
	NSLog(@"MenuMeterGPU loaded.");
	return self;
}

#pragma mark - Menu

- (NSMenu *)menu {
	[self updateMenuContent];
	return extraMenu;
}

static NSString *formatBytes(uint64_t bytes) {
	if (bytes >= 1099511627776ULL) {
		return [NSString stringWithFormat:@"%.2f TB", bytes / 1099511627776.0];
	} else if (bytes >= 1073741824ULL) {
		return [NSString stringWithFormat:@"%.2f GB", bytes / 1073741824.0];
	} else if (bytes >= 1048576ULL) {
		return [NSString stringWithFormat:@"%.1f MB", bytes / 1048576.0];
	} else if (bytes >= 1024ULL) {
		return [NSString stringWithFormat:@"%.0f KB", bytes / 1024.0];
	}
	return [NSString stringWithFormat:@"%llu B", bytes];
}

- (void)updateMenuContent {
	if (![gpuStats gpuAvailable]) {
		LiveUpdateMenuItemTitle(extraMenu, 1, @"No GPU statistics available");
		LiveUpdateMenuItemTitle(extraMenu, 2, @"");
		LiveUpdateMenuItemTitle(extraMenu, 4, @"—");
		LiveUpdateMenuItemTitle(extraMenu, 5, @"—");
		LiveUpdateMenuItemTitle(extraMenu, 6, @"—");
		LiveUpdateMenuItemTitle(extraMenu, 8, @"—");
		LiveUpdateMenuItemTitle(extraMenu, 9, @"—");
		return;
	}

	LiveUpdateMenuItemTitle(extraMenu, 1, [gpuStats gpuName]);
	NSString *desc = [gpuStats gpuDescription];
	LiveUpdateMenuItemTitleAndVisibility(extraMenu, 2, desc.length ? desc : nil, desc.length == 0);

	LiveUpdateMenuItemTitle(extraMenu, 4,
		[NSString stringWithFormat:@"Device: %.0f%%", [gpuStats deviceUtilization] * 100.0]);
	LiveUpdateMenuItemTitle(extraMenu, 5,
		[NSString stringWithFormat:@"Renderer: %.0f%%", [gpuStats rendererUtilization] * 100.0]);
	LiveUpdateMenuItemTitle(extraMenu, 6,
		[NSString stringWithFormat:@"Tiler: %.0f%%", [gpuStats tilerUtilization] * 100.0]);

	uint64_t inUse = [gpuStats memoryInUse];
	uint64_t alloc = [gpuStats memoryAllocated];
	LiveUpdateMenuItemTitle(extraMenu, 8,
		[NSString stringWithFormat:@"In use: %@", formatBytes(inUse)]);
	LiveUpdateMenuItemTitleAndVisibility(extraMenu, 9,
		alloc > 0 ? [NSString stringWithFormat:@"Allocated: %@", formatBytes(alloc)] : nil,
		alloc == 0);
}

#pragma mark - Timer / render

- (void)timerFired:(id)timer {
	[gpuStats sample];
	double util = [gpuStats deviceUtilization];
	[loadHistory addObject:@(util)];
	// Cap history to graph length * 2 for smooth redraw
	NSUInteger maxHist = (NSUInteger)MAX([ourPrefs gpuGraphLength] * 2, 60);
	while ([loadHistory count] > maxHist) {
		[loadHistory removeObjectAtIndex:0];
	}
	[super timerFired:timer];
}

- (BOOL)renderImage {
	[self setupAppearance];
	if (![loadHistory count]) return NO;

	double util = [[loadHistory lastObject] doubleValue];
	if (util < 0) util = 0;
	if (util > 1) util = 1;

	int mode = [ourPrefs gpuDisplayMode];
	float offset = 0;

	if (mode & kGPUDisplayGraph) {
		[self renderGraphAtOffset:offset];
		offset += [ourPrefs gpuGraphLength];
	}
	if (mode & kGPUDisplayPercent) {
		[self renderPercent:util atOffset:offset];
		offset += percentWidth;
	}
	if (mode & kGPUDisplayThermometer) {
		[self renderThermometer:util atOffset:offset];
		offset += kGPUThermometerDisplayWidth;
	}
	// If nothing selected, still show percent
	if ((mode & (kGPUDisplayPercent | kGPUDisplayGraph | kGPUDisplayThermometer)) == 0) {
		[self renderPercent:util atOffset:0];
	}
	return YES;
}

- (void)renderPercent:(double)util atOffset:(float)offset {
	NSDictionary *attrs = @{
		NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:self.fontSize weight:NSFontWeightRegular],
		NSForegroundColorAttributeName: fgMenuThemeColor ?: self.menuBarTextColor
	};
	NSString *text = [NSString stringWithFormat:@"%d%%", (int)round(util * 100.0)];
	if ([ourPrefs gpuShowMemory] && [gpuStats memoryInUse] > 0) {
		// Compact: "12% 1.5G"
		uint64_t m = [gpuStats memoryInUse];
		NSString *mem;
		if (m >= 1073741824ULL) mem = [NSString stringWithFormat:@"%.1fG", m / 1073741824.0];
		else mem = [NSString stringWithFormat:@"%.0fM", m / 1048576.0];
		text = [NSString stringWithFormat:@"%d%% %@", (int)round(util * 100.0), mem];
	}
	NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:attrs];
	[str drawAtPoint:NSMakePoint(offset + percentWidth - ceil(str.size.width) - 1,
								 (self.imageHeight - str.size.height) / 2.0 + self.baselineOffset)];
}

- (void)renderGraphAtOffset:(float)offset {
	NSBezierPath *path = [NSBezierPath bezierPath];
	float h = (float)self.imageHeight - 0.5f;
	int width = [ourPrefs gpuGraphLength];
	[path moveToPoint:NSMakePoint(offset, 0)];
	int pos = 0;
	for (pos = 0; pos < width; pos++) {
		NSInteger histIdx = (NSInteger)[loadHistory count] - width + pos;
		double u = 0;
		if (histIdx >= 0 && histIdx < (NSInteger)[loadHistory count]) {
			u = [loadHistory[histIdx] doubleValue];
		}
		if (u < 0) u = 0;
		if (u > 1) u = 1;
		[path lineToPoint:NSMakePoint(offset + pos, u * h + 0.5f)];
	}
	[path lineToPoint:NSMakePoint(offset + pos - 1, 0)];
	[path closePath];
	[(gpuColor ?: [NSColor systemGreenColor]) set];
	[path fill];
}

- (void)renderThermometer:(double)util atOffset:(float)offset {
	float totalH = (float)self.imageHeight - 3.0f;
	NSBezierPath *fill = [NSBezierPath bezierPathWithRect:NSMakeRect(offset + 1.5f, 1.5f,
																	 kGPUThermometerDisplayWidth - 3,
																	 totalH * util)];
	NSBezierPath *frame = [NSBezierPath bezierPathWithRect:NSMakeRect(offset + 0.5f, 0.5f,
																	  kGPUThermometerDisplayWidth - 1,
																	  (float)self.imageHeight - 1)];
	[(gpuColor ?: [NSColor systemGreenColor]) set];
	[fill fill];
	[[self.menuBarTextColor colorWithAlphaComponent:0.6] set];
	[frame stroke];
}

#pragma mark - Prefs

- (void)configFromPrefs:(NSNotification *)notification {
#ifdef ELCAPITAN
	[super configDisplay:kGPUMenuBundleID fromPrefs:ourPrefs withTimerInterval:[ourPrefs gpuInterval]];
#endif
	[self setupColor:nil];

	// Percent label width
	NSDictionary *attrs = @{
		NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:self.fontSize weight:NSFontWeightRegular],
		NSForegroundColorAttributeName: fgMenuThemeColor ?: self.menuBarTextColor
	};
	NSString *sample = [ourPrefs gpuShowMemory] ? @"100% 99.9G" : @"100%";
	NSAttributedString *str = [[NSAttributedString alloc] initWithString:sample attributes:attrs];
	percentWidth = (float)round(str.size.width) + kGPUPercentDisplayBorderWidth;

	menuWidth = 0;
	int mode = [ourPrefs gpuDisplayMode];
	if (mode == 0) mode = kGPUDisplayPercent;
	if (mode & kGPUDisplayGraph) menuWidth += [ourPrefs gpuGraphLength];
	if (mode & kGPUDisplayPercent) menuWidth += percentWidth;
	if (mode & kGPUDisplayThermometer) menuWidth += kGPUThermometerDisplayWidth;
	if (menuWidth < 1) menuWidth = percentWidth;

	statusItem.button.image = self.image;
}

- (void)setupColor:(NSNotification *)notification {
	fgMenuThemeColor = self.menuBarTextColor;
	gpuColor = [self colorByAdjustingForLightDark:[ourPrefs gpuColor]];
}

// baselineOffset / fontSize inherited helpers — may be on CPU extra only.
// Provide safe defaults if base doesn't define them.
- (CGFloat)baselineOffset {
	return 0;
}
- (CGFloat)fontSize {
	// Match CPU meter small monospaced size
	return [NSFont smallSystemFontSize];
}

@end

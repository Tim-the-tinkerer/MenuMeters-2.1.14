//
//  NSMenuExtraBase.m
//  MenuMeters
//
//  Created by Yuji on 2015/08/01.
//  Updated for modern macOS / Tahoe
//
//

#import "MenuMetersMenuExtraBase.h"
#import "MenuMeterWorkarounds.h"

#import "MenuMeterCPUExtra.h"
#import "MenuMeterDiskExtra.h"
#import "MenuMeterMemExtra.h"
#import "MenuMeterNetExtra.h"
#import "MenuMeterGPUExtra.h"

#define kAppleInterfaceThemeChangedNotification        @"AppleInterfaceThemeChangedNotification"

@implementation MenuMetersMenuExtraBase
-(NSColor*)colorByAdjustingForLightDark:(NSColor*)c
{
    [self setupAppearance];
    return [c blendedColorWithFraction:[[NSUserDefaults standardUserDefaults] floatForKey:@"tintPercentage"]/100  ofColor:self.isDark?[[NSColor whiteColor] colorWithAlphaComponent:[c alphaComponent]]:[[NSColor blackColor] colorWithAlphaComponent:[c alphaComponent]]];
}
-(instancetype)initWithBundleID:(NSString*)bundleID
{
    self=[super init];
    self.bundleID=bundleID;
    // Register for pref changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(configFromPrefs:)
                                                            name:self.bundleID
                                                          object:kPrefChangeNotification];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"tintPercentage" options:NSKeyValueObservingOptionNew context:nil];
    if(@available(macOS 10.14,*)){
    }else{
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(setupColor:)
                                                                name:kAppleInterfaceThemeChangedNotification
                                                              object:nil];
    }
    return self;
}
-(void)configFromPrefs:(NSNotification *)notification
{
    NSLog(@"shouldn't happen");
    abort();
}
-(NSMenu*)menu
{
    NSLog(@"shouldn't happen");
    abort();
}
-(void)setupColor:(NSNotification*)notification
{
    NSLog(@"shouldn't happen");
    abort();
}
-(CGFloat)imageHeight
{
    return self.height-1;
}
-(NSImage*)image
{
    CGFloat width = menuWidth;
    CGFloat height = self.imageHeight;
    // Never hand the menu bar a zero-size image (collapses the status item).
    if (width < 1) {
        width = 16;
    }
    if (height < 1) {
        height = 16;
    }
    NSSize imageSize=NSMakeSize(width, height);
    return [NSImage imageWithSize:imageSize
                          flipped:NO
                   drawingHandler:^BOOL(NSRect dstRect) {
        return [self renderImage];
    }];
}
-(BOOL)renderImage
{
    NSLog(@"shouldn't happen");
    abort();
}
-(void)timerFired:(id)notused
{
    if (!statusItem) {
        return;
    }
    NSImage *img = self.image;
    statusItem.button.image = img;
    // Ensure the item stays enabled/visible on modern menu bar (Tahoe Menu Bar toggles).
    if (!statusItem.visible) {
        statusItem.visible = YES;
    }
    // Detect status items that exist but are off-screen (notch / crowded menu bar).
    // Skip while the menu is open; only fire occasionally to avoid spam.
    static NSUInteger fireCount = 0;
    fireCount++;
    // Throttle "hidden by system" notifications (notch / overcrowded menu bar).
    if (fireCount > 15 && (fireCount % 30) == 0 && !self.isMenuVisible) {
        if (self.isInstalledButHiddenBySystem) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"hiddenBySystem" object:nil];
        }
    }
}
- (void)configDisplay:(NSString*)bundleID fromPrefs:(MenuMeterDefaults*)ourPrefs withTimerInterval:(NSTimeInterval)interval
{
    if([ourPrefs loadBoolPref:bundleID defaultValue:YES]){
        if(!statusItem){
            statusItem=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            // 11.0.1 does not keep the position unless autosaveName is explicitly set,
            // see https://github.com/feedback-assistant/reports/issues/151 .
            // Also required for System Settings → Menu Bar toggles on Ventura+.
            statusItem.autosaveName=self.bundleID;
            statusItem.behavior=NSStatusItemBehaviorRemovalAllowed;
            [statusItem addObserver:self forKeyPath:@"visible" options:NSKeyValueObservingOptionNew context:nil];
            statusItem.menu = self.menu;
            statusItem.menu.delegate = self;
            // Force visible and clear any stale "user removed" restore state (Tahoe Menu Bar settings).
            [[NSUserDefaults standardUserDefaults] setBool:YES
                                                    forKey:[NSString stringWithFormat:@"NSStatusItem Visible %@", self.bundleID]];
            statusItem.visible = YES;
            statusItem.button.imagePosition = NSImageOnly;
            statusItem.button.imageScaling = NSImageScaleProportionallyDown;
            statusItem.button.appearsDisabled = NO;
            statusItem.button.enabled = YES;
            /*
             Observing effectiveAppearance has a serious drawback when the Mac has two moniters, one with a light menubar and another with a dard menubar, which can happen since Big Sur depending on the chosen desktop pictures.
             In such cases statusItem.button.effectiveAppearance changes each time the system redraws the statusItem.button on two menubars, making configFromPrefs: called every time.
             Honestly, the way a single NSStatusItem behaves differently on two menubars with different appearances is undocumented, especially with a dynamically-drawn block-based image attached on a button...
            */
            [statusItem.button addObserver:self forKeyPath:@"effectiveAppearance" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
        } else {
            // Re-assert visibility (System Settings → Menu Bar can leave items registered but invisible).
            statusItem.visible = YES;
        }
        [updateTimer invalidate];
        updateTimer=[NSTimer timerWithTimeInterval:interval target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
        [updateTimer setTolerance:.2*interval];
        [[NSRunLoop currentRunLoop] addTimer:updateTimer forMode:NSRunLoopCommonModes];
        // Draw immediately so meters appear without waiting for the first timer fire.
        [self timerFired:nil];
    }else if(![ourPrefs loadBoolPref:bundleID defaultValue:YES] && statusItem){
        [self removeStatusItem];
    }
}
-(void)removeStatusItem
{
    [updateTimer invalidate];
    updateTimer = nil;
    if (statusItem) {
        @try {
            [statusItem removeObserver:self forKeyPath:@"visible"];
        } @catch (__unused NSException *ex) {}
        @try {
            [statusItem.button removeObserver:self forKeyPath:@"effectiveAppearance"];
        } @catch (__unused NSException *ex) {}
        [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
        statusItem=nil;
    }
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"menuExtraUnloaded" object:self.bundleID]];
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if(object==statusItem.button && [keyPath isEqualToString:@"effectiveAppearance"]){
        NSAppearance*old=change[NSKeyValueChangeOldKey];
        NSAppearance*new=change[NSKeyValueChangeNewKey];
        if (![old isKindOfClass:[NSNull class]] && ![new isKindOfClass:[NSNull class]] &&
            old && new && ![old.name isEqualToString:new.name]){
            [self setupColor:nil];
        }
    }

    if(object==statusItem && [keyPath isEqualToString:@"visible"]){
        if(!statusItem.visible){
            // User (or System Settings) removed the item — unload and sync prefs.
            [self removeStatusItem];
        }
    }
    if([keyPath isEqualToString:@"tintPercentage"]){
        [self setupColor:nil];
    }
}
- (void)openMenuMetersPref:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"openPref" object:self]];
}
- (void)openActivityMonitor:(id)sender {

    if (![[NSWorkspace sharedWorkspace] launchApplication:@"Activity Monitor.app"]) {
        NSLog(@"MenuMeter unable to launch the Activity Monitor.");
    }
    BOOL x=[[NSUserDefaults standardUserDefaults] boolForKey:@"activityMonitorOpenSpecificPanes"];
    if(!x)
        return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(),^{
            int tab=1;
            if([self isKindOfClass:[MenuMeterCPUExtra class]]){
                tab=1;
            }
            // on some Mac's there is a "GPU" tab at the 2nd position.
            // So the rest needs to be addressed from the last
            if([self isKindOfClass:[MenuMeterDiskExtra class]]){
                tab=-2;
            }
            if([self isKindOfClass:[MenuMeterMemExtra class]]){
                tab=-4;
            }
            if([self isKindOfClass:[MenuMeterNetExtra class]]){
                tab=-1;
            }
            // Activity Monitor GPU pane is typically the 2nd tab when present
            if([self isKindOfClass:[MenuMeterGPUExtra class]]){
                tab=2;
            }
            NSString*source=[NSString stringWithFormat:@"tell application \"System Events\" to tell process \"Activity Monitor\" to click radio button %@ of radio group 1 of group 2 of toolbar of window 1", @(tab)];
            NSAppleScript*script=[[NSAppleScript alloc] initWithSource:source];
            NSDictionary* errorDict=nil;
            [script executeAndReturnError:&errorDict];
            if(errorDict){
                NSLog(@"%@",errorDict);
            }
    });
} // openActivityMonitor
- (void)quitMenuMeters:(id)sender
{
    [NSApp terminate:nil];
}

- (void)addStandardMenuEntriesTo:(NSMenu*)extraMenu
{
    NSMenuItem* menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:NSLocalizedString(kOpenActivityMonitorTitle, kOpenActivityMonitorTitle)
                                                              action:@selector(openActivityMonitor:)
                                                       keyEquivalent:@""];
    [menuItem setTarget:self];
    menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:NSLocalizedString(kOpenMenuMetersPref, kOpenMenuMetersPref)
                                                  action:@selector(openMenuMetersPref:)
                                           keyEquivalent:@""];
    [menuItem setTarget:self];
    [extraMenu addItem:[NSMenuItem separatorItem]];
    menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:NSLocalizedString(kQuitMenuMetersTitle, kQuitMenuMetersTitle)
                                                  action:@selector(quitMenuMeters:)
                                           keyEquivalent:@"q"];
    menuItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [menuItem setTarget:self];

}
-(BOOL)isDark
{
    if(@available(macOS 10.14,*)){
        // https://github.com/ruiaureliano/macOS-Appearance/blob/master/Appearance/Source/AppDelegate.swift
        return [statusItem.button.effectiveAppearance.name containsString:@"ark"];
    }
    // Fallback for older systems / missing button
    BOOL isDark = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    NSString *interfaceStyle = [defaults stringForKey:@"AppleInterfaceStyle"];
    if (interfaceStyle && [interfaceStyle isEqualToString:@"Dark"]) {
        isDark = YES;
    }
    return isDark;
}
-(BOOL)isInstalledButHiddenBySystem
{
    // Status item exists and is marked visible, but its window is not on screen
    // (menu bar overcrowding, notch collision, etc.).
    if (!statusItem || !statusItem.visible) {
        return NO;
    }
    NSWindow*window=statusItem.button.window;
    if(!window){
        return NO;
    }
    CGWindowID windowID = (CGWindowID)window.windowNumber;
    if (windowID == kCGNullWindowID || windowID == 0) {
        return NO;
    }
    // CGWindowListCreate returns a CFArray of raw CGWindowID values (not CFNumber objects).
    // Values must be read via CFArrayGetValueAtIndex cast, not Objective-C messaging.
    CFArrayRef onScreenWindows = CGWindowListCreate(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (!onScreenWindows) {
        return NO;
    }
    BOOL found = NO;
    CFIndex count = CFArrayGetCount(onScreenWindows);
    for (CFIndex i = 0; i < count; i++) {
        CGWindowID wid = (CGWindowID)(uintptr_t)CFArrayGetValueAtIndex(onScreenWindows, i);
        if (wid == windowID) {
            found = YES;
            break;
        }
    }
    CFRelease(onScreenWindows);
    return !found;
}
-(NSColor*)menuBarTextColor
{
    if(@available(macOS 10.14,*)){
        return [NSColor labelColor];
    }
    if (self.isDark){
        return [NSColor whiteColor];
    }
    return [NSColor blackColor];
}
-(CGFloat)height
{
    CGFloat height=statusItem.button.frame.size.height;
    // height is sometimes zero here, which causes a lot of headaches if untreated...
    if(height<10){
        // Big Sur+ menu bar is typically ~24pt; pre-Big Sur was 22.
        height = [[NSStatusBar systemStatusBar] thickness];
        if (height < 10) {
            height = 24;
        }
    }
    return height;
}
- (void)setupAppearance {
    if(@available(macOS 11,*)){
        // Preferred modern API: scope drawing to the menu bar appearance.
        // setCurrentAppearance: is deprecated; performAsCurrentDrawingAppearance is the replacement.
        // Callers that draw immediately after setupAppearance still work via the legacy path below
        // when performAsCurrent is not usable (non-block drawing).
        NSAppearance *appearance = statusItem.button.effectiveAppearance;
        if (appearance) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [NSAppearance setCurrentAppearance:appearance];
#pragma clang diagnostic pop
        }
    } else if(@available(macOS 10.14,*)){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [NSAppearance setCurrentAppearance:statusItem.button.effectiveAppearance];
#pragma clang diagnostic pop
    }
}
#pragma mark NSMenuDelegate
- (void)menuNeedsUpdate:(NSMenu*)menu {
    statusItem.menu = self.menu;
    statusItem.menu.delegate = self;
}
- (void)menuWillOpen:(NSMenu*)menu {
    _isMenuVisible = YES;
}
- (void)menuDidClose:(NSMenu*)menu {
    _isMenuVisible = NO;
}

@end

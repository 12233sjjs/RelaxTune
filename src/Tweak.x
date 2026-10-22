#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import "Settings.h"
#import "PowerPolicy.h"
#include <math.h>
#include "Animation.h"

static int RTLockToken = -1;
static BOOL RTLocked;
static BOOL RTOwnsPower;
static BOOL RTOverrideWhileLocked;
static BOOL RTManagesPower;
static __thread unsigned RTAnimationDepth;
static NSString *const RTDomain = @"com.12233sjjs.relaxtune";

static void RTSaveOwnership(BOOL owned) {
    RTOwnsPower = owned;
    CFPreferencesSetAppValue(CFSTR("OwnsLowPower"), owned ? kCFBooleanTrue : kCFBooleanFalse,
                             (__bridge CFStringRef)RTDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)RTDomain);
}

static void RTApplyPower(void) {
    Class cls = NSClassFromString(@"_CDBatterySaver");
    if (![cls respondsToSelector:@selector(batterySaver)]) return;
    id saver = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(batterySaver));
    SEL read = NSSelectorFromString(@"getPowerMode");
    SEL write = NSSelectorFromString(@"setPowerMode:fromSource:");
    NSMethodSignature *signature = [saver methodSignatureForSelector:write];
    if (![saver respondsToSelector:read] || signature.numberOfArguments != 4 ||
        [signature getArgumentTypeAtIndex:3][0] != '@') return;
    long long current = ((long long (*)(id, SEL))objc_msgSend)(saver, read);
    if (current != 0 && current != 1) return;
    UIDeviceBatteryState battery = UIDevice.currentDevice.batteryState;
    // An unknown battery state must not trigger power-mode changes.
    if (battery == UIDeviceBatteryStateUnknown) return;
    BOOL charging = battery == UIDeviceBatteryStateCharging || battery == UIDeviceBatteryStateFull;
    BOOL enabled = atomic_load(&RTEnabled) && atomic_load(&RTLowPower);
    RTPowerAction action = RTPowerDecision(enabled && !RTOverrideWhileLocked, RTLocked,
                                           charging, current == 1, RTOwnsPower);
    if (action == RTForgetOwnership) {
        RTOverrideWhileLocked = RTLocked;
        RTSaveOwnership(NO);
        return;
    }
    if (action == RTNoChange) return;
    long long target = action == RTEnablePower ? 1 : 0;
    ((BOOL (*)(id, SEL, long long, id))objc_msgSend)(saver, write, target, @"RelaxTune");
    long long result = ((long long (*)(id, SEL))objc_msgSend)(saver, read);
    if (result == target) RTSaveOwnership(target == 1);
}

static void RTReadLock(void) {
    uint64_t state = 0;
    if (RTLockToken < 0 || notify_get_state(RTLockToken, &state) != NOTIFY_STATUS_OK) return;
    BOOL locked = state != 0;
    if (locked != RTLocked) RTOverrideWhileLocked = NO;
    RTLocked = locked;
    RTApplyPower();
}

static void RTSettingsChanged(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        RTLoadSettings();
        if (RTManagesPower) RTApplyPower();
    });
}

static NSTimeInterval RTDuration(NSTimeInterval duration) {
    if (RTAnimationDepth == 1 && atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
        !UIAccessibilityIsReduceMotionEnabled() && duration >= 0.12 && duration <= 1.0) {
        return RTScaledDuration(duration, atomic_load(&RTAnimationFactor));
    }
    return duration;
}

%group RTApps
%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    RTAnimationDepth++;
    @try {
        %orig(RTDuration(duration), animations);
    }
    @finally { RTAnimationDepth--; }
}
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    RTAnimationDepth++;
    @try {
        %orig(RTDuration(duration), animations, completion);
    }
    @finally { RTAnimationDepth--; }
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    RTAnimationDepth++;
    @try {
        %orig(RTDuration(duration), delay, options, animations, completion);
    }
    @finally { RTAnimationDepth--; }
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
    usingSpringWithDamping:(CGFloat)damping initialSpringVelocity:(CGFloat)velocity
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    RTAnimationDepth++;
    @try {
        %orig(RTDuration(duration), delay, damping, velocity, options, animations, completion);
    }
    @finally { RTAnimationDepth--; }
}
%end

%hook NSURLSessionConfiguration
+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    if (atomic_load(&RTEnabled) && atomic_load(&RTNetwork)) config.waitsForConnectivity = YES;
    return config;
}
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    if (atomic_load(&RTEnabled) && atomic_load(&RTNetwork)) config.waitsForConnectivity = YES;
    return config;
}
%end
%end

%group RTSpringAnimations
%hook SBFFluidBehaviorSettings
- (void)setResponse:(double)response {
    if (atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
        !UIAccessibilityIsReduceMotionEnabled() && response >= 0.12 && response <= 1.0) {
        response = fmax(0.01, response * atomic_load(&RTAnimationFactor));
    }
    %orig(response);
}
%end
%end

%group RTSpringPower
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dlopen("/System/Library/PrivateFrameworks/CoreDuet.framework/CoreDuet", RTLD_LAZY);
    CFPropertyListRef saved = CFPreferencesCopyAppValue(CFSTR("OwnsLowPower"),
                                                       (__bridge CFStringRef)RTDomain);
    if (saved) {
        id value = CFBridgingRelease(saved);
        RTOwnsPower = [value respondsToSelector:@selector(boolValue)] && [value boolValue];
    }
    UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil
                        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        RTApplyPower();
    }];
    [center addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil
                        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        RTApplyPower();
    }];
    notify_register_dispatch("com.apple.springboard.lockstate", &RTLockToken,
                              dispatch_get_main_queue(), ^(int token) { RTReadLock(); });
    RTReadLock();
}
%end
%end

%ctor {
    @autoreleasepool {
        if (!RTIsApp()) return;
        RTManagesPower = [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"];
        RTLoadSettings();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            RTSettingsChanged, CFSTR("com.12233sjjs.relaxtune.changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        if (RTManagesPower) {
            %init(RTSpringPower);
            if (NSClassFromString(@"SBFFluidBehaviorSettings")) {
                %init(RTSpringAnimations);
            }
        } else {
            %init(RTApps);
        }
    }
}

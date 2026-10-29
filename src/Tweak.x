#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import <sys/wait.h>
#import <dispatch/dispatch.h>
#import "Settings.h"
#import "PowerPolicy.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include "Animation.h"

static int RTLockToken = -1;
static BOOL RTLocked;
static BOOL RTOwnsPower;
static BOOL RTOverrideWhileLocked;
static BOOL RTManagesPower;
static BOOL RTGameRestoreLowPower;
static BOOL RTApplyingPower;
static BOOL RTPowerWritePending;
static BOOL RTFrontmostGame;
static dispatch_source_t RTZombieTimer;
static int RTRespringToken = -1;
static __thread unsigned RTAnimationDepth;
static __thread BOOL RTConvertingSpringAnimation;
static NSString *const RTDomain = @"com.12233sjjs.relaxtune";
static void RTApplyPower(void);
static void RTUpdateZombieReaping(void);

static void RTSaveOwnership(BOOL owned) {
    RTOwnsPower = owned;
    CFPreferencesSetAppValue(CFSTR("OwnsLowPower"), owned ? kCFBooleanTrue : kCFBooleanFalse,
                             (__bridge CFStringRef)RTDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)RTDomain);
}

static void RTSaveGameRestore(BOOL restore) {
    RTGameRestoreLowPower = restore;
    CFPreferencesSetAppValue(CFSTR("GameRestoreLowPower"), restore ? kCFBooleanTrue : kCFBooleanFalse,
                             (__bridge CFStringRef)RTDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)RTDomain);
}

static void RTReadFrontmostGame(id display) {
    id app = display;
    id springboard = UIApplication.sharedApplication;
    SEL frontmost = NSSelectorFromString(@"_accessibilityFrontMostApplication");
    if ([springboard respondsToSelector:frontmost])
        app = ((id (*)(id, SEL))objc_msgSend)(springboard, frontmost);
    SEL identifier = NSSelectorFromString(@"bundleIdentifier");
    id bundle = [app respondsToSelector:identifier]
        ? ((id (*)(id, SEL))objc_msgSend)(app, identifier) : nil;
    RTFrontmostGame = [bundle isKindOfClass:NSString.class] &&
                     RTIsPerformanceGame([bundle UTF8String]);
}

static id RTPowerController(void) {
    Class cls = NSClassFromString(@"_PMLowPowerMode");
    SEL shared = NSSelectorFromString(@"sharedInstance");
    if ([cls respondsToSelector:shared])
        return ((id (*)(id, SEL))objc_msgSend)(cls, shared);
    cls = NSClassFromString(@"_CDBatterySaver");
    SEL saver = NSSelectorFromString(@"batterySaver");
    return [cls respondsToSelector:saver] ? ((id (*)(id, SEL))objc_msgSend)(cls, saver) : nil;
}

static void RTRequestPower(id saver, NSInteger target, void (^completion)(BOOL)) {
    RTPowerWritePending = YES;
    void (^finished)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL changed = success && ((NSInteger (*)(id, SEL))objc_msgSend)(saver,
                NSSelectorFromString(@"getPowerMode")) == target;
            RTPowerWritePending = NO;
            completion(changed);
            if (changed) RTApplyPower();
        });
    };
    SEL asyncWrite = NSSelectorFromString(@"setPowerMode:fromSource:withCompletion:");
    NSMethodSignature *signature = [saver methodSignatureForSelector:asyncWrite];
    if (signature.numberOfArguments == 5 &&
        strcmp([signature getArgumentTypeAtIndex:2], @encode(NSInteger)) == 0 &&
        [signature getArgumentTypeAtIndex:3][0] == '@' &&
        [signature getArgumentTypeAtIndex:4][0] == '@') {
        ((void (*)(id, SEL, NSInteger, id, void (^)(BOOL, NSError *)))objc_msgSend)(
            saver, asyncWrite, target, @"cc优化系统", finished);
    } else {
        ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(saver,
            NSSelectorFromString(@"setPowerMode:fromSource:"), target, @"cc优化系统");
        finished(YES, nil);
    }
}

static void RTApplyPowerImpl(void) {
    id saver = RTPowerController();
    SEL read = NSSelectorFromString(@"getPowerMode");
    SEL write = NSSelectorFromString(@"setPowerMode:fromSource:");
    NSMethodSignature *signature = [saver methodSignatureForSelector:write];
    NSMethodSignature *readSignature = [saver methodSignatureForSelector:read];
    if (readSignature.numberOfArguments != 2 ||
        strcmp(readSignature.methodReturnType, @encode(NSInteger)) != 0 ||
        signature.numberOfArguments != 4 ||
        strcmp([signature getArgumentTypeAtIndex:2], @encode(NSInteger)) != 0 ||
        [signature getArgumentTypeAtIndex:3][0] != '@') return;
    NSInteger current = ((NSInteger (*)(id, SEL))objc_msgSend)(saver, read);
    if (current != 0 && current != 1) return;
    UIDeviceBatteryState battery = UIDevice.currentDevice.batteryState;
    // An unknown battery state must not trigger power-mode changes.
    if (battery == UIDeviceBatteryStateUnknown) return;
    BOOL charging = battery == UIDeviceBatteryStateCharging || battery == UIDeviceBatteryStateFull;
    BOOL gameEnabled = atomic_load(&RTEnabled) && atomic_load(&RTGamePerformance);
    BOOL gameActive = gameEnabled && RTFrontmostGame && !RTLocked;
    RTGamePowerAction gameAction = RTGamePowerDecision(gameEnabled, RTFrontmostGame, RTLocked,
                                                       current == 1, RTGameRestoreLowPower);
    if (gameAction == RTGameDisablePower) {
        BOOL restoreManual = RTGameRestoreLowPower || !RTOwnsPower;
        RTRequestPower(saver, 0, ^(BOOL changed) {
            if (changed) {
                RTSaveGameRestore(restoreManual);
                if (RTOwnsPower) RTSaveOwnership(NO);
            }
        });
        return;
    }
    if (gameAction == RTGameRestorePower) {
        RTRequestPower(saver, 1, ^(BOOL changed) {
            if (changed) RTSaveGameRestore(NO);
        });
        return;
    } else if (gameAction == RTGameClearRestore) {
        RTSaveGameRestore(NO);
    }
    if (gameActive) {
        if (RTOwnsPower) RTSaveOwnership(NO);
        return;
    }
    BOOL enabled = atomic_load(&RTEnabled) && atomic_load(&RTLowPower);
    RTPowerAction action = RTPowerDecision(enabled && !RTOverrideWhileLocked, RTLocked,
                                           charging, current == 1, RTOwnsPower);
    if (action == RTForgetOwnership) {
        RTOverrideWhileLocked = RTLocked;
        RTSaveOwnership(NO);
        return;
    }
    if (action == RTNoChange) return;
    NSInteger target = action == RTEnablePower ? 1 : 0;
    RTRequestPower(saver, target, ^(BOOL changed) {
        if (changed) RTSaveOwnership(target == 1);
    });
}

static void RTApplyPower(void) {
    if (!RTManagesPower || RTApplyingPower || RTPowerWritePending) return;
    RTApplyingPower = YES;
    @try { RTApplyPowerImpl(); }
    @finally { RTApplyingPower = NO; }
}

static void RTReadLock(void) {
    uint64_t state = 0;
    if (RTLockToken < 0 || notify_get_state(RTLockToken, &state) != NOTIFY_STATUS_OK) return;
    BOOL locked = state != 0;
    if (locked != RTLocked) RTOverrideWhileLocked = NO;
    RTLocked = locked;
    RTReadFrontmostGame(nil);
    RTApplyPower();
}

static void RTSettingsChanged(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        RTLoadSettings();
        if (RTManagesPower) RTApplyPower();
        if (RTManagesPower) RTRefreshRateDidChange();
        RTUpdateZombieReaping();
    });
}

static NSTimeInterval RTDuration(NSTimeInterval duration) {
    if (RTAnimationDepth == 1 && atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
        !UIAccessibilityIsReduceMotionEnabled() && duration >= 0.12 && duration <= 1.0) {
        return RTScaledDuration(duration, atomic_load(&RTAnimationFactor));
    }
    return duration;
}

static UIViewAnimationOptions RTSmoothOptions(UIViewAnimationOptions options) {
    if (!(atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
          !UIAccessibilityIsReduceMotionEnabled())) return options;
    UIViewAnimationOptions curveMask = UIViewAnimationOptionCurveEaseIn |
                                       UIViewAnimationOptionCurveEaseOut |
                                       UIViewAnimationOptionCurveLinear;
    options &= ~curveMask;
    return options | UIViewAnimationOptionBeginFromCurrentState;
}

static BOOL RTAnimationHooksActive(void) {
    return atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
           !UIAccessibilityIsReduceMotionEnabled();
}

static double RTNumberForKey(id object, NSString *key) {
    if (![object respondsToSelector:NSSelectorFromString(key)]) return 0.0;
    id value = [object valueForKey:key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.0;
}

static id RTSmoothBSAnimationSettings(double duration, double delay) {
    Class factoryClass = NSClassFromString(@"BSAnimationSettings");
    SEL factory = NSSelectorFromString(@"settingsWithDuration:delay:timingFunction:");
    if (!factoryClass || ![factoryClass respondsToSelector:factory]) return nil;
    id timing = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    return ((id (*)(id, SEL, double, double, id))objc_msgSend)(
        factoryClass, factory, duration, delay, timing);
}

static void RTUpdateZombieReaping(void) {
    if (!RTManagesPower) return;
    BOOL enabled = atomic_load(&RTEnabled) && atomic_load(&RTZombieReap);
    if (enabled && !RTZombieTimer) {
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
        RTZombieTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(RTZombieTimer,
            dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
            5 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(RTZombieTimer, ^{
            int status;
            while (waitpid(-1, &status, WNOHANG) > 0) {}
        });
        dispatch_resume(RTZombieTimer);
    } else if (!enabled && RTZombieTimer) {
        dispatch_source_cancel(RTZombieTimer);
        RTZombieTimer = nil;
    }
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
        NSTimeInterval value = RTConvertingSpringAnimation ? duration : RTDuration(duration);
        UIViewAnimationOptions smoothed = RTConvertingSpringAnimation ? options : RTSmoothOptions(options);
        %orig(value, delay, smoothed, animations, completion);
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
%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
    usingSpringWithDamping:(CGFloat)damping initialSpringVelocity:(CGFloat)velocity
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    if (!RTAnimationHooksActive()) {
        %orig(duration, delay, damping, velocity, options, animations, completion);
        return;
    }
    RTAnimationDepth++;
    @try {
        RTConvertingSpringAnimation = YES;
        [UIView animateWithDuration:RTDuration(duration) delay:delay
                           options:RTSmoothOptions(options) animations:animations completion:completion];
    } @finally {
        RTConvertingSpringAnimation = NO;
        RTAnimationDepth--;
    }
}
%end
%end

%group RTSBFNonSpring
%hook SBFAnimationSettings
- (id)BSAnimationSettings {
    if (!RTAnimationHooksActive()) return %orig;
    double duration = RTNumberForKey(self, @"duration");
    double delay = RTNumberForKey(self, @"delay");
    if (duration <= 0.0 || duration > 2.0) duration = 0.30;
    id settings = RTSmoothBSAnimationSettings(
        RTScaledDuration(duration, atomic_load(&RTAnimationFactor)), delay);
    return settings ?: %orig;
}
%end
%end

%group RTPocketThermal
%hook SBPocketStateMonitor
- (long long)pocketState {
    if (atomic_load(&RTEnabled) && atomic_load(&RTPocketThermal)) return 0;
    return %orig;
}
- (void)pocketStateManager:(id)manager didUpdateState:(long long)state {
    if (atomic_load(&RTEnabled) && atomic_load(&RTPocketThermal)) state = 0;
    %orig(manager, state);
}
%end
%end

%group RTSunlightThermal
%hook SBThermalController
- (long long)level {
    if (atomic_load(&RTEnabled) && atomic_load(&RTSunlightThermal)) return 0;
    return %orig;
}
- (BOOL)isThermalBlocked {
    if (atomic_load(&RTEnabled) && atomic_load(&RTSunlightThermal)) return NO;
    return %orig;
}
- (BOOL)_isBlocked {
    if (atomic_load(&RTEnabled) && atomic_load(&RTSunlightThermal)) return NO;
    return %orig;
}
%end
%end

%group RTSpringPower
%hook SpringBoard
- (void)frontDisplayDidChange:(id)display {
    %orig;
    RTReadFrontmostGame(display);
    RTApplyPower();
}
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dlopen("/System/Library/PrivateFrameworks/LowPowerMode.framework/LowPowerMode", RTLD_LAZY);
    dlopen("/System/Library/PrivateFrameworks/CoreDuet.framework/CoreDuet", RTLD_LAZY);
    CFPropertyListRef saved = CFPreferencesCopyAppValue(CFSTR("OwnsLowPower"),
                                                       (__bridge CFStringRef)RTDomain);
    if (saved) {
        id value = CFBridgingRelease(saved);
        RTOwnsPower = [value respondsToSelector:@selector(boolValue)] && [value boolValue];
    }
    CFPropertyListRef suspended = CFPreferencesCopyAppValue(CFSTR("GameRestoreLowPower"),
                                                            (__bridge CFStringRef)RTDomain);
    if (suspended) {
        id value = CFBridgingRelease(suspended);
        RTGameRestoreLowPower = [value respondsToSelector:@selector(boolValue)] && [value boolValue];
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
        if (!RTShouldLoadAppHooks()) return;
        RTManagesPower = [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"];
        RTLoadSettings();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            RTSettingsChanged, CFSTR("com.12233sjjs.relaxtune.changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        %init(RTSpringAnimations);
        if (RTManagesPower) {
            notify_register_dispatch("com.12233sjjs.relaxtune.respring", &RTRespringToken,
                                      dispatch_get_main_queue(), ^(int token) { exit(0); });
            %init(RTSpringPower);
            if (NSClassFromString(@"SBFAnimationSettings")) {
                %init(RTSBFNonSpring);
            }
            if (NSClassFromString(@"SBPocketStateMonitor")) {
                %init(RTPocketThermal);
            }
            if (NSClassFromString(@"SBThermalController")) {
                %init(RTSunlightThermal);
            }
            RTUpdateZombieReaping();
        } else {
            %init(RTApps);
        }
    }
}

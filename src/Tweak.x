#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import "Settings.h"
#import "PowerPolicy.h"
#include <math.h>
#include <string.h>
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
static BOOL RTManagesSpringSettings;
static BOOL RTApplyingSpringSpeed;
static NSHashTable *RTSpringSettings;
static char RTSpringBaseKey;
static __thread unsigned RTAnimationDepth;
static NSString *const RTDomain = @"com.12233sjjs.relaxtune";
static void RTApplyPower(void);
static void RTApplySpringSettings(void);

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
        RTApplySpringSettings();
    });
}

static NSTimeInterval RTDuration(NSTimeInterval duration) {
    if (RTAnimationDepth == 1 && atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
        !UIAccessibilityIsReduceMotionEnabled() && duration >= 0.12 && duration <= 1.0) {
        return RTScaledDuration(duration, atomic_load(&RTAnimationFactor));
    }
    return duration;
}

static BOOL RTSpringAnimationActive(void) {
    return atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
           !UIAccessibilityIsReduceMotionEnabled();
}

static void RTStoreSpringBase(id settings, double speed) {
    objc_setAssociatedObject(settings, &RTSpringBaseKey, @(speed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @synchronized (RTSpringSettings) {
        if (![RTSpringSettings containsObject:settings]) [RTSpringSettings addObject:settings];
    }
}

static void RTApplySpringSettings(void) {
    if (!RTManagesSpringSettings || !RTSpringSettings) return;
    @synchronized (RTSpringSettings) {
        for (id settings in RTSpringSettings.allObjects) {
            NSNumber *base = objc_getAssociatedObject(settings, &RTSpringBaseKey);
            if (!base) continue;
            double speed = [base doubleValue];
            if (RTSpringAnimationActive()) {
                speed = RTScaledSpringSpeed(speed, atomic_load(&RTAnimationFactor));
            }
            RTApplyingSpringSpeed = YES;
            @try { [settings setSpeed:speed]; }
            @finally { RTApplyingSpringSpeed = NO; }
        }
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

%group RTSpringAnimationSettings
%hook SBFAnimationSettings
- (void)setSpeed:(double)speed {
    if (!RTApplyingSpringSpeed) {
        RTStoreSpringBase(self, speed);
        speed = RTScaledSpringSpeed(speed, atomic_load(&RTAnimationFactor));
    }
    %orig(speed);
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
        if (RTManagesPower) {
            %init(RTSpringPower);
            if (NSClassFromString(@"SBFFluidBehaviorSettings")) {
                %init(RTSpringAnimations);
            }
            if (NSClassFromString(@"SBFAnimationSettings")) {
                RTSpringSettings = [NSHashTable weakObjectsHashTable];
                RTManagesSpringSettings = YES;
                %init(RTSpringAnimationSettings);
            }
        } else {
            %init(RTApps);
        }
    }
}

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "Settings.h"
#import "AnimationSettings.h"

static __thread unsigned RTAnimationDepth;
static __thread BOOL RTConvertingSpringAnimation;
static __thread BOOL RTUnlockTransition;
static __thread BOOL RTWakeTransition;
static __thread unsigned RTFolderAnimationDepth;
static char RTLockSettingsKey;
static char RTFolderSettingsKey;
static Class RTFolderSettingsClass;
typedef NS_ENUM(NSInteger, RTLockSettingsKind) { RTWakeSettings = 1, RTUnlockSettings };

static double RTCurrentAcceleration(void) {
    return atomic_load(RTUnlockTransition ? &RTUnlockAcceleration : &RTAnimationFactor);
}

static BOOL RTAnimationHooksActive(void) {
    if (RTWakeTransition || RTFolderAnimationDepth) return NO;
    BOOL enabled = RTUnlockTransition
        ? atomic_load(&RTUnlockAnimations) && RTCurrentAcceleration() > 0.0
        : atomic_load(&RTAnimations);
    return atomic_load(&RTEnabled) && enabled &&
           !atomic_load(&RTAnimationExcluded) && !UIAccessibilityIsReduceMotionEnabled();
}

static NSTimeInterval RTDuration(NSTimeInterval duration) {
    return RTAnimationDepth == 1 && RTAnimationHooksActive()
        ? RTScaledDuration(duration, RTCurrentAcceleration()) : duration;
}

static NSTimeInterval RTDelay(NSTimeInterval delay, NSTimeInterval duration) {
    return RTAnimationDepth == 1 && RTAnimationHooksActive() &&
           duration >= 0.12 && duration <= 1.0
        ? RTScaledDelay(delay, RTCurrentAcceleration()) : delay;
}

static UIViewAnimationOptions RTSmoothOptions(UIViewAnimationOptions options) {
    if (RTAnimationDepth != 1 || !RTAnimationHooksActive()) return options;
    UIViewAnimationOptions curveMask = UIViewAnimationOptionCurveEaseIn |
                                       UIViewAnimationOptionCurveEaseOut |
                                       UIViewAnimationOptionCurveLinear;
    return (options & ~curveMask) | UIViewAnimationOptionCurveEaseOut |
           UIViewAnimationOptionBeginFromCurrentState;
}

static BOOL RTAdjustPropertyAnimator(NSTimeInterval duration) {
    return RTAnimationDepth == 1 && RTAnimationHooksActive() &&
           duration >= 0.12 && duration <= 1.0;
}

static double RTNumberForKey(id object, NSString *key) {
    if (![object respondsToSelector:NSSelectorFromString(key)]) return 0.0;
    id value = [object valueForKey:key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.0;
}

static void RTApply120FrameRate(id settings) {
    if (!settings || !atomic_load(&RTHighRefresh) ||
        UIScreen.mainScreen.maximumFramesPerSecond < 120) return;
    SEL setRange = NSSelectorFromString(@"setPreferredFrameRateRange:");
    if ([settings respondsToSelector:setRange]) {
        CAFrameRateRange range = CAFrameRateRangeMake(120, 120, 120);
        ((void (*)(id, SEL, CAFrameRateRange))objc_msgSend)(settings, setRange, range);
    }
    SEL setReason = NSSelectorFromString(@"setHighFrameRateReason:");
    if ([settings respondsToSelector:setReason])
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(settings, setReason, 1114123);
}

static id RTSmoothBSAnimationSettings(double duration, double delay, double speed) {
    static Class factoryClass;
    static CAMediaTimingFunction *timing;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        factoryClass = NSClassFromString(@"BSAnimationSettings");
        timing = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    });
    id settings = RTCreateAnimationSettings(factoryClass, duration, delay, speed,
                                            RTCurrentAcceleration(), timing);
    RTApply120FrameRate(settings);
    return settings;
}

%group RTUIKitAnimations
%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (!RTAnimationHooksActive()) {
        %orig(duration, animations);
        return;
    }
    [self animateWithDuration:duration delay:0 options:0
                   animations:animations completion:nil];
}
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    if (!RTAnimationHooksActive()) {
        %orig(duration, animations, completion);
        return;
    }
    [self animateWithDuration:duration delay:0 options:0
                   animations:animations completion:completion];
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    RTAnimationDepth++;
    @try {
        NSTimeInterval value = RTConvertingSpringAnimation ? duration : RTDuration(duration);
        NSTimeInterval wait = RTConvertingSpringAnimation ? delay : RTDelay(delay, duration);
        UIViewAnimationOptions smoothed = RTSmoothOptions(options);
        %orig(value, wait, smoothed, animations, completion);
    } @finally { RTAnimationDepth--; }
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
    usingSpringWithDamping:(CGFloat)damping initialSpringVelocity:(CGFloat)velocity
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    if (RTAnimationDepth || !RTAnimationHooksActive()) {
        %orig(duration, delay, damping, velocity, options, animations, completion);
        return;
    }
    RTAnimationDepth++;
    BOOL wasConverting = RTConvertingSpringAnimation;
    @try {
        RTConvertingSpringAnimation = YES;
        [UIView animateWithDuration:RTDuration(duration) delay:RTDelay(delay, duration)
                           options:RTSmoothOptions(options) animations:animations completion:completion];
    } @finally {
        RTConvertingSpringAnimation = wasConverting;
        RTAnimationDepth--;
    }
}
%end
%end

%group RTUnlockSpringHooks
%hook UIView
+ (void)_animateUsingSpringWithTension:(double)tension friction:(double)friction
                          interactive:(BOOL)interactive animations:(void (^)(void))animations
                           completion:(void (^)(BOOL))completion {
    if (RTAnimationDepth || !RTUnlockTransition || !RTAnimationHooksActive() || interactive ||
        !isfinite(tension) || tension <= 0 || !isfinite(friction) || friction <= 0) {
        %orig(tension, friction, interactive, animations, completion);
        return;
    }
    CASpringAnimation *spring = [CASpringAnimation animation];
    spring.mass = 1.0;
    spring.stiffness = tension;
    spring.damping = friction;
    spring.initialVelocity = 0.0;
    double duration = spring.settlingDuration;
    if (!isfinite(duration) || duration <= 0.0 || duration > 10.0) {
        %orig(tension, friction, interactive, animations, completion);
        return;
    }
    // This call already has its final duration; the public UIKit hook must not scale it again.
    RTAnimationDepth++;
    @try {
        [self animateWithDuration:duration / RTAnimationSpeed(RTCurrentAcceleration()) delay:0
            options:RTSmoothOptions(UIViewAnimationOptionAllowUserInteraction)
            animations:animations completion:completion];
    } @finally { RTAnimationDepth--; }
}
%end
%end

%group RTPropertyAnimations
%hook UIViewPropertyAnimator
- (id)initWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve
           animations:(void (^)(void))animations {
    RTAnimationDepth++;
    @try {
        if (RTAdjustPropertyAnimator(duration)) curve = UIViewAnimationCurveEaseOut;
        return %orig(RTDuration(duration), curve, animations);
    } @finally { RTAnimationDepth--; }
}
- (id)initWithDuration:(NSTimeInterval)duration timingParameters:(id<UITimingCurveProvider>)timing {
    RTAnimationDepth++;
    @try {
        if (RTAdjustPropertyAnimator(duration))
            timing = [[UICubicTimingParameters alloc] initWithAnimationCurve:UIViewAnimationCurveEaseOut];
        return %orig(RTDuration(duration), timing);
    } @finally { RTAnimationDepth--; }
}
- (id)initWithDuration:(NSTimeInterval)duration controlPoint1:(CGPoint)p1
        controlPoint2:(CGPoint)p2 animations:(void (^)(void))animations {
    RTAnimationDepth++;
    @try {
        if (RTAdjustPropertyAnimator(duration)) {
            p1 = CGPointMake(0, 0);
            p2 = CGPointMake(0.58, 1);
        }
        return %orig(RTDuration(duration), p1, p2, animations);
    } @finally { RTAnimationDepth--; }
}
- (id)initWithDuration:(NSTimeInterval)duration dampingRatio:(CGFloat)damping
           animations:(void (^)(void))animations {
    if (RTAnimationDepth == 0 && RTAnimationHooksActive() && duration >= 0.12 && duration <= 1.0)
        return [self initWithDuration:duration curve:UIViewAnimationCurveEaseOut animations:animations];
    return %orig(duration, damping, animations);
}
+ (id)runningPropertyAnimatorWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
                                 options:(UIViewAnimationOptions)options
                              animations:(void (^)(void))animations
                              completion:(void (^)(UIViewAnimatingPosition))completion {
    RTAnimationDepth++;
    @try {
        return %orig(RTDuration(duration), RTDelay(delay, duration), RTSmoothOptions(options), animations, completion);
    } @finally { RTAnimationDepth--; }
}
%end
%end

%group RTSBFNonSpring
%hook SBFAnimationSettings
- (id)BSAnimationSettings {
    id original = %orig;
    if (RTFolderAnimationDepth || objc_getAssociatedObject(self, &RTFolderSettingsKey)) {
        RTApply120FrameRate(original);
        return original;
    }
    NSNumber *kind = objc_getAssociatedObject(self, &RTLockSettingsKey);
    if (kind.integerValue == RTWakeSettings) {
        RTApply120FrameRate(original);
        return original;
    }
    BOOL previous = RTUnlockTransition;
    if (kind.integerValue == RTUnlockSettings) RTUnlockTransition = YES;
    @try {
        if (RTAnimationHooksActive()) {
            double duration = RTNumberForKey(self, @"duration");
            double speed = RTNumberForKey(self, @"speed");
            if (!isfinite(duration) || duration <= 0.0) {
                duration = RTNumberForKey(original, @"duration");
                speed = 1.0;
            }
            id settings = RTSmoothBSAnimationSettings(duration, RTNumberForKey(self, @"delay"), speed);
            if (settings) return settings;
        }
    } @finally { RTUnlockTransition = previous; }
    RTApply120FrameRate(original);
    return original;
}
%end
%end

static id RTMarkLockSettings(id settings, RTLockSettingsKind kind) {
    if (settings) objc_setAssociatedObject(settings, &RTLockSettingsKey, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return settings;
}

static id RTMarkFolderSettings(id owner, id settings) {
    if (settings && RTFolderSettingsClass && [owner isKindOfClass:RTFolderSettingsClass])
        objc_setAssociatedObject(settings, &RTFolderSettingsKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return settings;
}

%group RTFolderCentralSettingsHooks
%hook SBHIconAnimationSettings
- (id)centralAnimationSettings { return RTMarkFolderSettings(self, %orig); }
%end
%end

%group RTFolderScaleSettingsHooks
%hook SBHScaleZoomSettings
- (id)crossfadeSettings { return RTMarkFolderSettings(self, %orig); }
- (id)effectiveCrossfadeAnimationSettings { return RTMarkFolderSettings(self, %orig); }
- (id)iconGridFadeSettings { return RTMarkFolderSettings(self, %orig); }
- (id)outerFolderFadeSettings { return RTMarkFolderSettings(self, %orig); }
%end
%end

%group RTFolderInnerSettingsHooks
%hook SBHFolderZoomSettings
- (id)innerFolderFadeSettings { return RTMarkFolderSettings(self, %orig); }
%end
%end

%group RTFolderOuterAnimationHooks
%hook SBFolderIconZoomAnimator
- (void)_prepareAnimation {
    RTFolderAnimationDepth++;
    @try { %orig; }
    @finally { RTFolderAnimationDepth--; }
}
- (void)_performAnimationToFraction:(double)fraction withCentralAnimationSettings:(id)settings
                             delay:(double)delay alreadyAnimating:(BOOL)animating
                  sharedCompletion:(id)completion {
    RTFolderAnimationDepth++;
    @try { %orig(fraction, settings, delay, animating, completion); }
    @finally { RTFolderAnimationDepth--; }
}
%end
%end

%group RTFolderInnerAnimationHooks
%hook _SBInnerFolderIconZoomAnimator
- (void)_prepareAnimation {
    RTFolderAnimationDepth++;
    @try { %orig; }
    @finally { RTFolderAnimationDepth--; }
}
- (void)_animateToFraction:(double)fraction afterDelay:(double)delay withSharedCompletion:(id)completion {
    RTFolderAnimationDepth++;
    @try { %orig(fraction, delay, completion); }
    @finally { RTFolderAnimationDepth--; }
}
%end
%end

static double RTWakeSpeed(double original) {
    if (!atomic_load(&RTEnabled) || !atomic_load(&RTWakeAnimations) ||
        atomic_load(&RTAnimationExcluded) || UIAccessibilityIsReduceMotionEnabled() ||
        !isfinite(original) || original <= 0.0) return original;
    return RTSmoothPlaybackSpeed(original, atomic_load(&RTWakeAcceleration));
}

%group RTWakeSpeedHooks
%hook SBFWakeAnimationSettings
- (double)speedMultiplierForWake { return RTWakeSpeed(%orig); }
%end
%end

%group RTWakeControllerSpeedHooks
%hook SBScreenWakeAnimationController
+ (double)_animationSpeedForBacklightChangeSource:(long long)source isWake:(BOOL)wake {
    double original = %orig;
    return wake ? RTWakeSpeed(original) : original;
}
%end
%end

%group RTWakeContextHooks
%hook SBScreenWakeAnimationController
- (void)_startWakeAnimationsForWaking:(BOOL)waking animationSettings:(id)settings {
    BOOL previous = RTWakeTransition;
    RTWakeTransition = YES;
    @try { %orig(waking, settings); }
    @finally { RTWakeTransition = previous; }
}
%end
%end

%group RTWakeSettingsHooks
%hook SBFWakeAnimationSettings
- (id)contentWakeSettings { return RTMarkLockSettings(%orig, RTWakeSettings); }
- (id)awakeWallpaperFilterSettings { return RTMarkLockSettings(%orig, RTWakeSettings); }
- (id)sleepWallpaperFilterSettings { return RTMarkLockSettings(%orig, RTWakeSettings); }
%end
%end

%group RTUnlockSettingsHooks
%hook CSLockScreenSettings
- (id)unlockWallpaperOutSettings { return RTMarkLockSettings(%orig, RTUnlockSettings); }
- (id)unlockWallpaperInSettings { return RTMarkLockSettings(%orig, RTUnlockSettings); }
- (id)unlockToPhoneWallpaperOutSettings { return RTMarkLockSettings(%orig, RTUnlockSettings); }
- (id)unlockToPhoneWallpaperInSettings { return RTMarkLockSettings(%orig, RTUnlockSettings); }
%end
%end

static BOOL RTLockScreenVisible(void) {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    SEL shared = NSSelectorFromString(@"sharedInstance");
    NSMethodSignature *sharedSignature = [managerClass methodSignatureForSelector:shared];
    if (sharedSignature.numberOfArguments != 2 || sharedSignature.methodReturnType[0] != '@') return NO;
    id manager = ((id (*)(id, SEL))objc_msgSend)(managerClass, shared);
    for (NSString *name in @[@"isUILocked", @"isLockScreenVisible"]) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature = [manager methodSignatureForSelector:selector];
        if (signature.numberOfArguments == 2 &&
            (signature.methodReturnType[0] == 'B' || signature.methodReturnType[0] == 'c') &&
            ((BOOL (*)(id, SEL))objc_msgSend)(manager, selector)) return YES;
    }
    return NO;
}

%group RTUnlockTransitionHooks
%hook SBCoverSheetSlidingViewController
- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated
                      withCompletion:(id)completion {
    BOOL previous = RTUnlockTransition;
    // CoverSheet presentation and finger tracking keep native timing.
    RTUnlockTransition = !presented && animated && RTLockScreenVisible();
    @try {
        %orig(presented, animated, completion);
    } @finally { RTUnlockTransition = previous; }
}
%end
%end

static BOOL RTMethodMatches(Class cls, NSString *name, const char *result, NSUInteger count) {
    NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:NSSelectorFromString(name)];
    return signature && signature.numberOfArguments == count &&
        strcmp(signature.methodReturnType, result) == 0;
}

static BOOL RTBoolArgument(NSMethodSignature *signature, NSUInteger index) {
    const char *type = [signature getArgumentTypeAtIndex:index];
    return type[0] == 'B' || type[0] == 'c';
}

void RTInstallAnimationHooks(BOOL springboard) {
    %init(RTUIKitAnimations);
    %init(RTPropertyAnimations);
    Class settingsClass = NSClassFromString(@"SBFAnimationSettings");
    if (springboard && RTMethodMatches(settingsClass, @"BSAnimationSettings", @encode(id), 2)) {
        %init(RTSBFNonSpring);
    }
    if (!springboard) return;
    RTFolderSettingsClass = NSClassFromString(@"SBHFolderZoomSettings");
    Class iconSettings = NSClassFromString(@"SBHIconAnimationSettings");
    if (RTFolderSettingsClass && RTMethodMatches(iconSettings, @"centralAnimationSettings", @encode(id), 2)) {
        %init(RTFolderCentralSettingsHooks);
    }
    Class scaleSettings = NSClassFromString(@"SBHScaleZoomSettings");
    if (RTFolderSettingsClass && RTMethodMatches(scaleSettings, @"crossfadeSettings", @encode(id), 2) &&
        RTMethodMatches(scaleSettings, @"effectiveCrossfadeAnimationSettings", @encode(id), 2) &&
        RTMethodMatches(scaleSettings, @"iconGridFadeSettings", @encode(id), 2) &&
        RTMethodMatches(scaleSettings, @"outerFolderFadeSettings", @encode(id), 2)) {
        %init(RTFolderScaleSettingsHooks);
    }
    if (RTMethodMatches(RTFolderSettingsClass, @"innerFolderFadeSettings", @encode(id), 2)) {
        %init(RTFolderInnerSettingsHooks);
    }
    Class outerFolder = NSClassFromString(@"SBFolderIconZoomAnimator");
    NSMethodSignature *outer = [outerFolder instanceMethodSignatureForSelector:NSSelectorFromString(
        @"_performAnimationToFraction:withCentralAnimationSettings:delay:alreadyAnimating:sharedCompletion:")];
    if (RTMethodMatches(outerFolder, @"_prepareAnimation", @encode(void), 2) &&
        outer.numberOfArguments == 7 && strcmp(outer.methodReturnType, @encode(void)) == 0 &&
        strcmp([outer getArgumentTypeAtIndex:2], @encode(double)) == 0 &&
        [outer getArgumentTypeAtIndex:3][0] == '@' &&
        strcmp([outer getArgumentTypeAtIndex:4], @encode(double)) == 0 &&
        RTBoolArgument(outer, 5) && [outer getArgumentTypeAtIndex:6][0] == '@') {
        %init(RTFolderOuterAnimationHooks);
    }
    Class innerFolder = NSClassFromString(@"_SBInnerFolderIconZoomAnimator");
    NSMethodSignature *inner = [innerFolder instanceMethodSignatureForSelector:NSSelectorFromString(
        @"_animateToFraction:afterDelay:withSharedCompletion:")];
    if (RTMethodMatches(innerFolder, @"_prepareAnimation", @encode(void), 2) &&
        inner.numberOfArguments == 5 && strcmp(inner.methodReturnType, @encode(void)) == 0 &&
        strcmp([inner getArgumentTypeAtIndex:2], @encode(double)) == 0 &&
        strcmp([inner getArgumentTypeAtIndex:3], @encode(double)) == 0 &&
        [inner getArgumentTypeAtIndex:4][0] == '@') {
        %init(RTFolderInnerAnimationHooks);
    }
    Class wake = NSClassFromString(@"SBFWakeAnimationSettings");
    Class controller = NSClassFromString(@"SBScreenWakeAnimationController");
    NSMethodSignature *wakeSpeed = [controller methodSignatureForSelector:NSSelectorFromString(
        @"_animationSpeedForBacklightChangeSource:isWake:")];
    if (wakeSpeed.numberOfArguments == 4 && strcmp(wakeSpeed.methodReturnType, @encode(double)) == 0 &&
        strcmp([wakeSpeed getArgumentTypeAtIndex:2], @encode(long long)) == 0 && RTBoolArgument(wakeSpeed, 3)) {
        %init(RTWakeControllerSpeedHooks);
    } else if (RTMethodMatches(wake, @"speedMultiplierForWake", @encode(double), 2)) {
        %init(RTWakeSpeedHooks);
    }
    NSMethodSignature *wakeContext = [controller instanceMethodSignatureForSelector:NSSelectorFromString(
        @"_startWakeAnimationsForWaking:animationSettings:")];
    if (wakeContext.numberOfArguments == 4 && strcmp(wakeContext.methodReturnType, @encode(void)) == 0 &&
        RTBoolArgument(wakeContext, 2) && [wakeContext getArgumentTypeAtIndex:3][0] == '@') {
        %init(RTWakeContextHooks);
    }
    if (RTMethodMatches(wake, @"contentWakeSettings", @encode(id), 2) &&
        RTMethodMatches(wake, @"awakeWallpaperFilterSettings", @encode(id), 2) &&
        RTMethodMatches(wake, @"sleepWallpaperFilterSettings", @encode(id), 2)) {
        %init(RTWakeSettingsHooks);
    }
    Class lock = NSClassFromString(@"CSLockScreenSettings");
    if (RTMethodMatches(lock, @"unlockWallpaperOutSettings", @encode(id), 2) &&
        RTMethodMatches(lock, @"unlockWallpaperInSettings", @encode(id), 2) &&
        RTMethodMatches(lock, @"unlockToPhoneWallpaperOutSettings", @encode(id), 2) &&
        RTMethodMatches(lock, @"unlockToPhoneWallpaperInSettings", @encode(id), 2)) {
        %init(RTUnlockSettingsHooks);
    }
    Class sliding = NSClassFromString(@"SBCoverSheetSlidingViewController");
    SEL finish = NSSelectorFromString(@"_finishTransitionToPresented:animated:withCompletion:");
    NSMethodSignature *signature = [sliding instanceMethodSignatureForSelector:finish];
    NSMethodSignature *spring = [UIView methodSignatureForSelector:NSSelectorFromString(
        @"_animateUsingSpringWithTension:friction:interactive:animations:completion:")];
    if (signature.numberOfArguments == 5 && strcmp(signature.methodReturnType, @encode(void)) == 0 &&
        RTBoolArgument(signature, 2) && RTBoolArgument(signature, 3) &&
        [signature getArgumentTypeAtIndex:4][0] == '@' &&
        spring.numberOfArguments == 7 && strcmp(spring.methodReturnType, @encode(void)) == 0 &&
        strcmp([spring getArgumentTypeAtIndex:2], @encode(double)) == 0 &&
        strcmp([spring getArgumentTypeAtIndex:3], @encode(double)) == 0 &&
        RTBoolArgument(spring, 4) && [spring getArgumentTypeAtIndex:5][0] == '@' &&
        [spring getArgumentTypeAtIndex:6][0] == '@') {
        %init(RTUnlockSpringHooks);
        %init(RTUnlockTransitionHooks);
    }
}

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Settings.h"
#import "AnimationSettings.h"

static __thread unsigned RTAnimationDepth;
static __thread BOOL RTConvertingSpringAnimation;

static BOOL RTAnimationHooksActive(void) {
    return atomic_load(&RTEnabled) && atomic_load(&RTAnimations) &&
           !atomic_load(&RTAnimationExcluded) && !UIAccessibilityIsReduceMotionEnabled();
}

static NSTimeInterval RTDuration(NSTimeInterval duration) {
    return RTAnimationDepth == 1 && RTAnimationHooksActive()
        ? RTScaledDuration(duration, atomic_load(&RTAnimationFactor)) : duration;
}

static UIViewAnimationOptions RTSmoothOptions(UIViewAnimationOptions options) {
    if (!RTAnimationHooksActive()) return options;
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
                                            atomic_load(&RTAnimationFactor), timing);
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
    [self animateWithDuration:duration delay:0 options:RTSmoothOptions(0)
                   animations:animations completion:nil];
}
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    if (!RTAnimationHooksActive()) {
        %orig(duration, animations, completion);
        return;
    }
    [self animateWithDuration:duration delay:0 options:RTSmoothOptions(0)
                   animations:animations completion:completion];
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    RTAnimationDepth++;
    @try {
        NSTimeInterval value = RTConvertingSpringAnimation ? duration : RTDuration(duration);
        UIViewAnimationOptions smoothed = RTSmoothOptions(options);
        %orig(value, delay, smoothed, animations, completion);
    } @finally { RTAnimationDepth--; }
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
    usingSpringWithDamping:(CGFloat)damping initialSpringVelocity:(CGFloat)velocity
                   options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                completion:(void (^)(BOOL))completion {
    if (!RTAnimationHooksActive()) {
        %orig(duration, delay, damping, velocity, options, animations, completion);
        return;
    }
    RTAnimationDepth++;
    BOOL wasConverting = RTConvertingSpringAnimation;
    @try {
        RTConvertingSpringAnimation = YES;
        [UIView animateWithDuration:RTDuration(duration) delay:delay
                           options:RTSmoothOptions(options) animations:animations completion:completion];
    } @finally {
        RTConvertingSpringAnimation = wasConverting;
        RTAnimationDepth--;
    }
}
%end

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
        return %orig(RTDuration(duration), delay, RTSmoothOptions(options), animations, completion);
    } @finally { RTAnimationDepth--; }
}
%end
%end

%group RTSBFNonSpring
%hook SBFAnimationSettings
- (id)BSAnimationSettings {
    id original = %orig;
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
    RTApply120FrameRate(original);
    return original;
}
%end
%end

void RTInstallAnimationHooks(BOOL springboard) {
    %init(RTUIKitAnimations);
    Class settingsClass = NSClassFromString(@"SBFAnimationSettings");
    if (springboard && [settingsClass instancesRespondToSelector:NSSelectorFromString(@"BSAnimationSettings")]) {
        %init(RTSBFNonSpring);
    }
}

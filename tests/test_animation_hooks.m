#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Settings.h"
#import "AnimationSettings.h"
#include <assert.h>

static BOOL reducedMotion;
static NSMutableArray<NSNumber *> *durations;
static double lastDelay;
static UIViewAnimationOptions lastOptions;
static BOOL originalSpring;
static CGPoint lastP1, lastP2;
BOOL UIAccessibilityIsReduceMotionEnabled(void) { return reducedMotion; }

@implementation UIScreen
+ (instancetype)mainScreen {
    static UIScreen *screen;
    if (!screen) { screen = [UIScreen new]; screen.maximumFramesPerSecond = 60; }
    return screen;
}
@end
@implementation UICubicTimingParameters
- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)curve {
    if ((self = [super init])) _curve = curve;
    return self;
}
@end
@implementation UIView
+ (void)animateWithDuration:(double)d animations:(void (^)(void))a {
    [self animateWithDuration:d delay:0 options:0 animations:a completion:nil];
}
+ (void)animateWithDuration:(double)d animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    [self animateWithDuration:d delay:0 options:0 animations:a completion:c];
}
+ (void)animateWithDuration:(double)d delay:(double)delay options:(UIViewAnimationOptions)o
                animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    [durations addObject:@(d)]; lastDelay = delay; lastOptions = o;
    if (a) a();
    if (c) c(YES);
}
+ (void)animateWithDuration:(double)d delay:(double)delay usingSpringWithDamping:(CGFloat)damping
     initialSpringVelocity:(CGFloat)v options:(UIViewAnimationOptions)o
                animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    originalSpring = YES;
    [self animateWithDuration:d delay:delay options:o animations:a completion:c];
}
@end
@implementation UIViewPropertyAnimator
- (instancetype)initWithDuration:(double)d timingParameters:(id<UITimingCurveProvider>)t {
    if ((self = [super init])) { _duration = d; _timing = t; }
    return self;
}
- (instancetype)initWithDuration:(double)d curve:(UIViewAnimationCurve)c animations:(void (^)(void))a {
    return [self initWithDuration:d timingParameters:[[UICubicTimingParameters alloc] initWithAnimationCurve:c]];
}
- (instancetype)initWithDuration:(double)d controlPoint1:(CGPoint)p1 controlPoint2:(CGPoint)p2 animations:(void (^)(void))a {
    lastP1 = p1; lastP2 = p2;
    return [self initWithDuration:d timingParameters:nil];
}
- (instancetype)initWithDuration:(double)d dampingRatio:(CGFloat)r animations:(void (^)(void))a {
    originalSpring = YES;
    return [self initWithDuration:d timingParameters:nil];
}
+ (instancetype)runningPropertyAnimatorWithDuration:(double)d delay:(double)delay options:(UIViewAnimationOptions)o
                                        animations:(void (^)(void))a completion:(void (^)(UIViewAnimatingPosition))c {
    lastDelay = delay; lastOptions = o;
    UIViewPropertyAnimator *animator = [[self alloc] initWithDuration:d curve:(o >> 16) & 3 animations:a];
    if (c) c(UIViewAnimatingPositionEnd);
    return animator;
}
@end

// The iOS 16 factory result is immutable and intentionally has no setSpeed:.
@interface BSAnimationSettings : NSObject
@property (readonly) double duration;
@property (readonly) double delay;
@property (readonly) id timing;
+ (id)settingsWithDuration:(double)d delay:(double)delay timingFunction:(id)timing;
@end
@implementation BSAnimationSettings
+ (id)settingsWithDuration:(double)d delay:(double)delay timingFunction:(id)t {
    BSAnimationSettings *settings = [self new];
    settings->_duration = d; settings->_delay = delay; settings->_timing = t;
    return settings;
}
@end
@interface SBFAnimationSettings : NSObject
@property double duration;
@property double delay;
@property double speed;
- (id)BSAnimationSettings;
@end
@implementation SBFAnimationSettings
- (id)BSAnimationSettings {
    return [BSAnimationSettings settingsWithDuration:self.duration delay:self.delay timingFunction:nil];
}
@end

static void near(double actual, double expected) { assert(fabs(actual - expected) < 1e-9); }
static void testUIKit(void) {
    __block unsigned completionCount = 0;
    [UIView animateWithDuration:0.5 animations:^{} completion:^(BOOL done) {
        assert(done); completionCount++;
    }];
    near(durations.lastObject.doubleValue, 0.4); assert(completionCount == 1);
    assert((lastOptions & (3 << 16)) == UIViewAnimationOptionCurveEaseOut);
    [UIView animateWithDuration:0.5 delay:0.2 usingSpringWithDamping:0.4 initialSpringVelocity:1
        options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [UIView animateWithDuration:0.3 animations:^{}];
        } completion:nil];
    assert(!originalSpring);
    near(durations[durations.count - 2].doubleValue, 0.4);
    near(durations.lastObject.doubleValue, 0.3); // nested call is not scaled twice
    [UIView animateWithDuration:0.5 delay:0.2 options:UIViewAnimationOptionAllowUserInteraction animations:^{} completion:nil];
    near(lastDelay, 0.2);
    assert(lastOptions & UIViewAnimationOptionAllowUserInteraction);
    assert(lastOptions & UIViewAnimationOptionBeginFromCurrentState);
}
static void testPropertyAnimator(void) {
    UIViewPropertyAnimator *a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5
        curve:UIViewAnimationCurveLinear animations:^{}];
    near(a.duration, 0.4);
    assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveEaseOut);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 timingParameters:nil];
    near(a.duration, 0.4); assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveEaseOut);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 controlPoint1:CGPointMake(1, 0)
        controlPoint2:CGPointMake(1, 0) animations:^{}];
    near(a.duration, 0.4); near(lastP1.x, 0); near(lastP2.x, 0.58); near(lastP2.y, 1);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 dampingRatio:0.4 animations:^{}];
    near(a.duration, 0.4); assert(!originalSpring);
    __block unsigned finished = 0;
    a = [UIViewPropertyAnimator runningPropertyAnimatorWithDuration:0.5 delay:0.2
        options:UIViewAnimationOptionAllowUserInteraction animations:^{} completion:^(UIViewAnimatingPosition p) {
            assert(p == UIViewAnimatingPositionEnd); finished++;
        }];
    near(a.duration, 0.4); near(lastDelay, 0.2); assert(finished == 1);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:5 curve:UIViewAnimationCurveLinear animations:^{}];
    near(a.duration, 5); assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveLinear);
}
static void testSpringBoard(void) {
    BSAnimationSettings *legacy = [BSAnimationSettings settingsWithDuration:0.3 delay:0.15 timingFunction:nil];
    SEL setter = NSSelectorFromString(@"setSpeed:");
    if ([legacy respondsToSelector:setter])
        ((void (*)(id, SEL, double))objc_msgSend)(legacy, setter, 1.25);
    near(legacy.duration, 0.3); // reproduces the 0.4.4 no-op on an immutable result
    SBFAnimationSettings *source = [SBFAnimationSettings new];
    source.duration = 0.3; source.delay = 0.15; source.speed = 1;
    BSAnimationSettings *result = [source BSAnimationSettings];
    assert(![result respondsToSelector:NSSelectorFromString(@"setSpeed:")]);
    near(result.duration, 0.24); near(result.delay, 0.15); near(source.duration, 0.3);
    assert(result.timing);
    source.speed = 2;
    near([[source BSAnimationSettings] duration], 0.12);
    atomic_store(&RTAnimationFactor, 2);
    near([[source BSAnimationSettings] duration], 0.24);
    atomic_store(&RTAnimationFactor, 1);
    assert(!RTCreateAnimationSettings(Nil, 0.3, 0, 1, 1, nil));
    assert(!RTCreateAnimationSettings(BSAnimationSettings.class, NAN, 0, 1, 1, nil));
    source.duration = 3;
    near([[source BSAnimationSettings] duration], 3);
}
int main(void) {
    @autoreleasepool {
        durations = [NSMutableArray array];
        atomic_store(&RTHighRefresh, false);
        RTInstallAnimationHooks(YES);
        testUIKit(); testPropertyAnimator(); testSpringBoard();
        for (unsigned reason = 0; reason < 4; reason++) {
            atomic_store(&RTEnabled, reason != 0);
            atomic_store(&RTAnimations, reason != 1);
            atomic_store(&RTAnimationExcluded, reason == 2);
            reducedMotion = reason == 3;
            [UIView animateWithDuration:0.5 animations:^{}];
            near(durations.lastObject.doubleValue, 0.5);
            UIViewPropertyAnimator *a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5
                curve:UIViewAnimationCurveLinear animations:^{}];
            near(a.duration, 0.5);
            assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveLinear);
            SBFAnimationSettings *source = [SBFAnimationSettings new]; source.duration = 0.3; source.speed = 1;
            near([[source BSAnimationSettings] duration], 0.3);
        }
        puts("PASS: real Logos hooks on mock UIKit/BS classes; immutable factory, property animators, nested scaling, callbacks, gating");
    }
    return 0;
}

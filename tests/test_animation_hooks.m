#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Settings.h"
#import "AnimationSettings.h"
#include <assert.h>
#ifndef RT_ANIMATION_FIXTURE_NAMESPACE_H
#error "Force-include tests/animation_fixture_namespace.h for both test translation units"
#endif

static BOOL reducedMotion;
static NSMutableArray<NSNumber *> *durations;
static double lastDelay;
static UIViewAnimationOptions lastOptions;
static BOOL originalSpring;
static BOOL raiseDuringUnlock;
static BOOL raiseDuringFolder;
static BOOL lockScreenVisible = YES;
static BOOL useWakeFallback;
static CGPoint lastP1, lastP2;
static CGFloat lastDamping, lastVelocity, lastDampingRatio;
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
    lastDamping = damping; lastVelocity = v;
    [self animateWithDuration:d delay:delay options:o animations:a completion:c];
}
+ (void)_animateUsingSpringWithTension:(double)t friction:(double)f interactive:(BOOL)i
                           animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    originalSpring = YES;
    [durations addObject:@0.5];
    if (a) a();
    if (c) c(YES);
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
    originalSpring = YES; lastDampingRatio = r;
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
@interface RTTestAnimationSettings : NSObject
@property (readonly) double duration;
@property (readonly) double delay;
@property (readonly) id timingFunction;
+ (id)settingsWithDuration:(double)d delay:(double)delay timingFunction:(id)timing;
@end
@implementation RTTestAnimationSettings
+ (id)settingsWithDuration:(double)d delay:(double)delay timingFunction:(id)t {
    RTTestAnimationSettings *settings = [self new];
    settings->_duration = d; settings->_delay = delay; settings->_timingFunction = t;
    return settings;
}
@end
// Test-only class name: the unprefixed name may already exist in BaseBoard.
// Keep the BSAnimationSettings export selector unchanged below.
@interface RTAnimationFixture_BSAnimationSettings : RTTestAnimationSettings
@end
@implementation RTAnimationFixture_BSAnimationSettings
@end

@interface SBFAnimationSettings : NSObject
@property double duration;
@property double delay;
@property double speed;
@property (strong) id timingFunction;
- (id)BSAnimationSettings;
@end
@implementation SBFAnimationSettings
- (id)BSAnimationSettings {
    return [RTTestAnimationSettings settingsWithDuration:self.duration delay:self.delay timingFunction:self.timingFunction];
}
@end

@interface SBHIconAnimationSettings : NSObject
@property (strong) SBFAnimationSettings *centralAnimationSettings;
@end
@implementation SBHIconAnimationSettings
@end
@interface SBHScaleZoomSettings : SBHIconAnimationSettings
@property (strong) SBFAnimationSettings *crossfadeSettings;
@property (strong) SBFAnimationSettings *iconGridFadeSettings;
@property (strong) SBFAnimationSettings *outerFolderFadeSettings;
- (id)effectiveCrossfadeAnimationSettings;
@end
@implementation SBHScaleZoomSettings
- (id)effectiveCrossfadeAnimationSettings { return self.crossfadeSettings; }
@end
@interface SBHFolderZoomSettings : SBHScaleZoomSettings
@property (strong) SBFAnimationSettings *innerFolderFadeSettings;
@end
@implementation SBHFolderZoomSettings
@end
@interface SBHFolderOpenSettings : SBHFolderZoomSettings
@end
@implementation SBHFolderOpenSettings
@end
@interface SBHFolderCloseSettings : SBHFolderZoomSettings
@end
@implementation SBHFolderCloseSettings
@end

static double folderExportDuration;
static BOOL folderExportNative;
static double folderPropertyDuration;
static void folderFixtureAnimation(void) {
    [UIView animateWithDuration:0.5 delay:0.2 usingSpringWithDamping:0.4
        initialSpringVelocity:1 options:UIViewAnimationOptionCurveLinear
        animations:^{} completion:nil];
    UIViewPropertyAnimator *a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5
        curve:UIViewAnimationCurveLinear animations:^{}];
    folderPropertyDuration = a.duration;
    assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveLinear);
}
@interface SBFolderIconZoomAnimator : NSObject
- (void)_prepareAnimation;
- (void)_performAnimationToFraction:(double)fraction withCentralAnimationSettings:(id)settings
    delay:(double)delay alreadyAnimating:(BOOL)animating sharedCompletion:(id)completion;
@end
@implementation SBFolderIconZoomAnimator
- (void)_prepareAnimation { folderFixtureAnimation(); }
- (void)_performAnimationToFraction:(double)fraction withCentralAnimationSettings:(id)settings
    delay:(double)delay alreadyAnimating:(BOOL)animating sharedCompletion:(id)completion {
    if (raiseDuringFolder) [NSException raise:@"folder fixture" format:@"failure"];
    id result = [settings BSAnimationSettings];
    folderExportDuration = [result duration];
    folderExportNative = [result isMemberOfClass:RTTestAnimationSettings.class];
    folderFixtureAnimation();
    if (completion) ((void (^)(void))completion)();
}
@end
@interface _SBInnerFolderIconZoomAnimator : NSObject
- (void)_prepareAnimation;
- (void)_animateToFraction:(double)fraction afterDelay:(double)delay withSharedCompletion:(id)completion;
@end
@implementation _SBInnerFolderIconZoomAnimator
- (void)_prepareAnimation { folderFixtureAnimation(); }
- (void)_animateToFraction:(double)fraction afterDelay:(double)delay withSharedCompletion:(id)completion {
    folderFixtureAnimation();
    if (completion) ((void (^)(void))completion)();
}
@end

@interface SBFWakeAnimationSettings : NSObject
@property (strong) SBFAnimationSettings *contentWakeSettings;
@property (strong) SBFAnimationSettings *awakeWallpaperFilterSettings;
@property (strong) SBFAnimationSettings *sleepWallpaperFilterSettings;
- (double)speedMultiplierForWake;
- (double)speedMultiplierForLiftToWake;
@end
@implementation SBFWakeAnimationSettings
- (double)speedMultiplierForWake { return 1.2; }
- (double)speedMultiplierForLiftToWake { return 1.4; }
@end

@interface SBScreenWakeAnimationController : NSObject
+ (double)_animationSpeedForBacklightChangeSource:(long long)source isWake:(BOOL)wake;
- (void)_startWakeAnimationsForWaking:(BOOL)wake animationSettings:(id)settings;
@end
@implementation SBScreenWakeAnimationController
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if (useWakeFallback && selector == NSSelectorFromString(@"_animationSpeedForBacklightChangeSource:isWake:"))
        return nil;
    return [super methodSignatureForSelector:selector];
}
+ (double)_animationSpeedForBacklightChangeSource:(long long)source isWake:(BOOL)wake {
    SBFWakeAnimationSettings *settings = [SBFWakeAnimationSettings new];
    double speed = source == 20 ? settings.speedMultiplierForLiftToWake : 1.0;
    return wake ? speed * settings.speedMultiplierForWake : speed;
}
- (void)_startWakeAnimationsForWaking:(BOOL)wake animationSettings:(id)settings {
    [UIView animateWithDuration:0.5 animations:^{}];
}
@end

@interface SBLockScreenManager : NSObject
+ (id)sharedInstance;
- (BOOL)isUILocked;
- (BOOL)isLockScreenVisible;
@end
@implementation SBLockScreenManager
+ (id)sharedInstance {
    static SBLockScreenManager *manager;
    if (!manager) manager = [self new];
    return manager;
}
- (BOOL)isUILocked { return lockScreenVisible; }
- (BOOL)isLockScreenVisible { return lockScreenVisible; }
@end

@interface CSLockScreenSettings : NSObject
@property (strong) SBFAnimationSettings *unlockWallpaperOutSettings;
@property (strong) SBFAnimationSettings *unlockWallpaperInSettings;
@property (strong) SBFAnimationSettings *unlockToPhoneWallpaperOutSettings;
@property (strong) SBFAnimationSettings *unlockToPhoneWallpaperInSettings;
@end
@implementation CSLockScreenSettings
@end

@interface SBCoverSheetSlidingViewController : NSObject
- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated withCompletion:(id)completion;
@end
@implementation SBCoverSheetSlidingViewController
- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated withCompletion:(id)completion {
    if (raiseDuringUnlock) [NSException raise:@"fixture" format:@"unlock failure"];
    [UIView _animateUsingSpringWithTension:300 friction:34 interactive:NO animations:^{}
        completion:completion];
}
@end

static void testFixtureClasses(void) {
    // Verify raw prefixed runtime names as well as every redirected lookup.
    // Token pasting/stringification intentionally bypass the type-name aliases.
#define RT_ASSERT_FIXTURE_CLASS(cls) \
    assert(NSClassFromString(@"RTAnimationFixture_" @#cls) == RTAnimationFixture_ ## cls.class); \
    assert(NSClassFromString(@#cls) == RTAnimationFixture_ ## cls.class); \
    assert(objc_getClass(#cls) == RTAnimationFixture_ ## cls.class);
    RT_ANIMATION_FIXTURE_CLASSES(RT_ASSERT_FIXTURE_CLASS)
#undef RT_ASSERT_FIXTURE_CLASS
}

static void near(double actual, double expected) { assert(fabs(actual - expected) < 1e-9); }
// 0.5 changes eligible timing only: caller options, curves and public spring
// parameters must survive; do not restore the old forced ease-out conversion.
static void testUIKit(void) {
    __block unsigned completionCount = 0;
    [UIView animateWithDuration:0.5 animations:^{} completion:^(BOOL done) {
        assert(done); completionCount++;
    }];
    near(durations.lastObject.doubleValue, 0.5 / 1.9); assert(completionCount == 1);
    assert(lastOptions == 0);
    originalSpring = NO;
    UIViewAnimationOptions springOptions = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear;
    [UIView animateWithDuration:0.5 delay:0.2 usingSpringWithDamping:0.4 initialSpringVelocity:1
        options:springOptions animations:^{
            assert(lastOptions == springOptions); near(lastDelay, 0.2 / 1.9);
            [UIView animateWithDuration:0.3 animations:^{}];
        } completion:^(BOOL done) { assert(done); completionCount++; }];
    assert(originalSpring && completionCount == 2);
    near(lastDamping, 0.4); near(lastVelocity, 1);
    near(durations[durations.count - 2].doubleValue, 0.5 / 1.9);
    near(durations.lastObject.doubleValue, 0.3); // nested call is not scaled twice
    [UIView animateWithDuration:0.5 delay:0.2 options:UIViewAnimationOptionAllowUserInteraction animations:^{} completion:nil];
    near(lastDelay, 0.2 / 1.9);
    assert(lastOptions == UIViewAnimationOptionAllowUserInteraction);
    UIViewAnimationOptions callerOptions = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.5 delay:0.2 options:callerOptions animations:^{} completion:nil];
    assert(lastOptions == callerOptions);
}
static void testPropertyAnimator(void) {
    UIViewPropertyAnimator *a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5
        curve:UIViewAnimationCurveLinear animations:^{}];
    near(a.duration, 0.5 / 1.9);
    assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveLinear);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 timingParameters:nil];
    near(a.duration, 0.5 / 1.9); assert(a.timing == nil);
    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc] initWithAnimationCurve:UIViewAnimationCurveEaseIn];
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 timingParameters:timing];
    near(a.duration, 0.5 / 1.9); assert(a.timing == timing);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 controlPoint1:CGPointMake(1, 0)
        controlPoint2:CGPointMake(1, 0) animations:^{}];
    near(a.duration, 0.5 / 1.9);
    near(lastP1.x, 1); near(lastP1.y, 0); near(lastP2.x, 1); near(lastP2.y, 0);
    originalSpring = NO;
    a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 dampingRatio:0.4 animations:^{}];
    near(a.duration, 0.5 / 1.9); assert(originalSpring); near(lastDampingRatio, 0.4);
    __block unsigned finished = 0;
    a = [UIViewPropertyAnimator runningPropertyAnimatorWithDuration:0.5 delay:0.2
        options:UIViewAnimationOptionAllowUserInteraction animations:^{} completion:^(UIViewAnimatingPosition p) {
            assert(p == UIViewAnimatingPositionEnd); finished++;
        }];
    near(a.duration, 0.5 / 1.9); near(lastDelay, 0.2 / 1.9); assert(finished == 1);
    assert(lastOptions == UIViewAnimationOptionAllowUserInteraction);
    a = [[UIViewPropertyAnimator alloc] initWithDuration:5 curve:UIViewAnimationCurveLinear animations:^{}];
    near(a.duration, 5); assert([(UICubicTimingParameters *)a.timing curve] == UIViewAnimationCurveLinear);
}
static void testSpringBoard(void) {
    RTTestAnimationSettings *legacy = [RTTestAnimationSettings settingsWithDuration:0.3 delay:0.15 timingFunction:nil];
    SEL setter = NSSelectorFromString(@"setSpeed:");
    if ([legacy respondsToSelector:setter])
        ((void (*)(id, SEL, double))objc_msgSend)(legacy, setter, 1.25);
    near(legacy.duration, 0.3); // reproduces the 0.4.4 no-op on an immutable result
    SBFAnimationSettings *source = [SBFAnimationSettings new];
    source.duration = 0.3; source.delay = 0.15; source.speed = 1;
    // The production factory must preserve the caller's timing object, not
    // synthesize a fixed curve; a missing timing function must remain nil.
    id timing = [NSObject new];
    source.timingFunction = timing;
    assert(NSClassFromString(@"BSAnimationSettings") == RTAnimationFixture_BSAnimationSettings.class);
    id result = [source BSAnimationSettings];
    assert(![result respondsToSelector:NSSelectorFromString(@"setSpeed:")]);
    near([result duration], 0.3 / 1.9); near([result delay], 0.15 / 1.9); near(source.duration, 0.3);
    assert([result timingFunction] == timing);
    assert([result isMemberOfClass:RTAnimationFixture_BSAnimationSettings.class]);
    source.timingFunction = nil;
    result = [source BSAnimationSettings];
    assert([result isMemberOfClass:RTAnimationFixture_BSAnimationSettings.class]);
    assert([result timingFunction] == nil);
    near([result duration], 0.3 / 1.9); near([result delay], 0.15 / 1.9);
    source.speed = 2;
    near([[source BSAnimationSettings] duration], 0.3 / 3.8);
    atomic_store(&RTAnimationFactor, 2);
    near([[source BSAnimationSettings] duration], 0.3 / 5.6);
    atomic_store(&RTAnimationFactor, 1);
    assert(!RTCreateAnimationSettings(Nil, 0.3, 0, 1, 1, nil));
    assert(!RTCreateAnimationSettings(RTAnimationFixture_BSAnimationSettings.class, NAN, 0, 1, 1, nil));
    RTTestAnimationSettings *fixture = RTCreateAnimationSettings(RTAnimationFixture_BSAnimationSettings.class, 0.3, 0, 1, 1, nil);
    near(fixture.duration, 0.3 / 1.9); assert(fixture.timingFunction == nil);
    source.duration = 3;
    near([[source BSAnimationSettings] duration], 3);
}

static void testAccelerationDirection(void) {
    SBFAnimationSettings *source = [SBFAnimationSettings new];
    source.duration = 0.5; source.speed = 1;
    for (unsigned i = 0; i <= 100; i++) {
        double level = i / 10.0;
        double expected = 0.5 / (1.0 + 0.9 * level);
        atomic_store(&RTAnimationFactor, level);
        [UIView animateWithDuration:0.5 animations:^{}];
        near(durations.lastObject.doubleValue, expected);
        UIViewPropertyAnimator *a = [[UIViewPropertyAnimator alloc] initWithDuration:0.5
            curve:UIViewAnimationCurveLinear animations:^{}];
        near(a.duration, expected);
        near([[source BSAnimationSettings] duration], expected);
        [UIView animateWithDuration:0.5 delay:0.2 options:0 animations:^{} completion:nil];
        near(durations.lastObject.doubleValue, expected);
        near(lastDelay, 0.2 / (1.0 + 0.9 * level));
    }
    atomic_store(&RTAnimationFactor, 1);
}

static SBFAnimationSettings *lockAnimation(void) {
    SBFAnimationSettings *s = [SBFAnimationSettings new]; s.duration = 0.5; s.speed = 1;
    return s;
}

static void testFolderAnimations(void) {
    atomic_store(&RTAnimationFactor, 10);
    for (Class cls in @[SBHFolderOpenSettings.class, SBHFolderCloseSettings.class]) {
        SBHFolderZoomSettings *settings = [cls new];
        settings.centralAnimationSettings = lockAnimation();
        settings.crossfadeSettings = lockAnimation();
        settings.iconGridFadeSettings = lockAnimation();
        settings.outerFolderFadeSettings = lockAnimation();
        settings.innerFolderFadeSettings = lockAnimation();
        for (SBFAnimationSettings *s in @[settings.centralAnimationSettings, settings.crossfadeSettings,
            settings.effectiveCrossfadeAnimationSettings, settings.iconGridFadeSettings,
            settings.outerFolderFadeSettings, settings.innerFolderFadeSettings]) {
            for (unsigned repeat = 0; repeat < 2; repeat++) {
                id result = [s BSAnimationSettings];
                near([result duration], 0.5);
                assert([result isMemberOfClass:RTTestAnimationSettings.class]);
            }
        }
    }
    SBHScaleZoomSettings *appSettings = [SBHScaleZoomSettings new];
    appSettings.centralAnimationSettings = lockAnimation();
    appSettings.crossfadeSettings = lockAnimation();
    near([[appSettings.centralAnimationSettings BSAnimationSettings] duration], 0.05);
    near([[appSettings.effectiveCrossfadeAnimationSettings BSAnimationSettings] duration], 0.05);

    SBFolderIconZoomAnimator *outer = [SBFolderIconZoomAnimator new];
    _SBInnerFolderIconZoomAnimator *inner = [_SBInnerFolderIconZoomAnimator new];
    __block unsigned completed = 0;
    for (unsigned opening = 0; opening <= 1; opening++) {
        originalSpring = NO;
        [outer _prepareAnimation];
        assert(originalSpring); near(durations.lastObject.doubleValue, 0.5);
        [outer _performAnimationToFraction:opening withCentralAnimationSettings:lockAnimation()
            delay:0.2 alreadyAnimating:NO sharedCompletion:^{
                [inner _animateToFraction:opening afterDelay:0.2 withSharedCompletion:^{ completed++; }];
            }];
        assert(originalSpring && folderExportNative);
        near(folderExportDuration, 0.5); near(folderPropertyDuration, 0.5);
        near(durations.lastObject.doubleValue, 0.5); near(lastDelay, 0.2);
        assert((lastOptions & (3 << 16)) == UIViewAnimationOptionCurveLinear);
        [inner _prepareAnimation];
        near(durations.lastObject.doubleValue, 0.5);
    }
    assert(completed == 2);
    raiseDuringFolder = YES;
    @try {
        [outer _performAnimationToFraction:1 withCentralAnimationSettings:nil delay:0
            alreadyAnimating:NO sharedCompletion:nil];
    } @catch (NSException *exception) { assert([exception.name isEqualToString:@"folder fixture"]); }
    raiseDuringFolder = NO;
    [UIView animateWithDuration:0.5 animations:^{}];
    near(durations.lastObject.doubleValue, 0.05);
    atomic_store(&RTAnimationFactor, 1);
}

static void testPhaseTiming(void) {
    atomic_store(&RTAnimationFactor, 1);
    [UIView animateWithDuration:0.5 delay:0.2 options:UIViewAnimationOptionCurveLinear animations:^{
        [UIView animateWithDuration:0.3 delay:0.1 options:UIViewAnimationOptionCurveEaseIn
            animations:^{} completion:nil];
    } completion:nil];
    near(durations[durations.count - 2].doubleValue, 0.5 / 1.9);
    near(durations.lastObject.doubleValue, 0.3); near(lastDelay, 0.1);
    assert((lastOptions & (3 << 16)) == UIViewAnimationOptionCurveEaseIn);
    [UIView animateWithDuration:5 delay:0.2 options:0 animations:^{} completion:nil];
    near(durations.lastObject.doubleValue, 5); near(lastDelay, 0.2);
    [UIView animateWithDuration:0.5 delay:0.2 usingSpringWithDamping:0.4 initialSpringVelocity:1
        options:0 animations:^{} completion:nil];
    near(durations.lastObject.doubleValue, 0.5 / 1.9); near(lastDelay, 0.2 / 1.9);
}

static void testLockAnimations(void) {
    SBFWakeAnimationSettings *wake = [SBFWakeAnimationSettings new];
    CSLockScreenSettings *lock = [CSLockScreenSettings new];
    SBCoverSheetSlidingViewController *sliding = [SBCoverSheetSlidingViewController new];
    wake.contentWakeSettings = lockAnimation();
    wake.awakeWallpaperFilterSettings = lockAnimation();
    wake.sleepWallpaperFilterSettings = lockAnimation();
    lock.unlockWallpaperOutSettings = lockAnimation();
    lock.unlockWallpaperInSettings = lockAnimation();
    lock.unlockToPhoneWallpaperOutSettings = lockAnimation();
    lock.unlockToPhoneWallpaperInSettings = lockAnimation();
    atomic_store(&RTWakeAnimations, true); atomic_store(&RTWakeAcceleration, 5);
    atomic_store(&RTUnlockAnimations, true); atomic_store(&RTUnlockAcceleration, 2);
    for (unsigned mainEnabled = 0; mainEnabled <= 1; mainEnabled++) {
        atomic_store(&RTAnimations, mainEnabled);
        atomic_store(&RTAnimationFactor, 10);
        near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:0 isWake:YES], 1.2 * 5.5);
        near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:20 isWake:YES], 1.2 * 1.4 * 5.5);
        near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:20 isWake:NO], 1.4);
        [[SBScreenWakeAnimationController new] _startWakeAnimationsForWaking:YES animationSettings:nil];
        near(durations.lastObject.doubleValue, 0.5); // caller already applied the wake speed
        for (SBFAnimationSettings *s in @[wake.contentWakeSettings, wake.awakeWallpaperFilterSettings,
                                        wake.sleepWallpaperFilterSettings])
            near([[s BSAnimationSettings] duration], 0.5);
        for (SBFAnimationSettings *s in @[lock.unlockWallpaperOutSettings, lock.unlockWallpaperInSettings,
                                        lock.unlockToPhoneWallpaperOutSettings, lock.unlockToPhoneWallpaperInSettings])
            near([[s BSAnimationSettings] duration], 0.5 / 2.8);
        originalSpring = NO;
        __block unsigned completed = 0;
        [sliding _finishTransitionToPresented:NO animated:YES withCompletion:^(BOOL finished) {
            assert(finished); completed++;
        }];
        CASpringAnimation *spring = [CASpringAnimation animation];
        spring.mass = 1; spring.stiffness = 300; spring.damping = 34; spring.initialVelocity = 0;
        near(durations.lastObject.doubleValue, spring.settlingDuration / 2.8);
        assert(!originalSpring && completed == 1);
    }
    // Changing unlock must not affect wake; zero restores the source speed/settings.
    atomic_store(&RTUnlockAcceleration, 0);
    near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:0 isWake:YES], 1.2 * 5.5);
    near([[lock.unlockWallpaperInSettings BSAnimationSettings] duration], 0.5);
    originalSpring = NO;
    [sliding _finishTransitionToPresented:NO animated:YES withCompletion:nil];
    assert(originalSpring);
    atomic_store(&RTWakeAcceleration, 0);
    near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:20 isWake:YES], 1.2 * 1.4);
    atomic_store(&RTUnlockAcceleration, 10); atomic_store(&RTWakeAcceleration, 10);
    atomic_store(&RTUnlockAnimations, false); atomic_store(&RTWakeAnimations, false);
    near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:20 isWake:YES], 1.2 * 1.4);
    near([[lock.unlockWallpaperInSettings BSAnimationSettings] duration], 0.5);
    originalSpring = NO;
    [sliding _finishTransitionToPresented:NO animated:YES withCompletion:nil];
    assert(originalSpring);
    atomic_store(&RTUnlockAnimations, true);
    originalSpring = NO;
    [sliding _finishTransitionToPresented:YES animated:YES withCompletion:nil];
    assert(originalSpring); // presenting the cover sheet is not unlocking
    lockScreenVisible = NO;
    originalSpring = NO;
    [sliding _finishTransitionToPresented:NO animated:YES withCompletion:nil];
    assert(originalSpring); // dismissing Notification Center is not unlocking
    lockScreenVisible = YES;
    originalSpring = NO;
    [UIView _animateUsingSpringWithTension:300 friction:34 interactive:NO animations:^{} completion:nil];
    assert(originalSpring); // unlocked context must not leak
    raiseDuringUnlock = YES;
    @try { [sliding _finishTransitionToPresented:NO animated:YES withCompletion:nil]; }
    @catch (NSException *exception) { assert([exception.name isEqualToString:@"fixture"]); }
    raiseDuringUnlock = NO;
    [UIView animateWithDuration:0.5 animations:^{}];
    near(durations.lastObject.doubleValue, 0.05);
    atomic_store(&RTWakeAnimations, true);
    for (unsigned i = 0; i <= 100; i++) {
        double level = i / 10.0;
        atomic_store(&RTWakeAcceleration, level);
        atomic_store(&RTUnlockAcceleration, level);
        near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:20 isWake:YES],
             1.2 * 1.4 * (1.0 + 0.9 * level));
        near([[lock.unlockWallpaperInSettings BSAnimationSettings] duration], 0.5 / (1.0 + 0.9 * level));
    }
    for (unsigned reason = 0; reason < 3; reason++) {
        atomic_store(&RTEnabled, reason != 0);
        atomic_store(&RTAnimationExcluded, reason == 1); reducedMotion = reason == 2;
        atomic_store(&RTWakeAnimations, true);
        near([SBScreenWakeAnimationController _animationSpeedForBacklightChangeSource:20 isWake:YES], 1.2 * 1.4);
        near([[lock.unlockWallpaperInSettings BSAnimationSettings] duration], 0.5);
    }
    atomic_store(&RTEnabled, true); atomic_store(&RTAnimations, true);
    atomic_store(&RTAnimationExcluded, false); reducedMotion = NO;
    atomic_store(&RTWakeAnimations, false); atomic_store(&RTUnlockAnimations, false);
    atomic_store(&RTAnimationFactor, 1);
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        useWakeFallback = argc > 1 && strcmp(argv[1], "--wake-fallback") == 0;
        durations = [NSMutableArray array];
        atomic_store(&RTHighRefresh, false);
        atomic_store(&RTAnimationFactor, 1);
        testFixtureClasses();
        RTInstallAnimationHooks(YES);
        testUIKit(); testPropertyAnimator(); testSpringBoard();
        testAccelerationDirection(); testPhaseTiming(); testFolderAnimations(); testLockAnimations();
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
        puts("PASS: Logos fixtures; synchronized delay/duration, native folders, nesting, acceleration, wake/unlock, callbacks, gating");
    }
    return 0;
}

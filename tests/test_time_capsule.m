/* macOS Foundation fixture, not a UIKit/device layout test. This compiles and
 * executes the ACTUAL companion .x, with mock OS image/prefs/clock/scheduling
 * boundaries and lightweight, namespaced UIKit classes. */
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include <assert.h>
#include <stdio.h>
#include <math.h>

static void FixtureOriginal(id self, SEL command, id date, id time, id upload, id download);
static id FixtureGetter(id self, SEL command);
#define RT_TIME_CAPSULE_TESTING 1
#import "../src/TimeCapsuleBattery.x"

NSString *const NSFontAttributeName = @"RTTimeCapsuleFixtureFont";
@implementation UIView
- (instancetype)init {
    if ((self = [super init])) { _alpha = 1; _bounds = CGRectMake(0, 0, 500, 50); }
    return self;
}
@end
@implementation UIWindow
@end
@implementation UIFont
@end
@implementation UILabel
@end
@implementation UIApplication
+ (instancetype)sharedApplication {
    static UIApplication *application;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ application = [self new]; });
    return application;
}
@end
@implementation NSString (RTTimeCapsuleFixtureSizing)
- (CGSize)sizeWithAttributes:(NSDictionary *)attributes {
    assert(NSThread.isMainThread);
    UIFont *font = attributes[NSFontAttributeName];
    return CGSizeMake(self.length * font.characterWidth, font.lineHeight);
}
@end

static Class fixtureClass;
static UILabel *fixtureLabel;
static UIView *fixtureParent;
static UIWindow *fixtureWindow;
static UIView *fixtureBubble;
static id getterResult;
static NSMutableDictionary *preferences;
static NSMutableArray<NSDictionary *> *queued;
static NSString *classImage, *ownImage, *originalImage, *getterImage;
static double uptimeValue;
static unsigned readCalls, originalCalls, getterCalls, queueCalls;
static BOOL providerSuccess, originalWrites, originalThrows, preferencesReadable;
static double providerCelsius;
static id lastSelf, lastDate, lastTime, lastUpload, lastDownload;
static SEL lastCommand;

static SEL UpdateSelector(void) {
    return sel_registerName("updateDateLine:timeLine:uploadLine:downloadLine:");
}
Class RTTimeCapsuleTestLookupClass(void) { assert(NSThread.isMainThread); return fixtureClass; }
NSString *RTTimeCapsuleTestClassImage(Class cls) { (void)cls; return classImage; }
NSString *RTTimeCapsuleTestAddressImage(const void *address) {
    if (address == RTDateInfoIMPAddress((IMP)FixtureOriginal)) return originalImage;
    if (address == RTDateInfoIMPAddress((IMP)FixtureGetter)) return getterImage;
    return ownImage;
}
CFPropertyListRef RTTimeCapsuleTestCopyPreference(CFStringRef key) {
    assert(NSThread.isMainThread);
    id value = preferences[(__bridge NSString *)key];
    return value ? CFBridgingRetain(value) : NULL;
}
BOOL RTTimeCapsuleTestSynchronizePreferences(void) {
    assert(NSThread.isMainThread); return preferencesReadable;
}
double RTTimeCapsuleTestUptime(void) { assert(NSThread.isMainThread); return uptimeValue; }
void RTTimeCapsuleTestEnqueue(double delay, dispatch_block_t block) {
    ++queueCalls;
    [queued addObject:@{@"delay": @(delay), @"block": [block copy]}];
}
BOOL RTReadBatteryTemperatureC(double *outCelsius) {
    assert(NSThread.isMainThread);
    assert(RTDateInfoApplicationActive());
    assert(RTDateInfoViewVisible(fixtureBubble, fixtureWindow, fixtureBubble));
    assert(RTDateInfoViewVisible(fixtureLabel, fixtureWindow, fixtureBubble));
    ++readCalls;
    if (providerSuccess) *outCelsius = providerCelsius;
    return providerSuccess;
}
static void FixtureOriginal(id self, SEL command, id date, id time, id upload, id download) {
    ++originalCalls;
    lastSelf = self; lastCommand = command; lastDate = date; lastTime = time;
    lastUpload = upload; lastDownload = download;
    if (originalThrows) [NSException raise:@"FixtureOriginalException" format:@"preserve me"];
    if (originalWrites) fixtureLabel.text = [time isKindOfClass:NSString.class] ? time : @"12:34";
}
static id FixtureGetter(id self, SEL command) {
    (void)self;
    assert(sel_isEqual(command, sel_registerName("timeLabel")));
    assert(NSThread.isMainThread);
    ++getterCalls;
    return getterResult;
}
static Class NewClass(Class superclass, const char *updateTypes, const char *getterTypes) {
    static unsigned serial;
    NSString *name = [NSString stringWithFormat:@"RTTimeCapsuleFixtureBubble%u", ++serial];
    Class cls = objc_allocateClassPair(superclass, name.UTF8String, 0);
    assert(cls);
    if (updateTypes) assert(class_addMethod(cls, UpdateSelector(), (IMP)FixtureOriginal, updateTypes));
    if (getterTypes) assert(class_addMethod(cls, sel_registerName("timeLabel"), (IMP)FixtureGetter, getterTypes));
    objc_registerClassPair(cls);
    return cls;
}
static void Reset(void) {
    // Restore only our previously installed fixture method. No runtime class disposal.
    if (RTDateInfoTemperatureHookInstalled) {
        Method method = class_getInstanceMethod(RTDateInfoBubbleClass, UpdateSelector());
        assert(method_getImplementation(method) == (IMP)RTDateInfoUpdateWithBatteryTemperature);
        method_setImplementation(method, (IMP)RTOriginalDateInfoUpdate);
    }
    RTOriginalDateInfoUpdate = NULL; RTDateInfoTimeLabel = NULL; RTDateInfoBubbleClass = Nil;
    RTDateInfoTemperatureHookInstalled = NO; RTDateInfoHookRejected = NO;
    RTDateInfoRetryPending = NO; RTDateInfoHookAttempts = 0;
    RTDateInfoSample = (RTTimeCapsuleSample){0};
    classImage = @"/var/jb/Library/MobileSubstrate/DynamicLibraries/DateInfo.dylib";
    ownImage = @"/var/jb/Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib";
    originalImage = classImage; getterImage = classImage;
    queued = [NSMutableArray new]; preferences = [NSMutableDictionary new];
    readCalls = originalCalls = getterCalls = queueCalls = 0;
    lastSelf = lastDate = lastTime = lastUpload = lastDownload = nil; lastCommand = NULL;
    providerSuccess = YES; providerCelsius = 32.5; uptimeValue = 100;
    originalWrites = NO; originalThrows = NO; preferencesReadable = YES;
    UIApplication.sharedApplication.applicationState = UIApplicationStateActive;
    fixtureClass = Nil; fixtureBubble = nil; fixtureLabel = nil; getterResult = nil;
    fixtureParent = nil; fixtureWindow = nil;
}
static void CreateVisible(void) {
    fixtureClass = NewClass(UIView.class, "v48@0:8@16@24@32@40", "@16@0:8");
    fixtureWindow = [UIWindow new]; fixtureWindow.window = fixtureWindow;
    fixtureParent = [UIView new]; fixtureParent.window = fixtureWindow; fixtureParent.superview = fixtureWindow;
    fixtureBubble = [fixtureClass new]; fixtureBubble.window = fixtureWindow; fixtureBubble.superview = fixtureParent;
    fixtureLabel = [UILabel new]; fixtureLabel.window = fixtureWindow; fixtureLabel.superview = fixtureBubble;
    fixtureLabel.font = [UIFont new]; fixtureLabel.font.characterWidth = 8; fixtureLabel.font.lineHeight = 16;
    fixtureLabel.numberOfLines = 1; fixtureLabel.text = @"12:34";
    fixtureLabel.minimumScaleFactor = 0.93; fixtureLabel.adjustsFontSizeToFitWidth = NO;
    getterResult = fixtureLabel;
    RTTryInstallDateInfoTemperatureHook();
    assert(RTDateInfoTemperatureHookInstalled);
    assert((IMP)RTOriginalDateInfoUpdate == (IMP)FixtureOriginal);
}
static void Update(id date, id time, id upload, id download) {
    unsigned before = originalCalls;
    ((RTDateInfoUpdateIMP)objc_msgSend)(fixtureBubble, UpdateSelector(), date, time, upload, download);
    assert(originalCalls == before + 1);
    assert(lastSelf == fixtureBubble && sel_isEqual(lastCommand, UpdateSelector()));
    assert(lastDate == date && lastTime == time && lastUpload == upload && lastDownload == download);
}
static void Tick(void) { Update(@"date", @"12:34", @"up", @"down"); }
static void DrainOne(void) {
    assert(queued.count);
    NSDictionary *item = queued.firstObject;
    [queued removeObjectAtIndex:0];
    uptimeValue += [item[@"delay"] doubleValue];
    dispatch_block_t block = item[@"block"];
    block();
}
static void Enable(void) { preferences[@"TimeCapsuleBatteryTemp"] = @YES; }
static void AssertBase(void) { assert([fixtureLabel.text isEqualToString:@"12:34"]); }
static void AssertTemperature(NSString *suffix) { assert([fixtureLabel.text hasSuffix:suffix]); }

static void RunOffMain(dispatch_block_t block) {
    // dispatch_sync may execute inline on the calling main thread. Use an
    // asynchronous worker plus a semaphore so these really test off-main calls.
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool {
            assert(!NSThread.isMainThread);
            block();
            dispatch_semaphore_signal(done);
        }
    });
    assert(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0);
}
static void TestInstallation(void) {
    Reset();
    RTTryInstallDateInfoTemperatureHook();
    assert(queued.count == 1 && RTDateInfoHookAttempts == 1);
    for (unsigned i = 0; i < 100; ++i) RTTryInstallDateInfoTemperatureHook();
    assert(queued.count == 1 && RTDateInfoHookAttempts == 1);
    while (queued.count) DrainOne();
    assert(RTDateInfoHookAttempts == RTDateInfoMaximumAttempts);
    assert(queueCalls == RTDateInfoMaximumAttempts - 1);
    RTTryInstallDateInfoTemperatureHook();
    assert(!queued.count && !RTDateInfoTemperatureHookInstalled);

    Reset();
    RunOffMain(^{ RTTryInstallDateInfoTemperatureHook(); });
    assert(RTDateInfoHookAttempts == 0 && queued.count == 1);
    fixtureClass = NewClass(UIView.class, "v@:@@@@", "@@:");
    DrainOne();
    assert(RTDateInfoTemperatureHookInstalled && !queued.count);
    unsigned attempts = RTDateInfoHookAttempts;
    for (unsigned i = 0; i < 10; ++i) RTTryInstallDateInfoTemperatureHook();
    assert(RTDateInfoHookAttempts == attempts);

    // A bounded delayed load can succeed; no polling remains after installation.
    Reset(); RTTryInstallDateInfoTemperatureHook();
    fixtureClass = NewClass(UIView.class, "v@:@@@@", "@@:");
    DrainOne();
    assert(RTDateInfoTemperatureHookInstalled && !queued.count);
}
static void AssertRejected(Class cls) {
    fixtureClass = cls;
    IMP before = class_getMethodImplementation(cls, UpdateSelector());
    RTTryInstallDateInfoTemperatureHook();
    assert(!RTDateInfoTemperatureHookInstalled && RTDateInfoHookRejected && !queued.count);
    assert(class_getMethodImplementation(cls, UpdateSelector()) == before);
    RTTryInstallDateInfoTemperatureHook();
    assert(RTDateInfoHookAttempts == 1);
}
static void TestABIAndOrigin(void) {
    const char *badUpdates[] = {NULL, "@@:@@@@", "v@:@@@", "v@:@@@@@", "v@:@q@@", "v@:@@^v@", "v@:@?@@@"};
    for (unsigned i = 0; i < sizeof(badUpdates) / sizeof(badUpdates[0]); ++i) {
        Reset(); AssertRejected(NewClass(UIView.class, badUpdates[i], "@@:"));
    }
    const char *badGetters[] = {NULL, "v@:", "q@:", "@@:@", "@#:", "@?@:"};
    for (unsigned i = 0; i < sizeof(badGetters) / sizeof(badGetters[0]); ++i) {
        Reset(); AssertRejected(NewClass(UIView.class, "v@:@@@@", badGetters[i]));
    }
    Reset(); AssertRejected(NewClass(NSObject.class, "v@:@@@@", "@@:"));
    Reset(); Class parent = NewClass(UIView.class, "v@:@@@@", "@@:");
    AssertRejected(NewClass(parent, NULL, NULL)); // Do not mutate an inherited method.
    Reset(); classImage = @"/tmp/DateInfo.dylib";
    AssertRejected(NewClass(UIView.class, "v@:@@@@", "@@:"));
    Reset(); classImage = nil;
    AssertRejected(NewClass(UIView.class, "v@:@@@@", "@@:"));
    Reset(); ownImage = @"/var/other/Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib";
    AssertRejected(NewClass(UIView.class, "v@:@@@@", "@@:"));
    Reset(); originalImage = @"/tmp/UnknownHook.dylib";
    AssertRejected(NewClass(UIView.class, "v@:@@@@", "@@:"));
    Reset(); getterImage = nil;
    AssertRejected(NewClass(UIView.class, "v@:@@@@", "@@:"));
}
static void TestForwardingAndPreferences(void) {
    Reset(); CreateVisible();
    id date = [NSObject new], upload = [NSObject new], download = [NSObject new];
    Update(date, nil, upload, download); // Preserve identities and nil, not rewritten timeLine.
    AssertBase(); assert(readCalls == 0); // Missing battery preference MUST be OFF.
    NSArray *malformed = @[@"YES", @"1", @2, @(-1), @0.5, @(NAN), @[], @{}];
    for (id bad in malformed) {
        preferences[@"TimeCapsuleBatteryTemp"] = bad;
        Tick(); AssertBase(); assert(readCalls == 0);
    }
    preferences[@"TimeCapsuleBatteryTemp"] = @NO;
    Tick(); AssertBase(); assert(readCalls == 0);
    preferences[@"TimeCapsuleBatteryTemp"] = @1;
    Tick(); AssertTemperature(@"电池 32.5°C"); assert(readCalls == 1);
    // A repeated original which leaves text unchanged must not accumulate suffixes.
    NSString *rendered = [fixtureLabel.text copy];
    for (unsigned i = 0; i < 10; ++i) { Tick(); assert([fixtureLabel.text isEqualToString:rendered]); }
    assert(readCalls == 1);
    preferencesReadable = NO;
    Tick(); AssertBase(); assert(readCalls == 1); // Unreadable preferences fail closed and clean our prior text.
    preferencesReadable = YES;
    Tick(); AssertTemperature(@"电池 32.5°C"); assert(readCalls == 1);
    preferences[@"TimeCapsuleBatteryTemp"] = @"broken";
    Tick(); AssertBase(); assert(readCalls == 1);
    Enable(); preferences[@"Enabled"] = @NO;
    Tick(); AssertBase();
    preferences[@"Enabled"] = @"YES";
    Tick(); AssertBase();
    [preferences removeObjectForKey:@"Enabled"];
    Tick(); AssertTemperature(@"电池 32.5°C"); // Enabled's existing default is YES.
    [preferences removeObjectForKey:@"TimeCapsuleBatteryTemp"];
    Tick(); AssertBase(); // Removing explicit opt-in cleans up our own text.
    Enable(); originalWrites = YES;
    Update(date, @"23:59", upload, download);
    assert([fixtureLabel.text hasPrefix:@"23:59  电池 "]);
    originalWrites = NO;
    fixtureLabel.text = @"another tweak owns this";
    preferences[@"TimeCapsuleBatteryTemp"] = @NO;
    Tick(); assert([fixtureLabel.text isEqualToString:@"another tweak owns this"]);
    unsigned reads = readCalls, getters = getterCalls;
    originalThrows = YES;
    @try { Tick(); assert(false); }
    @catch (NSException *exception) { assert([exception.name isEqualToString:@"FixtureOriginalException"]); }
    assert(readCalls == reads && getterCalls == getters);
}

static void AssertNoCompanionWork(void) {
    NSString *text = [fixtureLabel.text copy];
    unsigned reads = readCalls, getters = getterCalls;
    Tick();
    assert(readCalls == reads && getterCalls == getters && [fixtureLabel.text isEqualToString:text]);
    assert(!queued.count);
}
static void TestVisibilityAndMainThread(void) {
    Reset(); CreateVisible(); Enable();
    fixtureBubble.hidden = YES; AssertNoCompanionWork(); fixtureBubble.hidden = NO;
    fixtureParent.hidden = YES; AssertNoCompanionWork(); fixtureParent.hidden = NO;
    fixtureWindow.hidden = YES; AssertNoCompanionWork(); fixtureWindow.hidden = NO;
    fixtureParent.alpha = 0; AssertNoCompanionWork(); fixtureParent.alpha = 1;
    fixtureBubble.alpha = NAN; AssertNoCompanionWork(); fixtureBubble.alpha = 1;
    fixtureParent.alpha = .05; fixtureBubble.alpha = .05; AssertNoCompanionWork();
    fixtureParent.alpha = fixtureBubble.alpha = 1;
    fixtureBubble.window = nil; AssertNoCompanionWork(); fixtureBubble.window = fixtureWindow;
    UIApplication.sharedApplication.applicationState = UIApplicationStateInactive; AssertNoCompanionWork();
    UIApplication.sharedApplication.applicationState = UIApplicationStateBackground; AssertNoCompanionWork();
    UIApplication.sharedApplication.applicationState = UIApplicationStateActive;
    RunOffMain(^{ AssertNoCompanionWork(); });
    assert(originalCalls == 10); // Every gated update still invoked its donor once.
    fixtureBubble.bounds = CGRectZero; AssertNoCompanionWork();
    fixtureBubble.bounds = CGRectMake(0, 0, 500, 50);
    fixtureWindow.bounds = CGRectZero; AssertNoCompanionWork();
    fixtureWindow.bounds = CGRectMake(0, 0, 500, 50);
    fixtureLabel.hidden = YES; Tick(); AssertBase(); assert(readCalls == 0); fixtureLabel.hidden = NO;
    fixtureLabel.superview = fixtureParent; Tick(); AssertBase(); assert(readCalls == 0);
    fixtureLabel.superview = fixtureBubble;
    Tick(); AssertTemperature(@"电池 32.5°C");
    fixtureParent.hidden = YES; preferences[@"TimeCapsuleBatteryTemp"] = @NO;
    AssertNoCompanionWork(); // Cleanup waits for visibility; do not mutate hidden UI.
    uptimeValue += 100; assert(readCalls == 1 && !queued.count);
    fixtureParent.hidden = NO; Tick(); AssertBase(); assert(readCalls == 1);
}

static void TestFitAndOwnership(void) {
    Reset(); CreateVisible(); Enable();
    CGRect frame = fixtureLabel.frame;
    UIFont *font = fixtureLabel.font;
    fixtureLabel.bounds = CGRectMake(0, 0, 30, 50);
    Tick(); AssertBase(); assert(readCalls == 0);
    fixtureLabel.bounds = CGRectMake(0, 0, 500, 10);
    Tick(); AssertBase(); assert(readCalls == 0);
    fixtureLabel.bounds = CGRectMake(0, 0, 500, 50);
    fixtureLabel.numberOfLines = 2;
    Tick(); AssertBase(); assert(readCalls == 0);
    fixtureLabel.numberOfLines = 1;
    fixtureLabel.attributedText = [[NSAttributedString alloc] initWithString:@"12:34"];
    Tick(); AssertBase(); assert(readCalls == 0);
    fixtureLabel.attributedText = nil;
    fixtureLabel.font = nil;
    Tick(); AssertBase(); assert(readCalls == 0); fixtureLabel.font = font;
    fixtureLabel.text = @"12:34\nsecond line";
    Tick(); assert(readCalls == 0); fixtureLabel.text = @"12:34";
    Tick(); AssertTemperature(@"电池 32.5°C"); assert(readCalls == 1);
    fixtureLabel.bounds = CGRectMake(0, 0, 30, 50);
    Tick(); AssertBase(); assert(readCalls == 1); // Undo just our mutation on no-fit.
    assert(fixtureLabel.font == font && CGRectEqualToRect(fixtureLabel.frame, frame));
    assert(!fixtureLabel.adjustsFontSizeToFitWidth && fixtureLabel.minimumScaleFactor == .93);

    fixtureLabel.bounds = CGRectMake(0, 0, 500, 50);
    Tick(); AssertTemperature(@"电池 32.5°C"); assert(readCalls == 1);
    getterResult = nil; Tick(); AssertBase(); assert(readCalls == 1); // Lost getter result still undoes only our visible text.
    getterResult = [NSObject new]; Tick(); AssertBase(); assert(readCalls == 1);
    getterResult = fixtureLabel;
    // Getter replaced AFTER validation: never invoke an unverified IMP.
    Method getter = class_getInstanceMethod(fixtureClass, sel_registerName("timeLabel"));
    IMP old = method_setImplementation(getter, imp_implementationWithBlock(^id(id object) {
        (void)object; assert(false); return nil;
    }));
    Tick(); AssertBase(); assert(readCalls == 1);
    IMP block = method_setImplementation(getter, old); imp_removeBlock(block);

    // The unavailable marker can fit while a wider actual value cannot.
    uptimeValue += 2; providerCelsius = 125;
    NSString *marker = @"12:34  电池 --°C";
    fixtureLabel.bounds = CGRectMake(0, 0, marker.length * font.characterWidth + 1, 50);
    Tick(); AssertBase(); assert(readCalls == 2);
    fixtureLabel.bounds = CGRectMake(0, 0, 500, 50);
    Tick(); AssertTemperature(@"电池 125.0°C"); assert(readCalls == 2);
    // Externally replaced attributed content is not ours to erase.
    fixtureLabel.attributedText = [[NSAttributedString alloc] initWithString:fixtureLabel.text];
    preferences[@"TimeCapsuleBatteryTemp"] = @NO;
    NSString *before = [fixtureLabel.text copy];
    Tick(); assert([fixtureLabel.text isEqualToString:before] && fixtureLabel.attributedText != nil);
}
static void TestCachingAndFailure(void) {
    Reset(); CreateVisible(); Enable();
    Tick(); AssertTemperature(@"电池 32.5°C"); assert(readCalls == 1);
    uptimeValue = 100.999; providerCelsius = 40;
    Tick(); AssertTemperature(@"电池 32.5°C"); assert(readCalls == 1);
    uptimeValue = 101;
    Tick(); AssertTemperature(@"电池 40.0°C"); assert(readCalls == 2);
    uptimeValue = 102; providerSuccess = NO;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 3);
    uptimeValue = 102.5; providerSuccess = YES; providerCelsius = 39;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 3); // Cache failed attempt, not old value.
    uptimeValue = 103;
    Tick(); AssertTemperature(@"电池 39.0°C"); assert(readCalls == 4);
    uptimeValue = 104; providerCelsius = NAN;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 5);
    uptimeValue = 105; providerCelsius = 126;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 6);
    uptimeValue = 99; providerCelsius = 37;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 6); // No clock-regression burst.
    uptimeValue = NAN;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 6);
    uptimeValue = 106;
    Tick(); AssertTemperature(@"电池 37.0°C"); assert(readCalls == 7);
    fixtureWindow.hidden = YES;
    for (unsigned i = 0; i < 10; ++i) { uptimeValue += 10; AssertNoCompanionWork(); }
    assert(readCalls == 7 && queued.count == 0 && queueCalls == 0);
    fixtureWindow.hidden = NO; providerSuccess = NO;
    Tick(); AssertTemperature(@"电池 --°C"); assert(readCalls == 8); // Resume must refresh stale cache.
}
int main(void) {
    @autoreleasepool {
        assert(NSThread.isMainThread);
        TestInstallation();
        TestABIAndOrigin();
        TestForwardingAndPreferences();
        TestVisibilityAndMainThread();
        TestFitAndOwnership();
        TestCachingAndFailure();
        Reset();
        puts("PASS: actual TimeCapsuleBattery.x runtime ABI/origin gates, original forwarding, fail-closed opt-in, main/visibility, fit/ownership, caching/failures and bounded load order");
    }
    return 0;
}

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdatomic.h>
#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#endif
#import "RTBatteryTemperature.h"
#import "RTTimeCapsulePolicy.h"

/* Optional, separately installed DateInfo 1.3.10. Never load/copy its image.
 * All state below is main-queue confined except the immutable saved IMPs used
 * to forward an update arriving on another thread. No global UIKit hooks. */
typedef void (*RTDateInfoUpdateIMP)(id, SEL, id, id, id, id);
typedef id (*RTDateInfoLabelIMP)(id, SEL);
static _Atomic(RTDateInfoUpdateIMP) RTOriginalDateInfoUpdate;
static RTDateInfoLabelIMP RTDateInfoTimeLabel;
static Class RTDateInfoBubbleClass;
static BOOL RTDateInfoTemperatureHookInstalled;
static BOOL RTDateInfoHookRejected;
static BOOL RTDateInfoRetryPending;
static unsigned RTDateInfoHookAttempts;
static const unsigned RTDateInfoMaximumAttempts = 20;
static RTTimeCapsuleSample RTDateInfoSample;
static char RTDateInfoBaseKey, RTDateInfoWrittenKey, RTDateInfoLastLabelKey;
@interface RTTimeCapsuleLabelReference : NSObject
@property(nonatomic, weak) UILabel *label;
@end
@implementation RTTimeCapsuleLabelReference
@end
static void RTTryInstallDateInfoTemperatureHook(void);

#if defined(RT_TIME_CAPSULE_TESTING)
/* Test substitutes only OS boundaries, not ABI/visibility/fit/cache/hook logic.
 * The fixture includes this actual .x translation unit without Logos. */
extern Class RTTimeCapsuleTestLookupClass(void);
extern NSString *RTTimeCapsuleTestClassImage(Class cls);
extern NSString *RTTimeCapsuleTestAddressImage(const void *address);
extern CFPropertyListRef RTTimeCapsuleTestCopyPreference(CFStringRef key);
extern BOOL RTTimeCapsuleTestSynchronizePreferences(void);
extern double RTTimeCapsuleTestUptime(void);
extern void RTTimeCapsuleTestEnqueue(double delay, dispatch_block_t block);
#else
static NSString *RTDateInfoCanonicalPath(const char *path) {
    if (!path) return nil;
    char *canonical = realpath(path, NULL);
    if (!canonical) return nil;
    NSString *result = [NSString stringWithUTF8String:canonical];
    free(canonical);
    return result;
}
#endif

static NSString *RTDateInfoClassImage(Class cls) {
#if defined(RT_TIME_CAPSULE_TESTING)
    return RTTimeCapsuleTestClassImage(cls);
#else
    return RTDateInfoCanonicalPath(class_getImageName(cls));
#endif
}
static NSString *RTDateInfoAddressImage(const void *address) {
#if defined(RT_TIME_CAPSULE_TESTING)
    return RTTimeCapsuleTestAddressImage(address);
#else
    Dl_info info = {0};
    return dladdr(address, &info) ? RTDateInfoCanonicalPath(info.dli_fname) : nil;
#endif
}
static const void *RTDateInfoIMPAddress(IMP implementation) {
#if __has_feature(ptrauth_calls)
    return ptrauth_strip(implementation, ptrauth_key_function_pointer);
#else
    return (const void *)implementation;
#endif
}
static void RTDateInfoEnqueue(double delay, dispatch_block_t block) {
#if defined(RT_TIME_CAPSULE_TESTING)
    RTTimeCapsuleTestEnqueue(delay, block);
#else
    if (delay == 0.0) dispatch_async(dispatch_get_main_queue(), block);
    else dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), block);
#endif
}

static BOOL RTDateInfoPreference(CFStringRef key, BOOL missingDefault) {
#if defined(RT_TIME_CAPSULE_TESTING)
    CFPropertyListRef value = RTTimeCapsuleTestCopyPreference(key);
#else
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, CFSTR("com.12233sjjs.relaxtune"));
#endif
    if (!value) return missingDefault;
    BOOL result = NO; // Malformed values fail closed, including numeric 2/NaN.
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        result = CFBooleanGetValue((CFBooleanRef)value);
    } else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        double number = 0.0;
        result = CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &number) &&
                 isfinite(number) && number == 1.0;
    }
    CFRelease(value);
    return result;
}
static BOOL RTCapsuleTemperatureEnabled(void) {
#if defined(RT_TIME_CAPSULE_TESTING)
    if (!RTTimeCapsuleTestSynchronizePreferences()) return NO;
#else
    if (!CFPreferencesAppSynchronize(CFSTR("com.12233sjjs.relaxtune"))) return NO;
#endif
    // Same domain/key/default as Settings.m, but stricter malformed-value policy.
    // This gates only our companion, never DateInfo's independent functionality.
    return RTDateInfoPreference(CFSTR("Enabled"), YES) &&
           RTDateInfoPreference(CFSTR("TimeCapsuleBatteryTemp"), NO);
}

static BOOL RTDateInfoApplicationActive(void) {
    UIApplication *application = UIApplication.sharedApplication;
    return application && (![application respondsToSelector:@selector(applicationState)] ||
                           application.applicationState == UIApplicationStateActive);
}
static BOOL RTDateInfoViewVisible(UIView *view, UIWindow *window, UIView *requiredAncestor) {
    if (!view || !window || view.window != window) return NO;
    CGSize size = view.bounds.size, windowSize = window.bounds.size;
    if (!isfinite(size.width) || !isfinite(size.height) || size.width <= 0 || size.height <= 0 ||
        !isfinite(windowSize.width) || !isfinite(windowSize.height) ||
        windowSize.width <= 0 || windowSize.height <= 0) return NO;
    BOOL foundAncestor = requiredAncestor == nil;
    double effectiveAlpha = 1.0;
    // Bound traversal even for a broken/mock hierarchy; never infer free footer space.
    for (unsigned depth = 0; view && depth < 128; ++depth, view = view.superview) {
        if (view.hidden || !isfinite(view.alpha)) return NO;
        effectiveAlpha *= view.alpha;
        if (effectiveAlpha <= 0.01) return NO;
        if (view == requiredAncestor) foundAncestor = YES;
        if (view == window) return foundAncestor;
    }
    return NO;
}

static void RTDateInfoUndoOwnText(UILabel *label) {
    NSString *written = objc_getAssociatedObject(label, &RTDateInfoWrittenKey);
    NSString *base = objc_getAssociatedObject(label, &RTDateInfoBaseKey);
    // Equality is ownership evidence; never strip suffixes by pattern. A donor
    // or another tweak's new text/attributed formatting must remain untouched.
    if (written && base && !label.attributedText.length && [label.text isEqualToString:written])
        label.text = base;
    objc_setAssociatedObject(label, &RTDateInfoBaseKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(label, &RTDateInfoWrittenKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
static BOOL RTDateInfoTextFits(NSString *text, UILabel *label) {
    CGSize bounds = label.bounds.size;
    if (!label.font || label.numberOfLines != 1 || label.attributedText.length ||
        !isfinite(bounds.width) || !isfinite(bounds.height) || bounds.width <= 0 || bounds.height <= 0 ||
        [text rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound)
        return NO;
    CGSize measured = [text sizeWithAttributes:@{NSFontAttributeName: label.font}];
    // Measure unshrunk text with the ORIGINAL font, with a small rounding margin.
    // No font/frame/bounds/mask/line-break/accessibility mutations, no footer.
    return isfinite(measured.width) && isfinite(measured.height) &&
           measured.width > 0 && measured.height > 0 &&
           ceil(measured.width) + 1.0 <= floor(bounds.width) &&
           ceil(measured.height) + 1.0 <= floor(bounds.height);
}

static NSString *RTDateInfoTemperatureText(void) {
#if defined(RT_TIME_CAPSULE_TESTING)
    double now = RTTimeCapsuleTestUptime();
#else
    double now = NSProcessInfo.processInfo.systemUptime;
#endif
    if (RTTimeCapsuleMaySample(&RTDateInfoSample, now)) {
        double celsius = 0.0;
        BOOL valid = RTReadBatteryTemperatureC(&celsius) && isfinite(celsius) &&
                     celsius >= -40.0 && celsius <= 125.0;
        RTDateInfoSample = (RTTimeCapsuleSample){true, valid, now, valid ? celsius : 0.0};
    }
    return RTTimeCapsuleSampleFresh(&RTDateInfoSample, now)
        ? [NSString stringWithFormat:@"电池 %.1f°C", RTDateInfoSample.celsius] : @"电池 --°C";
}

static void RTDateInfoUpdateWithBatteryTemperature(id self, SEL command,
    id dateLine, id timeLine, id uploadLine, id downloadLine) {
    // Published before installing this IMP; preserve all six arguments and do
    // not catch/alter exceptions or move the donor invocation to another queue.
    RTDateInfoUpdateIMP original = RTOriginalDateInfoUpdate;
    if (!original) return; // Unreachable for a successfully installed hook.
    original(self, command, dateLine, timeLine, uploadLine, downloadLine);
    if (![NSThread isMainThread]) return;
    if (object_getClass(self) != RTDateInfoBubbleClass || !RTDateInfoApplicationActive()) return;
    UIView *bubble = (UIView *)self;
    UIWindow *window = bubble.window;
    if (!RTDateInfoViewVisible(bubble, window, bubble)) return;
    RTTimeCapsuleLabelReference *previous = objc_getAssociatedObject(bubble, &RTDateInfoLastLabelKey);
    UILabel *previousLabel = previous.label;
    if (previousLabel && RTDateInfoViewVisible(previousLabel, window, bubble))
        RTDateInfoUndoOwnText(previousLabel);
    SEL labelSelector = sel_registerName("timeLabel");
    Method getter = class_getInstanceMethod(RTDateInfoBubbleClass, labelSelector);
    if (!getter || method_getImplementation(getter) != (IMP)RTDateInfoTimeLabel) return;
    id labelObject = RTDateInfoTimeLabel(self, labelSelector);
    // Subclasses can override drawing/insets; their usable text rect is unknown.
    if (![labelObject isMemberOfClass:UILabel.class]) return;
    UILabel *label = labelObject;
    if (!RTDateInfoViewVisible(label, window, bubble)) return;
    RTDateInfoUndoOwnText(label);
    if (!RTCapsuleTemperatureEnabled()) return;
    NSString *base = [label.text copy];
    if (![base isKindOfClass:NSString.class] || !base.length) return;
    NSString *unavailable = [base stringByAppendingString:@"  电池 --°C"];
    // If even the unavailable marker cannot fit, do no sensor IO at all.
    if (!RTDateInfoTextFits(unavailable, label)) return;
    NSString *candidate = [NSString stringWithFormat:@"%@  %@", base, RTDateInfoTemperatureText()];
    if (!RTDateInfoTextFits(candidate, label)) return;
    objc_setAssociatedObject(label, &RTDateInfoBaseKey, base, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(label, &RTDateInfoWrittenKey, candidate, OBJC_ASSOCIATION_COPY_NONATOMIC);
    RTTimeCapsuleLabelReference *reference = [RTTimeCapsuleLabelReference new];
    reference.label = label;
    objc_setAssociatedObject(bubble, &RTDateInfoLastLabelKey, reference, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    label.text = candidate;
}

static Method RTDateInfoOwnedMethod(Class cls, SEL selector) {
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method result = NULL;
    for (unsigned i = 0; i < count; ++i) {
        if (sel_isEqual(method_getName(methods[i]), selector)) { result = methods[i]; break; }
    }
    free(methods);
    return result;
}
static BOOL RTDateInfoTypeEquals(char *ownedType, const char *expected) {
    BOOL equal = ownedType && strcmp(ownedType, expected) == 0;
    free(ownedType);
    return equal;
}
static BOOL RTDateInfoMethodABI(Method method, BOOL update) {
    unsigned count = update ? 6 : 2; // self, _cmd, four object arguments.
    if (!method || method_getNumberOfArguments(method) != count ||
        !RTDateInfoTypeEquals(method_copyReturnType(method), update ? "v" : "@")) return NO;
    for (unsigned i = 0; i < count; ++i) {
        if (!RTDateInfoTypeEquals(method_copyArgumentType(method, i), i == 1 ? ":" : "@")) return NO;
    }
    return YES;
}
static BOOL RTDateInfoUIViewClass(Class cls) {
    if (!cls || cls == UIView.class || class_isMetaClass(cls)) return NO;
    for (Class current = class_getSuperclass(cls); current; current = class_getSuperclass(current))
        if (current == UIView.class) return YES;
    return NO;
}
static void RTTryInstallDateInfoTemperatureHook(void) {
    if (![NSThread isMainThread]) {
        RTDateInfoEnqueue(0.0, ^{ RTTryInstallDateInfoTemperatureHook(); });
        return;
    }
    if (RTDateInfoTemperatureHookInstalled || RTDateInfoHookRejected || RTDateInfoRetryPending ||
        RTDateInfoHookAttempts >= RTDateInfoMaximumAttempts) return;
    ++RTDateInfoHookAttempts;
#if defined(RT_TIME_CAPSULE_TESTING)
    Class bubbleClass = RTTimeCapsuleTestLookupClass();
#else
    Class bubbleClass = objc_getClass("DIBubbleView");
#endif
    if (!bubbleClass) {
        if (RTDateInfoHookAttempts < RTDateInfoMaximumAttempts) {
            RTDateInfoRetryPending = YES;
            RTDateInfoEnqueue(0.25, ^{
                RTDateInfoRetryPending = NO;
                RTTryInstallDateInfoTemperatureHook();
            });
        }
        return; // Finite launch-only retry window: 20 attempts / 4.75 s.
    }
    // A class present with an unexpected identity/API is a permanent no-op.
    RTDateInfoHookRejected = YES;
    if (!RTDateInfoUIViewClass(bubbleClass)) return;
    NSString *image = RTDateInfoClassImage(bubbleClass);
    NSString *companion = RTDateInfoAddressImage((const void *)&RTTryInstallDateInfoTemperatureHook);
    if (!image || !companion || !RTTimeCapsuleExpectedImage(image.UTF8String, companion.UTF8String)) return;
    SEL selector = sel_registerName("updateDateLine:timeLine:uploadLine:downloadLine:");
    Method update = RTDateInfoOwnedMethod(bubbleClass, selector);
    Method getter = RTDateInfoOwnedMethod(bubbleClass, sel_registerName("timeLabel"));
    if (!RTDateInfoMethodABI(update, YES) || !RTDateInfoMethodABI(getter, NO)) return;
    IMP original = method_getImplementation(update);
    IMP labelGetter = method_getImplementation(getter);
    if (!original || !labelGetter || original == (IMP)RTDateInfoUpdateWithBatteryTemperature ||
        ![RTDateInfoAddressImage(RTDateInfoIMPAddress(original)) isEqualToString:image] ||
        ![RTDateInfoAddressImage(RTDateInfoIMPAddress(labelGetter)) isEqualToString:image]) return;
    // Direct runtime replacement: unlike a substrate trampoline, the saved IMP
    // has a verifiable image origin. Do not chain to unknown pre-existing hooks.
    RTOriginalDateInfoUpdate = (RTDateInfoUpdateIMP)original;
    RTDateInfoTimeLabel = (RTDateInfoLabelIMP)labelGetter;
    RTDateInfoBubbleClass = bubbleClass;
    if (method_getImplementation(getter) != labelGetter || method_getImplementation(update) != original)
        return;
    IMP displaced = method_setImplementation(update, (IMP)RTDateInfoUpdateWithBatteryTemperature);
    if (displaced != original) {
        // Unexpected concurrent swizzle: remove ours only if it is still current.
        if (method_getImplementation(update) == (IMP)RTDateInfoUpdateWithBatteryTemperature)
            method_setImplementation(update, displaced);
        return;
    }
    RTDateInfoTemperatureHookInstalled = YES;
    RTDateInfoHookRejected = NO;
}

#if !defined(RT_TIME_CAPSULE_TESTING)
__attribute__((constructor)) static void RTDateInfoTemperatureStart(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        // The first installation attempt, including all runtime validation, is on main.
        if ([NSThread isMainThread]) RTTryInstallDateInfoTemperatureHook();
        else RTDateInfoEnqueue(0.0, ^{ RTTryInstallDateInfoTemperatureHook(); });
    }
}
#endif

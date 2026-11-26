// Test-only namespace: force-include for BOTH the Logos output and fixtures.
// Import real SDK declarations before aliases; never alter Foundation/QuartzCore.
#ifndef RT_ANIMATION_FIXTURE_NAMESPACE_H
#define RT_ANIMATION_FIXTURE_NAMESPACE_H
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <string.h>

#define RT_ANIMATION_FIXTURE_CLASSES(X) \
    X(UIScreen) \
    X(UICubicTimingParameters) \
    X(UIView) \
    X(UIViewPropertyAnimator) \
    X(BSAnimationSettings) \
    X(SBFAnimationSettings) \
    X(SBHIconAnimationSettings) \
    X(SBHScaleZoomSettings) \
    X(SBHFolderZoomSettings) \
    X(SBHFolderOpenSettings) \
    X(SBHFolderCloseSettings) \
    X(SBFolderIconZoomAnimator) \
    X(_SBInnerFolderIconZoomAnimator) \
    X(SBFWakeAnimationSettings) \
    X(SBScreenWakeAnimationController) \
    X(SBLockScreenManager) \
    X(CSLockScreenSettings) \
    X(SBCoverSheetSlidingViewController)

static inline const char *RTAnimationFixtureClassName(const char *name) {
    if (!name) return name;
#define RT_MAP_FIXTURE_CLASS(cls) \
    if (strcmp(name, #cls) == 0) return "RTAnimationFixture_" #cls;
    RT_ANIMATION_FIXTURE_CLASSES(RT_MAP_FIXTURE_CLASS)
#undef RT_MAP_FIXTURE_CLASS
    return name;
}

// These wrappers precede the macros so their calls reach the real runtime.
// Exact class-name mapping only: selectors, KVC keys and SDK classes stay intact.
static inline Class RTAnimationFixtureNSClassFromString(NSString *name) {
    const char *original = name.UTF8String;
    const char *mapped = RTAnimationFixtureClassName(original);
    return NSClassFromString(mapped == original ? name : [NSString stringWithUTF8String:mapped]);
}
static inline Class RTAnimationFixtureObjCGetClass(const char *name) {
    return objc_getClass(RTAnimationFixtureClassName(name));
}
#define NSClassFromString RTAnimationFixtureNSClassFromString
#define objc_getClass RTAnimationFixtureObjCGetClass

// Type names and @implementation names must match the redirected runtime names.
// DO NOT alias BSAnimationSettings: it is also the production export selector.
// Its fixture class is explicitly prefixed in test_animation_hooks.m instead.
#define UIScreen RTAnimationFixture_UIScreen
#define UICubicTimingParameters RTAnimationFixture_UICubicTimingParameters
#define UIView RTAnimationFixture_UIView
#define UIViewPropertyAnimator RTAnimationFixture_UIViewPropertyAnimator
#define SBFAnimationSettings RTAnimationFixture_SBFAnimationSettings
#define SBHIconAnimationSettings RTAnimationFixture_SBHIconAnimationSettings
#define SBHScaleZoomSettings RTAnimationFixture_SBHScaleZoomSettings
#define SBHFolderZoomSettings RTAnimationFixture_SBHFolderZoomSettings
#define SBHFolderOpenSettings RTAnimationFixture_SBHFolderOpenSettings
#define SBHFolderCloseSettings RTAnimationFixture_SBHFolderCloseSettings
#define SBFolderIconZoomAnimator RTAnimationFixture_SBFolderIconZoomAnimator
#define _SBInnerFolderIconZoomAnimator RTAnimationFixture__SBInnerFolderIconZoomAnimator
#define SBFWakeAnimationSettings RTAnimationFixture_SBFWakeAnimationSettings
#define SBScreenWakeAnimationController RTAnimationFixture_SBScreenWakeAnimationController
#define SBLockScreenManager RTAnimationFixture_SBLockScreenManager
#define CSLockScreenSettings RTAnimationFixture_CSLockScreenSettings
#define SBCoverSheetSlidingViewController RTAnimationFixture_SBCoverSheetSlidingViewController
#define UITimingCurveProvider RTAnimationFixture_UITimingCurveProvider
#endif

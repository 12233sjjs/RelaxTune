#import "Settings.h"
#include "Animation.h"

#ifdef RT_ROOTHIDE
extern const char *jbroot(const char *path);
#endif

atomic_bool RTEnabled = true;
atomic_bool RTAnimations = true;
atomic_bool RTNetwork = true;
atomic_bool RTLowPower = true;
atomic_bool RTGamePerformance = true;
atomic_bool RTHighRefresh = false;
atomic_bool RTAudio = false;
_Atomic(double) RTAnimationFactor = 0.9;

static BOOL RTRead(NSString *key, BOOL fallback) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                      CFSTR("com.12233sjjs.relaxtune"));
    if (!value) return fallback;
    id object = CFBridgingRelease(value);
    return [object isKindOfClass:NSNumber.class] ? [object boolValue] : fallback;
}

void RTLoadSettings(void) {
    CFPreferencesAppSynchronize(CFSTR("com.12233sjjs.relaxtune"));
    atomic_store(&RTAnimations, RTRead(@"Animations", YES));
    atomic_store(&RTNetwork, RTRead(@"Network", YES));
    atomic_store(&RTLowPower, RTRead(@"LowPower", YES));
    atomic_store(&RTGamePerformance, RTRead(@"GamePerformance", YES));
    atomic_store(&RTHighRefresh, RTRead(@"HighRefresh", NO));
    atomic_store(&RTAudio, RTRead(@"Audio", NO));
    CFPropertyListRef raw = CFPreferencesCopyAppValue(CFSTR("AnimationFactor"),
                                                     CFSTR("com.12233sjjs.relaxtune"));
    double factor = 0.9;
    if (raw) {
        id value = CFBridgingRelease(raw);
        if ([value isKindOfClass:NSNumber.class]) factor = [value doubleValue];
    }
    atomic_store(&RTAnimationFactor, RTClampFactor(factor));
    atomic_store(&RTEnabled, RTRead(@"Enabled", YES));
}

BOOL RTIsExcludedApp(NSString *identifier, NSDictionary *configuration) {
    if (!identifier.length) return NO;
    if ([identifier isEqualToString:@"com.tencent.smoba"]) return YES;
    if (![configuration isKindOfClass:NSDictionary.class]) return NO;
    id apps = configuration[@"appconfig"];
    if (![apps isKindOfClass:NSDictionary.class]) return NO;
    id value = apps[identifier];
    return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

BOOL RTShouldLoadAppHooks(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    if (![bundle.bundlePath.pathExtension isEqualToString:@"app"]) return NO;
    NSDictionary *configuration = nil;
#ifdef RT_ROOTHIDE
    // Match Relaxin's read-only appconfig lookup using the current jailbreak root.
    const char *path = jbroot("/var/mobile/Library/RootHide/RootHideConfig.plist");
    if (path) {
        configuration = [NSDictionary dictionaryWithContentsOfFile:
            [NSString stringWithUTF8String:path]];
    }
#endif
    return !RTIsExcludedApp(bundle.bundleIdentifier, configuration);
}

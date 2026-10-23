#import "Settings.h"
#include "Animation.h"

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

BOOL RTIsApp(void) {
    NSString *path = NSBundle.mainBundle.bundlePath;
    return [path.pathExtension isEqualToString:@"app"];
}

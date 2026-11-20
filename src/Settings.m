#import "Settings.h"
#include "Animation.h"

atomic_bool RTEnabled = true;
atomic_bool RTAnimations = true;
atomic_bool RTWakeAnimations = false;
atomic_bool RTUnlockAnimations = false;
atomic_bool RTAnimationExcluded = false;
atomic_bool RTNetwork = true;
atomic_bool RTTCPNoDelay = false;
atomic_bool RTHighRefresh = true;
atomic_bool RTAudio = false;
atomic_bool RTZombieReap = false;
_Atomic(double) RTAnimationFactor = 0.0;
_Atomic(double) RTWakeAcceleration = 0.0;
_Atomic(double) RTUnlockAcceleration = 0.0;

static BOOL RTRead(NSString *key, BOOL fallback) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                      CFSTR("com.12233sjjs.relaxtune"));
    if (!value) return fallback;
    id object = CFBridgingRelease(value);
    return [object isKindOfClass:NSNumber.class] ? [object boolValue] : fallback;
}

static double RTReadAcceleration(NSString *key) {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
        CFSTR("com.12233sjjs.relaxtune")));
    return [value isKindOfClass:NSNumber.class] ? RTClampFactor([value doubleValue]) : 0.0;
}

void RTLoadSettings(void) {
    CFPreferencesAppSynchronize(CFSTR("com.12233sjjs.relaxtune"));
    id excluded = CFBridgingRelease(CFPreferencesCopyAppValue(
        CFSTR("AnimationExcludedApps"), CFSTR("com.12233sjjs.relaxtune")));
    atomic_store(&RTAnimationExcluded,
        RTIsAnimationExcluded(NSBundle.mainBundle.bundleIdentifier, excluded));
    atomic_store(&RTAnimations, RTRead(@"Animations", YES));
    atomic_store(&RTWakeAnimations, RTRead(@"WakeAnimations", NO));
    atomic_store(&RTUnlockAnimations, RTRead(@"UnlockAnimations", NO));
    atomic_store(&RTNetwork, RTRead(@"Network", YES));
    atomic_store(&RTTCPNoDelay, RTRead(@"TCPNoDelay", NO));
    atomic_store(&RTHighRefresh, RTRead(@"HighRefresh", YES));
    atomic_store(&RTAudio, RTRead(@"Audio", NO));
    atomic_store(&RTZombieReap, RTRead(@"ZombieReap", NO));
    atomic_store(&RTAnimationFactor, RTReadAcceleration(@"AnimationAcceleration"));
    atomic_store(&RTWakeAcceleration, RTReadAcceleration(@"WakeAcceleration"));
    atomic_store(&RTUnlockAcceleration, RTReadAcceleration(@"UnlockAcceleration"));
    atomic_store(&RTEnabled, RTRead(@"Enabled", YES));
}

BOOL RTShouldLoadAppHooks(void) {
    // Once injected, app hooks do not depend on RootHide's blacklist or game ID.
    // The injector still controls whether this library is loaded in the first place.
    return [NSBundle.mainBundle.bundlePath.pathExtension isEqualToString:@"app"];
}

BOOL RTShouldLoadMainTweak(NSString *bundleIdentifier, BOOL isApplicationBundle) {
    return [bundleIdentifier isEqualToString:@"com.apple.springboard"] || isApplicationBundle;
}

BOOL RTIsAnimationExcluded(NSString *identifier, NSArray *excludedIdentifiers) {
    if (!identifier.length || ![excludedIdentifiers isKindOfClass:NSArray.class]) return NO;
    for (id entry in excludedIdentifiers) {
        if ([entry isKindOfClass:NSString.class] &&
            [entry caseInsensitiveCompare:identifier] == NSOrderedSame) return YES;
    }
    return NO;
}

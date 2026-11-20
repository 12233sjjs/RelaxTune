#import <Foundation/Foundation.h>
#import "Settings.h"
#include <assert.h>
#include <stdio.h>
#include <math.h>

static void testAccelerationPreferences(void) {
    CFStringRef domain = CFSTR("com.12233sjjs.relaxtune");
    NSArray<NSString *> *keys = @[@"AnimationFactor", @"AnimationAcceleration", @"WakeAcceleration",
        @"UnlockAcceleration", @"WakeAnimations", @"UnlockAnimations"];
    NSMutableDictionary *original = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        original[key] = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, domain)) ?: NSNull.null;
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, domain);
    }
    @try {
        // Old duration ratios must not be reinterpreted as acceleration levels.
        CFPreferencesSetAppValue(CFSTR("AnimationFactor"), (__bridge CFPropertyListRef)@10, domain);
        RTLoadSettings();
        assert(atomic_load(&RTAnimationFactor) == 0.0);
        assert(atomic_load(&RTWakeAcceleration) == 0.0 && !atomic_load(&RTWakeAnimations));
        assert(atomic_load(&RTUnlockAcceleration) == 0.0 && !atomic_load(&RTUnlockAnimations));
        CFPreferencesSetAppValue(CFSTR("AnimationAcceleration"), (__bridge CFPropertyListRef)@0.96, domain);
        CFPreferencesSetAppValue(CFSTR("WakeAcceleration"), (__bridge CFPropertyListRef)@2.34, domain);
        CFPreferencesSetAppValue(CFSTR("UnlockAcceleration"), (__bridge CFPropertyListRef)@20, domain);
        CFPreferencesSetAppValue(CFSTR("WakeAnimations"), kCFBooleanTrue, domain);
        CFPreferencesSetAppValue(CFSTR("UnlockAnimations"), kCFBooleanFalse, domain);
        RTLoadSettings();
        assert(atomic_load(&RTAnimationFactor) == 1.0);
        assert(fabs(atomic_load(&RTWakeAcceleration) - 2.3) < 1e-12);
        assert(atomic_load(&RTUnlockAcceleration) == 10.0);
        assert(atomic_load(&RTWakeAnimations) && !atomic_load(&RTUnlockAnimations));
        CFPreferencesSetAppValue(CFSTR("AnimationAcceleration"), (__bridge CFPropertyListRef)@"invalid", domain);
        RTLoadSettings();
        assert(atomic_load(&RTAnimationFactor) == 0.0);
    } @finally {
        for (NSString *key in keys) {
            id value = original[key];
            CFPreferencesSetAppValue((__bridge CFStringRef)key,
                value == NSNull.null ? NULL : (__bridge CFPropertyListRef)value, domain);
        }
        CFPreferencesAppSynchronize(domain);
    }
}

int main(void) {
    @autoreleasepool {
        assert(RTShouldLoadMainTweak(@"com.apple.springboard", NO));
        assert(RTShouldLoadMainTweak(@"com.example.blocked", YES));
        assert(RTShouldLoadMainTweak(@"com.example.allowed", YES));
        assert(RTShouldLoadMainTweak(@"com.tencent.smoba", YES));
        assert(RTShouldLoadMainTweak(nil, YES));
        assert(!RTShouldLoadMainTweak(@"com.example.daemon", NO));
        assert(RTShouldLoadMainTweak(@"com.example.daemon", YES));
        // App eligibility depends only on bundle type, not an external app list.
        assert(RTShouldLoadAppHooks() ==
            [NSBundle.mainBundle.bundlePath.pathExtension isEqualToString:@"app"]);
        assert(RTIsAnimationExcluded(@"com.example.blocked", @[@"com.example.blocked"]));
        assert(RTIsAnimationExcluded(@"com.example.blocked", @[@"COM.EXAMPLE.BLOCKED"]));
        assert(!RTIsAnimationExcluded(@"com.example.allowed", @[@"com.example.blocked"]));
        assert(!RTIsAnimationExcluded(nil, @[@"com.example.blocked"]));
        testAccelerationPreferences();
        puts("PASS: blacklist-independent app eligibility and manual animation exclusions");
    }
    return 0;
}

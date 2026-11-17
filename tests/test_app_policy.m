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
        NSDictionary *configuration = @{
            @"appconfig": @{
                @"com.example.blocked": @YES,
                @"com.example.allowed": @NO,
                @"com.example.numeric": @1,
                @"com.example.invalid": @"true",
                @"com.example.null": NSNull.null,
                @"com.tencent.smoba": @NO
            }
        };
        assert(RTShouldLoadMainTweak(@"com.apple.springboard", NO));
        assert(RTShouldLoadMainTweak(@"com.example.blocked", YES));
        assert(RTShouldLoadMainTweak(@"com.example.allowed", YES));
        assert(!RTShouldLoadMainTweak(@"com.example.daemon", NO));
        assert(RTShouldLoadMainTweak(@"com.example.daemon", YES));
        assert(RTIsAnimationExcluded(@"com.example.blocked", @[@"com.example.blocked"]));
        assert(RTIsAnimationExcluded(@"com.example.blocked", @[@"COM.EXAMPLE.BLOCKED"]));
        assert(!RTIsAnimationExcluded(@"com.example.allowed", @[@"com.example.blocked"]));
        assert(!RTIsAnimationExcluded(nil, @[@"com.example.blocked"]));
        assert(RTIsExcludedApp(@"com.tencent.smoba", nil));
        assert(RTIsExcludedApp(@"com.tencent.smoba", configuration));
        assert(!RTIsExcludedApp(@"com.tencent.smoba.other", configuration));
        assert(RTIsExcludedApp(@"com.example.blocked", configuration));
        assert(RTIsExcludedApp(@"com.example.numeric", configuration));
        assert(!RTIsExcludedApp(@"com.example.allowed", configuration));
        assert(!RTIsExcludedApp(@"com.example.unknown", configuration));
        assert(!RTIsExcludedApp(@"com.example.invalid", configuration));
        assert(!RTIsExcludedApp(@"com.example.null", configuration));
        assert(!RTIsExcludedApp(nil, configuration));
        assert(!RTIsExcludedApp(@"", configuration));
        assert(!RTIsExcludedApp(@"com.example.blocked", nil));
        assert(!RTIsExcludedApp(@"com.example.blocked", @{}));
        assert(!RTIsExcludedApp(@"com.example.blocked", @{@"appconfig": @[]}));
        assert(!RTIsExcludedApp(@"com.example.blocked", (NSDictionary *)@[]));
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:@{
            @"appconfig": @{@"com.example.blocked": @YES, @"com.example.allowed": @NO}
        } format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
        NSDictionary *decoded = [NSPropertyListSerialization propertyListWithData:data
            options:NSPropertyListImmutable format:NULL error:nil];
        assert(RTIsExcludedApp(@"com.example.blocked", decoded));
        assert(!RTIsExcludedApp(@"com.example.allowed", decoded));
        testAccelerationPreferences();
        puts("PASS: fixed game exclusion, RootHide appconfig and malformed configuration handling");
    }
    return 0;
}

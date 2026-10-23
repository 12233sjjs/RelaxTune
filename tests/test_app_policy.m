#import <Foundation/Foundation.h>
#import "Settings.h"
#include <assert.h>
#include <stdio.h>

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
        puts("PASS: fixed game exclusion, RootHide appconfig and malformed configuration handling");
    }
    return 0;
}

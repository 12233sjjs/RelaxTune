#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "RTBatteryTemperature.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

enum {
    CaseValid = 0,
    CaseNoService,
    CasePropertiesError,
    CaseMissingKey,
    CaseWrongPropertiesType,
    CaseString,
    CaseBoolean,
    CaseNaN,
    CaseMinBound,
    CaseMaxBound,
    CaseTooCold,
    CaseTooHot,
    CaseReleaseError,
    CaseNoMatchingDictionary
};

static int gCase;
static unsigned gMatchingCalls;
static unsigned gServiceLookupCalls;
static unsigned gPropertiesCalls;
static unsigned gReleaseCalls;
static const uint32_t kMockService = 77;

static CFMutableDictionaryRef mockServiceMatching(const char *name) {
    assert(name != NULL && strcmp(name, "IOPMPowerSource") == 0);
    ++gMatchingCalls;
    if (gCase == CaseNoMatchingDictionary) return NULL;
    return CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static uint32_t mockServiceGetMatchingService(uint32_t masterPort,
                                               CFDictionaryRef matching) {
    assert(masterPort == 0);
    assert(matching != NULL && CFGetTypeID(matching) == CFDictionaryGetTypeID());
    ++gServiceLookupCalls;
    /* Mirrors IOKit's consume-on-call ownership of the matching dictionary. */
    CFRelease(matching);
    return gCase == CaseNoService ? 0 : kMockService;
}

static int32_t mockRegistryEntryCreateCFProperties(uint32_t entry,
    CFMutableDictionaryRef *properties, CFAllocatorRef allocator, uint32_t options) {
    assert(entry == kMockService);
    assert(allocator == kCFAllocatorDefault && options == 0);
    ++gPropertiesCalls;
    *properties = NULL;
    if (gCase == CasePropertiesError) {
        *properties = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        assert(*properties != NULL);
        return -1; /* Provider must release even an error-path returned object. */
    }
    if (gCase == CaseWrongPropertiesType) {
        *properties = (CFMutableDictionaryRef)CFRetain(CFSTR("not a dictionary"));
        return 0;
    }

    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault,
        0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    assert(dictionary != NULL);
    if (gCase != CaseMissingKey) {
        CFTypeRef value = NULL;
        double raw = 3267.0;
        if (gCase == CaseString) {
            value = CFRetain(CFSTR("3267"));
        } else if (gCase == CaseBoolean) {
            value = CFRetain(kCFBooleanTrue);
        } else {
            if (gCase == CaseNaN) raw = NAN;
            if (gCase == CaseMinBound) raw = -4000.0;
            if (gCase == CaseMaxBound) raw = 12500.0;
            if (gCase == CaseTooCold) raw = -4000.01;
            if (gCase == CaseTooHot) raw = 12500.01;
            value = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &raw);
        }
        assert(value != NULL);
        CFDictionarySetValue(dictionary, CFSTR("Temperature"), value);
        CFRelease(value);
    }
    *properties = dictionary; /* Create ownership is transferred to the caller. */
    return 0;
}

static int32_t mockIOObjectRelease(uint32_t object) {
    assert(object == kMockService);
    ++gReleaseCalls;
    return gCase == CaseReleaseError ? -1 : 0;
}

static void resetCounters(void) {
    gMatchingCalls = 0;
    gServiceLookupCalls = 0;
    gPropertiesCalls = 0;
    gReleaseCalls = 0;
}

static void testCase(int testCase, bool expectedSuccess, double expectedCelsius,
                     unsigned expectedLookups, unsigned expectedProperties,
                     unsigned expectedReleases) {
    gCase = testCase;
    resetCounters();
    double output = 88.5;
    BOOL result = RTReadBatteryTemperatureC(&output);
    assert((result == YES) == expectedSuccess);
    if (expectedSuccess) assert(fabs(output - expectedCelsius) < 1e-12);
    else assert(output == 88.5);
    assert(gMatchingCalls == 1);
    assert(gServiceLookupCalls == expectedLookups);
    assert(gPropertiesCalls == expectedProperties);
    assert(gReleaseCalls == expectedReleases);
}

int main(void) {
    @autoreleasepool {
        RTBatteryTemperatureTestBackend backend = {
            .serviceMatching = mockServiceMatching,
            .serviceGetMatchingService = mockServiceGetMatchingService,
            .registryEntryCreateCFProperties = mockRegistryEntryCreateCFProperties,
            .objectRelease = mockIOObjectRelease
        };
        RTSetBatteryTemperatureTestBackend(&backend);

        testCase(CaseValid, YES, 32.67, 1, 1, 1);
        testCase(CaseNoService, NO, 0.0, 1, 0, 0);
        testCase(CasePropertiesError, NO, 0.0, 1, 1, 1);
        testCase(CaseMissingKey, NO, 0.0, 1, 1, 1);
        testCase(CaseWrongPropertiesType, NO, 0.0, 1, 1, 1);
        testCase(CaseString, NO, 0.0, 1, 1, 1);
        testCase(CaseBoolean, NO, 0.0, 1, 1, 1);
        testCase(CaseNaN, NO, 0.0, 1, 1, 1);
        testCase(CaseMinBound, YES, -40.0, 1, 1, 1);
        testCase(CaseMaxBound, YES, 125.0, 1, 1, 1);
        testCase(CaseTooCold, NO, 0.0, 1, 1, 1);
        testCase(CaseTooHot, NO, 0.0, 1, 1, 1);
        testCase(CaseReleaseError, NO, 0.0, 1, 1, 1);
        testCase(CaseNoMatchingDictionary, NO, 0.0, 0, 0, 0);

        /* Incomplete backend rejects safely before acquiring registry objects. */
        backend.registryEntryCreateCFProperties = NULL;
        RTSetBatteryTemperatureTestBackend(&backend);
        resetCounters();
        double unchanged = 19.0;
        assert(!RTReadBatteryTemperatureC(&unchanged));
        assert(unchanged == 19.0);
        assert(gMatchingCalls == 0 && gServiceLookupCalls == 0 &&
               gPropertiesCalls == 0 && gReleaseCalls == 0);
        assert(!RTReadBatteryTemperatureC(NULL));

        RTSetBatteryTemperatureTestBackend(NULL);
        puts("PASS: mocked IOKit success/failure paths, ownership releases, type checks, no stale output");
    }
    return 0;
}

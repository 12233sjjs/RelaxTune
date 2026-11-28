#include "RTTimeCapsulePolicy.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    const char *own = "/var/containers/Bundle/.jbroot-A1/Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib";
    const char *donor = "/var/containers/Bundle/.jbroot-A1/Library/MobileSubstrate/DynamicLibraries/DateInfo.dylib";
    assert(RTTimeCapsuleExpectedImage(donor, own));
    assert(RTTimeCapsuleExpectedImage("/Library/MobileSubstrate/DynamicLibraries/DateInfo.dylib",
                                    "/Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib"));
    assert(RTTimeCapsuleExpectedImage("/var/jb/Library/MobileSubstrate/DynamicLibraries/DateInfo.dylib",
                                    "/var/jb/Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib"));
    assert(!RTTimeCapsuleExpectedImage(NULL, own));
    assert(!RTTimeCapsuleExpectedImage(donor, NULL));
    assert(!RTTimeCapsuleExpectedImage("DateInfo.dylib", own));
    assert(!RTTimeCapsuleExpectedImage("/tmp/DateInfo.dylib", own));
    assert(!RTTimeCapsuleExpectedImage("/tmp/DateInfo.dylib", "/tmp/RelaxTune.dylib"));
    assert(!RTTimeCapsuleExpectedImage("/Library/MobileSubstrate/DynamicLibraries/DateInfo.dylib.fake", own));
    assert(!RTTimeCapsuleExpectedImage("/Library/MobileSubstrate/DynamicLibraries/dateinfo.dylib", own));
    assert(!RTTimeCapsuleExpectedImage("/var/jb2/Library/MobileSubstrate/DynamicLibraries/DateInfo.dylib", own));
    assert(!RTTimeCapsuleExpectedImage(donor, "/Library/MobileSubstrate/DynamicLibraries/"));

    RTTimeCapsuleSample s = {0};
    assert(RTTimeCapsuleMaySample(&s, 0));
    assert(!RTTimeCapsuleMaySample(&s, NAN));
    assert(!RTTimeCapsuleMaySample(&s, INFINITY));
    assert(!RTTimeCapsuleMaySample(&s, -1));
    assert(!RTTimeCapsuleSampleFresh(&s, 0));
    s = (RTTimeCapsuleSample){true, true, 10, 32.5};
    assert(RTTimeCapsuleSampleFresh(&s, 10));
    assert(RTTimeCapsuleSampleFresh(&s, 10.999));
    assert(!RTTimeCapsuleMaySample(&s, 10.999));
    assert(RTTimeCapsuleMaySample(&s, 11));
    assert(!RTTimeCapsuleSampleFresh(&s, 11));
    assert(!RTTimeCapsuleSampleFresh(&s, 9));
    assert(!RTTimeCapsuleMaySample(&s, 9));
    assert(!RTTimeCapsuleSampleFresh(&s, NAN));
    s.valid = false;
    assert(!RTTimeCapsuleSampleFresh(&s, 10.1));
    assert(!RTTimeCapsuleMaySample(&s, 10.1)); // Failures are rate-limited too.
    assert(RTTimeCapsuleMaySample(&s, 10000)); // No resident timer needed on resume.
    puts("PASS: actual companion image-path and monotonic freshness/rate-limit policy");
    return 0;
}

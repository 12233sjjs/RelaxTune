#ifndef RT_TIME_CAPSULE_POLICY_H
#define RT_TIME_CAPSULE_POLICY_H

#include <stdbool.h>
#include <math.h>
#include <stddef.h>
#include <string.h>

/* Inputs must already be canonical absolute paths (realpath in production).
 * Accept only a sibling of this companion in the tweak installation directory.
 * RootHide/rootless prefixes may vary; a basename-only match is NOT enough.
 * This is an installation-path check, NOT cryptographic/author authentication. */
static inline bool RTTimeCapsuleExpectedImage(const char *image, const char *companion) {
    const char *suffix = "/Library/MobileSubstrate/DynamicLibraries";
    if (!image || !companion || image[0] != '/' || companion[0] != '/') return false;
    const char *imageName = strrchr(image, '/');
    const char *ownName = strrchr(companion, '/');
    if (!imageName || !ownName || strcmp(imageName + 1, "DateInfo.dylib") != 0 ||
        ownName[1] == '\0') return false;
    size_t directoryLength = (size_t)(ownName - companion);
    size_t suffixLength = strlen(suffix);
    return directoryLength >= suffixLength &&
        (size_t)(imageName - image) == directoryLength &&
        memcmp(image, companion, directoryLength) == 0 &&
        memcmp(companion + directoryLength - suffixLength, suffix, suffixLength) == 0;
}

typedef struct {
    bool attempted;
    bool valid;
    double attemptedAt;
    double celsius;
} RTTimeCapsuleSample;

/* A failed attempt is cached too. No clock -> no read; a clock regression must
 * not cause a burst of new reads or present a sample from the future. */
static inline bool RTTimeCapsuleMaySample(const RTTimeCapsuleSample *sample, double now) {
    return isfinite(now) && now >= 0.0 &&
        (!sample->attempted || (now >= sample->attemptedAt && now - sample->attemptedAt >= 1.0));
}
static inline bool RTTimeCapsuleSampleFresh(const RTTimeCapsuleSample *sample, double now) {
    return sample->attempted && sample->valid && isfinite(now) &&
        now >= sample->attemptedAt && now - sample->attemptedAt < 1.0;
}
#endif

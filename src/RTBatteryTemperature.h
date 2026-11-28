#ifndef RT_BATTERY_TEMPERATURE_H
#define RT_BATTERY_TEMPERATURE_H

#import <Foundation/Foundation.h>
#include <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Reads IOPMPowerSource's registry "Temperature" value and converts it to
 * degrees Celsius. Returns NO for unavailable, denied, malformed, non-finite,
 * or out-of-bounds values. On failure, does not modify *outCelsius.
 *
 * This is a synchronous one-shot read; callers should invoke it only while
 * their battery bubble is visible (approximately once per second at most).
 */
FOUNDATION_EXPORT BOOL RTReadBatteryTemperatureC(double *outCelsius);

#if defined(RT_BATTERY_TEMPERATURE_TESTING)
#include <stdint.h>
/* Test-only ABI-compatible injection seam; never present in production builds. */
typedef struct {
    CFMutableDictionaryRef (*serviceMatching)(const char *name);
    uint32_t (*serviceGetMatchingService)(uint32_t masterPort, CFDictionaryRef matching);
    int32_t (*registryEntryCreateCFProperties)(uint32_t entry,
        CFMutableDictionaryRef *properties, CFAllocatorRef allocator, uint32_t options);
    int32_t (*objectRelease)(uint32_t object);
} RTBatteryTemperatureTestBackend;

FOUNDATION_EXPORT void RTSetBatteryTemperatureTestBackend(
    const RTBatteryTemperatureTestBackend * _Nullable backend);
#endif

NS_ASSUME_NONNULL_END

#endif /* RT_BATTERY_TEMPERATURE_H */

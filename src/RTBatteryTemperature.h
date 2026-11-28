#ifndef RT_BATTERY_TEMPERATURE_H
#define RT_BATTERY_TEMPERATURE_H

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Reads IOPMPowerSource's registry "Temperature" value and converts it to
 * degrees Celsius. Returns NO for unavailable, denied, malformed, non-finite,
 * or out-of-bounds values. On failure, does not modify *outCelsius.
 *
 * This is a synchronous one-shot read; callers should invoke it only while
 * their battery bubble is visible (approximately once per second at most).
 */
FOUNDATION_EXPORT BOOL RTReadBatteryTemperatureC(double * _Nullable outCelsius);

#if defined(RT_BATTERY_TEMPERATURE_TESTING)
/* Test-only ABI-compatible injection seam; never present in production builds. */
typedef struct {
    CFMutableDictionaryRef _Nullable (* _Nullable serviceMatching)(const char *name);
    uint32_t (* _Nullable serviceGetMatchingService)(uint32_t masterPort, CFDictionaryRef matching);
    int32_t (* _Nullable registryEntryCreateCFProperties)(uint32_t entry,
        CFMutableDictionaryRef _Nullable * _Nonnull properties, CFAllocatorRef _Nullable allocator, uint32_t options);
    int32_t (* _Nullable objectRelease)(uint32_t object);
} RTBatteryTemperatureTestBackend;

FOUNDATION_EXPORT void RTSetBatteryTemperatureTestBackend(
    const RTBatteryTemperatureTestBackend * _Nullable backend);
#endif

NS_ASSUME_NONNULL_END

#endif /* RT_BATTERY_TEMPERATURE_H */

#import "RTBatteryTemperature.h"
#import "RTBatteryTemperaturePolicy.h"

#include <dlfcn.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

/*
 * Deliberately redeclare only the stable C ABI signatures needed here. The
 * iOS SDK's IOKit headers mark these interfaces unavailable to iOS; resolving
 * them dynamically avoids importing those declarations or linking IOKit.
 */
typedef CFMutableDictionaryRef (*RTIOServiceMatchingFn)(const char *name);
typedef uint32_t (*RTIOServiceGetMatchingServiceFn)(uint32_t masterPort,
                                                    CFDictionaryRef matching);
typedef int32_t (*RTIORegistryEntryCreateCFPropertiesFn)(uint32_t entry,
    CFMutableDictionaryRef *properties, CFAllocatorRef allocator, uint32_t options);
typedef int32_t (*RTIOObjectReleaseFn)(uint32_t object);

typedef struct {
    RTIOServiceMatchingFn serviceMatching;
    RTIOServiceGetMatchingServiceFn serviceGetMatchingService;
    RTIORegistryEntryCreateCFPropertiesFn createProperties;
    RTIOObjectReleaseFn objectRelease;
} RTBatteryTemperatureBackend;

#if defined(RT_BATTERY_TEMPERATURE_TESTING)
static RTBatteryTemperatureBackend RTTestBackend;
static bool RTTestBackendEnabled = false;

void RTSetBatteryTemperatureTestBackend(
    const RTBatteryTemperatureTestBackend *backend) {
    if (backend == NULL) {
        memset(&RTTestBackend, 0, sizeof(RTTestBackend));
        RTTestBackendEnabled = false;
        return;
    }
    RTTestBackend.serviceMatching = backend->serviceMatching;
    RTTestBackend.serviceGetMatchingService = backend->serviceGetMatchingService;
    RTTestBackend.createProperties = backend->registryEntryCreateCFProperties;
    RTTestBackend.objectRelease = backend->objectRelease;
    RTTestBackendEnabled = true;
}
#endif

static bool RTResolveSymbol(void *handle, const char *name,
                            void *destination, size_t destinationSize) {
    void *symbol = dlsym(handle, name);
    if (symbol == NULL || destinationSize != sizeof(symbol)) return false;
    memcpy(destination, &symbol, sizeof(symbol));
    return true;
}

static bool RTBackendComplete(const RTBatteryTemperatureBackend *backend) {
    return backend->serviceMatching != NULL &&
        backend->serviceGetMatchingService != NULL &&
        backend->createProperties != NULL && backend->objectRelease != NULL;
}

BOOL RTReadBatteryTemperatureC(double *outCelsius) {
    if (outCelsius == NULL) return NO;

    RTBatteryTemperatureBackend backend = {0};
    void *framework = NULL;
    uint32_t service = 0;
    CFMutableDictionaryRef matching = NULL;
    CFMutableDictionaryRef properties = NULL;
    int32_t propertiesStatus = 0;
    double resultCelsius = 0.0;
    bool success = false;

#if defined(RT_BATTERY_TEMPERATURE_TESTING)
    if (RTTestBackendEnabled) {
        backend = RTTestBackend;
    } else
#endif
    {
        framework = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",
                           RTLD_LAZY | RTLD_LOCAL);
        if (framework == NULL) goto cleanup;
        if (!RTResolveSymbol(framework, "IOServiceMatching",
                             &backend.serviceMatching, sizeof(backend.serviceMatching)) ||
            !RTResolveSymbol(framework, "IOServiceGetMatchingService",
                             &backend.serviceGetMatchingService,
                             sizeof(backend.serviceGetMatchingService)) ||
            !RTResolveSymbol(framework, "IORegistryEntryCreateCFProperties",
                             &backend.createProperties, sizeof(backend.createProperties)) ||
            !RTResolveSymbol(framework, "IOObjectRelease",
                             &backend.objectRelease, sizeof(backend.objectRelease)))
            goto cleanup;
    }

    if (!RTBackendComplete(&backend)) goto cleanup;

    /* IOServiceGetMatchingService consumes the matching dictionary. */
    matching = backend.serviceMatching("IOPMPowerSource");
    if (matching == NULL) goto cleanup;
    service = backend.serviceGetMatchingService(0, matching);
    matching = NULL;
    if (service == 0) goto cleanup;

    propertiesStatus = backend.createProperties(
        service, &properties, kCFAllocatorDefault, 0);
    if (propertiesStatus == 0 && properties != NULL &&
        CFGetTypeID(properties) == CFDictionaryGetTypeID()) {
        const void *rawValue = CFDictionaryGetValue(properties, CFSTR("Temperature"));
        if (rawValue != NULL && CFGetTypeID(rawValue) == CFNumberGetTypeID()) {
            double rawCentiCelsius = 0.0;
            if (CFNumberGetValue((CFNumberRef)rawValue, kCFNumberDoubleType,
                                 &rawCentiCelsius)) {
                success = RTBatteryTemperatureCFromRaw(rawCentiCelsius, &resultCelsius);
            }
        }
    }

cleanup:
    if (properties != NULL) CFRelease(properties);
    if (service != 0 && backend.objectRelease != NULL &&
        backend.objectRelease(service) != 0) success = false;
    if (framework != NULL) dlclose(framework);

    /* Commit only after all checks and cleanup; failures cannot leak stale data. */
    if (success) *outCelsius = resultCelsius;
    return success ? YES : NO;
}

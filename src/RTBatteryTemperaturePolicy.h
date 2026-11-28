#ifndef RT_BATTERY_TEMPERATURE_POLICY_H
#define RT_BATTERY_TEMPERATURE_POLICY_H

#include <math.h>
#include <stdbool.h>

/* IOPMPowerSource's Temperature registry value is centi-degrees Celsius. */
#define RT_BATTERY_TEMPERATURE_MIN_C (-40.0)
#define RT_BATTERY_TEMPERATURE_MAX_C (125.0)

/*
 * Converts a raw centi-Celsius value to Celsius. Boundaries are inclusive.
 * Invalid input (including NaN/infinity) and a null output return false and
 * leave *outCelsius untouched.
 */
static inline bool RTBatteryTemperatureCFromRaw(double rawCentiCelsius,
                                                 double *outCelsius) {
    if (outCelsius == 0 || !isfinite(rawCentiCelsius)) return false;
    const double minRaw = RT_BATTERY_TEMPERATURE_MIN_C * 100.0;
    const double maxRaw = RT_BATTERY_TEMPERATURE_MAX_C * 100.0;
    if (rawCentiCelsius < minRaw || rawCentiCelsius > maxRaw) return false;
    const double celsius = rawCentiCelsius / 100.0;
    if (!isfinite(celsius) || celsius < RT_BATTERY_TEMPERATURE_MIN_C ||
        celsius > RT_BATTERY_TEMPERATURE_MAX_C) return false;
    *outCelsius = celsius;
    return true;
}

#endif /* RT_BATTERY_TEMPERATURE_POLICY_H */

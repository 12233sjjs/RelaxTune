# Real battery temperature source

`RTReadBatteryTemperatureC(double *)` performs one synchronous read of the
`Temperature` property on the `IOPMPowerSource` IORegistry service. The value is
a `CFNumber` in centi-degrees Celsius; the provider divides it by 100 and
returns Celsius. There is no use of `thermalState`, CPU sensors, guessed
values, donor binaries, a retained service, a timer, or a worker thread.

## Units provenance

The unit conversion is independently corroborated by the public
[pymobiledevice3 diagnostics implementation](https://github.com/doronz88/pymobiledevice3/blob/a7b136e2a47d05a593a51c1743975cf8cdd8c2e6/pymobiledevice3/services/diagnostics.py)
(commit `a7b136e2a47d05a593a51c1743975cf8cdd8c2e6`, file
`pymobiledevice3/services/diagnostics.py`): its `BatteryInfo` conversion maps
`Temperature` to `temperature / 100`. The same project's public diagnostics
code documents the `IOPMPowerSource` registry source. This implementation
uses only the documented unit fact; it does not copy third-party code.

## Runtime and ownership

The iOS SDK's IOKit declarations are not imported. The provider declares only
the required C ABI function-pointer signatures and dynamically resolves
`IOServiceMatching`, `IOServiceGetMatchingService`,
`IORegistryEntryCreateCFProperties`, and `IOObjectRelease` from
`/System/Library/Frameworks/IOKit.framework/IOKit`. It opens and closes that
framework for each call; no service or handle is cached. The matching
dictionary is handed to `IOServiceGetMatchingService` (which consumes it), the
created properties dictionary is released with `CFRelease`, and every
nonzero service is released with `IOObjectRelease`, including property-read
and validation failures. An object-release error also makes the read fail.

The result is accepted only when the property container is a dictionary, the
`Temperature` key exists, its value is a `CFNumber` (not a `CFBoolean`, string,
or other object), conversion succeeds, and the converted value is finite and
within the inclusive `-40.0...125.0 °C` admissibility envelope. The envelope
is a defensive plausibility bound, not a claim about sensor accuracy or a
battery's safe operating limits. Failures return `NO` and leave the caller's
output untouched; there is no stale-value cache or fabricated fallback.

The API is an on-demand private IORegistry read, not a promise of availability
on every iOS build/device. A denied, unavailable, missing, or changed registry
interface returns unavailable. Integrators should call it only while the
bubble is visible, at most approximately once per second, and display
unavailable on `NO`. No device read was performed as part of this work.

## Tests and commands

The pure conversion policy is independent C (`RTBatteryTemperaturePolicy.h`)
and has been compiled and run here at both `-O0` and `-O2`. The Objective-C
provider fixture injects fake IOKit ABI functions only when compiled with
`RT_BATTERY_TEMPERATURE_TESTING`; the test-only setter is absent from
production builds. On macOS, run the complete tests from the repository root:

```sh
clang -std=c11 -Wall -Wextra -Werror -O0 -Isrc \
  tests/test_battery_temperature.c -lm -o /tmp/rt-battery-temperature-o0
/tmp/rt-battery-temperature-o0
clang -std=c11 -Wall -Wextra -Werror -O2 -Isrc \
  tests/test_battery_temperature.c -lm -o /tmp/rt-battery-temperature-o2
/tmp/rt-battery-temperature-o2
clang -fobjc-arc -Wall -Wextra -Werror \
  -DRT_BATTERY_TEMPERATURE_TESTING -Isrc \
  src/RTBatteryTemperature.m tests/test_battery_temperature.m \
  -framework Foundation -framework CoreFoundation \
  -o /tmp/rt-battery-temperature-provider
/tmp/rt-battery-temperature-provider
```

The Objective-C fixture covers a valid decimal value; unavailable service;
property API error with a returned object; absent key; non-dictionary property
object; string and Boolean values; NaN; inclusive minimum and maximum; values
outside both bounds; service release failure; missing matching dictionary;
incomplete injected ABI; output unchanged on failure; and release-call counts.
The local Alpine/iSH environment has neither Apple's Foundation/CoreFoundation
SDK nor the macOS Objective-C ARC runtime, so the Objective-C fixture must be
compiled and executed by macOS CI using the command above. No package or
binary was installed to work around that platform limitation.

Expected successful test output:

```text
PASS: Celsius conversion, precision, inclusive limits, malformed numeric edges, unchanged failure output
PASS: Celsius conversion, precision, inclusive limits, malformed numeric edges, unchanged failure output
PASS: mocked IOKit success/failure paths, ownership releases, type checks, no stale output
```

## Integration boundary

`RTBatteryTemperature.m` is part of the extension source build and explicitly
links CoreFoundation; no IOKit framework link is needed. The separate
`TimeCapsuleBattery.x` companion calls `RTReadBatteryTemperatureC(&temperatureC)`
only on eligible visible main-thread updates, at most once per second. It shows
unavailable on `NO` instead of using an older good sample. This prototype is
default OFF and needs donor/device layout and genuine source-unit validation;
no background sampling timer is introduced.

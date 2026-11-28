#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "RTBatteryTemperaturePolicy.h"

static void expectRejected(double raw) {
    double output = 73.25;
    assert(!RTBatteryTemperatureCFromRaw(raw, &output));
    assert(output == 73.25);
}

int main(void) {
    double celsius = -999.0;
    assert(!RTBatteryTemperatureCFromRaw(0.0, NULL));
    assert(celsius == -999.0);

    assert(RTBatteryTemperatureCFromRaw(0.0, &celsius) && celsius == 0.0);
    assert(RTBatteryTemperatureCFromRaw(3275.0, &celsius) && celsius == 32.75);
    assert(RTBatteryTemperatureCFromRaw(-123.0, &celsius) && celsius == -1.23);
    assert(RTBatteryTemperatureCFromRaw(1.0, &celsius) && celsius == 0.01);
    assert(RTBatteryTemperatureCFromRaw(-1.0, &celsius) && celsius == -0.01);

    assert(RTBatteryTemperatureCFromRaw(-4000.0, &celsius) &&
           celsius == RT_BATTERY_TEMPERATURE_MIN_C);
    assert(RTBatteryTemperatureCFromRaw(12500.0, &celsius) &&
           celsius == RT_BATTERY_TEMPERATURE_MAX_C);
    expectRejected(-4000.0001);
    expectRejected(12500.0001);
    expectRejected(NAN);
    expectRejected(INFINITY);
    expectRejected(-INFINITY);

    puts("PASS: Celsius conversion, precision, inclusive limits, malformed numeric edges, unchanged failure output");
    return 0;
}

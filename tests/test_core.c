#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "DSP.h"
#include "Animation.h"

static void testAnimation(void) {
    double previousDuration = INFINITY;
    for (unsigned i = 0; i <= 100; i++) {
        double value = i / 10.0;
        assert(fabs(RTClampFactor(value) - value) < 1e-12);
        double expectedSpeed = 1.0 + 0.9 * value;
        double uiDuration = RTScaledDuration(0.5, value);
        double sbDuration = 0.5 / RTSmoothPlaybackSpeed(1.0, value);
        assert(fabs(uiDuration - 0.5 / expectedSpeed) < 1e-12);
        assert(fabs(uiDuration - sbDuration) < 1e-12);
        assert(uiDuration < previousDuration);
        assert(uiDuration > 0.0 && isfinite(uiDuration));
        previousDuration = uiDuration;
        assert(fabs(RTSmoothPlaybackSpeed(0.5, value) - 0.5 * expectedSpeed) < 1e-12);
    }
    assert(RTClampFactor(-1.0) == 0.0);
    assert(RTClampFactor(11.0) == 10.0);
    assert(RTClampFactor(NAN) == 0.0);
    assert(RTClampFactor(INFINITY) == 0.0);
    assert(RTClampFactor(0.94) == 0.9);
    assert(RTClampFactor(0.96) == 1.0);
    assert(RTClampFactor(9.999) == 10.0);
    assert(RTScaledDuration(5.0, 0.0) == 5.0);
    assert(RTScaledDuration(0.05, 0.0) == 0.05);
    assert(RTScaledDuration(0.5, 0.0) == 0.5);
    assert(RTScaledDuration(0.5, 10.0) == 0.05);
    assert(RTSmoothPlaybackSpeed(1.0, 0.0) == 1.0);
    assert(RTSmoothPlaybackSpeed(1.0, 10.0) == 10.0);
    assert(RTSmoothPlaybackSpeed(NAN, 0.0) == 1.0);
    assert(RTSmoothPlaybackSpeed(INFINITY, 0.0) == 1.0);
    assert(RTSmoothPlaybackSpeed(100.0, 0.0) == 100.0);
    assert(RTSmoothPlaybackSpeed(0.01, 10.0) == 0.1);
}

static double gain(double rate, double frequency) {
    RTEqualizer eq;
    assert(RTEQInit(&eq, rate));
    double sumIn = 0.0, sumOut = 0.0;
    for (unsigned i = 0; i < (unsigned)rate * 2; i++) {
        float input = (float)(0.25 * sin(6.283185307179586 * frequency * i / rate));
        float output = RTEQSample(&eq, 0, input);
        assert(isfinite(output));
        assert(fabsf(output) <= 1.0f);
        assert(RTEQSample(&eq, 1, 0.0f) == 0.0f);
        if (i > rate) {
            sumIn += input * input;
            sumOut += output * output;
        }
    }
    return sqrt(sumOut / sumIn);
}

static void testDSP(void) {
    RTEqualizer eq;
    assert(!RTEQInit(&eq, NAN));
    assert(!RTEQInit(&eq, 8000));
    for (unsigned i = 0; i < 2; i++) {
        double rate = i == 0 ? 44100.0 : 48000.0;
        double bass = gain(rate, 100.0);
        double middle = gain(rate, 1000.0);
        double treble = gain(rate, 4000.0);
        assert(bass > middle * 1.15 && bass < middle * 1.35);
        assert(treble > middle * 1.05 && treble < middle * 1.20);
        assert(RTEQInit(&eq, rate));
        for (unsigned n = 0; n < 100000; n++) {
            float output = RTEQSample(&eq, 0, n & 1 ? 1.0f : -1.0f);
            assert(isfinite(output) && fabsf(output) <= 1.0f);
        }
        assert(RTEQSample(&eq, 0, NAN) == 0.0f);
        assert(RTEQSample(&eq, 0, INFINITY) == 0.0f);
        RTEQReset(&eq);
        assert(RTEQSample(&eq, 0, 0.0f) == 0.0f);
        assert(RTEQSample(&eq, 2, 0.5f) == 0.5f);
    }
}

int main(void) {
    testAnimation();
    testDSP();
    puts("PASS: animation 0..10/0.1 monotonic acceleration, native zero, DSP response/stereo/headroom/reset");
    return 0;
}

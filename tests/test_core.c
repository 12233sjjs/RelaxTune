#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "DSP.h"
#include "PowerPolicy.h"
#include "Animation.h"

static void testPower(void) {
    assert(RTPowerDecision(true, true, false, false, false) == RTEnablePower);
    assert(RTPowerDecision(true, true, false, true, false) == RTNoChange);
    assert(RTPowerDecision(true, false, false, true, false) == RTNoChange);
    assert(RTPowerDecision(true, false, false, true, true) == RTRestorePower);
    assert(RTPowerDecision(true, true, true, true, true) == RTRestorePower);
    assert(RTPowerDecision(false, true, false, true, true) == RTRestorePower);
    assert(RTPowerDecision(true, true, false, false, true) == RTForgetOwnership);
    assert(RTPowerDecision(true, true, false, true, true) == RTNoChange);
    assert(RTPowerDecision(true, true, true, false, false) == RTNoChange);
    assert(RTPowerDecision(true, false, false, false, false) == RTNoChange);
}

static void testAnimation(void) {
    for (unsigned i = 0; i <= 1000; i++) {
        double value = i / 100.0;
        assert(fabs(RTClampFactor(value) - value) < 1e-12);
        double expected = value == 0.0 ? 0.0 :
            fmax(1.0 / 120.0, round(0.5 * value * 120.0) / 120.0);
        assert(fabs(RTScaledDuration(0.5, value) - expected) < 1e-12);
    }
    assert(RTClampFactor(-1.0) == 0.0);
    assert(RTClampFactor(11.0) == 10.0);
    assert(RTClampFactor(NAN) == 0.9);
    assert(RTClampFactor(INFINITY) == 0.9);
    assert(RTClampFactor(0.914) == 0.91);
    assert(RTClampFactor(0.916) == 0.92);
    assert(RTClampFactor(9.999) == 10.0);
    assert(RTScaledDuration(5.0, 0.0) == 5.0);
    assert(RTScaledDuration(0.05, 0.0) == 0.05);
    assert(RTScaledDuration(0.5, 0.0) == 0.0);
    assert(fabs(RTFrameAlignedDuration(0.091, 120.0) - 11.0 / 120.0) < 1e-12);
    assert(fabs(RTFrameAlignedDuration(0.091, 60.0) - 5.0 / 60.0) < 1e-12);
    assert(fabs(RTScaledDurationForFrameRate(0.5, 0.91, 60.0) - 27.0 / 60.0) < 1e-12);
    assert(RTFrameAlignedDuration(0.0, 120.0) == 0.0);
    assert(RTFrameAlignedDuration(NAN, 120.0) != RTFrameAlignedDuration(NAN, 120.0));
    assert(fabs(RTScaledSpringSpeed(1.0, 0.9) - 0.9) < 1e-12);
    assert(fabs(RTScaledSpringSpeed(0.5, 2.0) - 1.0) < 1e-12);
    assert(RTScaledSpringSpeed(0.0, 0.5) == 0.0);
    assert(isnan(RTScaledSpringSpeed(NAN, 0.5)));
    assert(RTScaledSpringSpeed(-1.0, 2.0) == -1.0);
}

static void testGamePower(void) {
    assert(RTIsPerformanceGame("com.tencent.smoba"));
    assert(!RTIsPerformanceGame(NULL));
    assert(!RTIsPerformanceGame("com.tencent.smoba.other"));
    assert(!RTIsPerformanceGame("com.apple.springboard"));

    // Manual low power: suspend on entry, retain the intent, restore on exit.
    assert(RTGamePowerDecision(true, true, false, true, false) == RTGameDisablePower);
    assert(RTGamePowerDecision(true, true, false, false, true) == RTGameNoChange);
    assert(RTGamePowerDecision(true, false, false, false, true) == RTGameRestorePower);
    assert(RTGamePowerDecision(true, false, false, true, true) == RTGameClearRestore);
    assert(RTGamePowerDecision(true, false, false, true, false) == RTGameNoChange);

    // An originally disabled mode must not be enabled when the game exits.
    assert(RTGamePowerDecision(true, true, false, false, false) == RTGameNoChange);
    assert(RTGamePowerDecision(true, false, false, false, false) == RTGameNoChange);
    assert(RTPowerDecision(true, false, false, true, true) == RTRestorePower);

    // Locking or disabling protection restores a suspended manual mode.
    assert(RTGamePowerDecision(true, true, true, false, true) == RTGameRestorePower);
    assert(RTGamePowerDecision(false, true, false, false, true) == RTGameRestorePower);
    assert(RTGamePowerDecision(false, true, false, true, true) == RTGameClearRestore);
    assert(RTGamePowerDecision(false, true, false, true, false) == RTGameNoChange);
    assert(RTPowerDecision(true, true, false, true, false) == RTNoChange);
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
    testPower();
    testAnimation();
    testGamePower();
    testDSP();
    puts("PASS: power ownership, game suspend/restore, animation 0..10/0.01, spring speed scaling, DSP response/stereo/headroom/reset");
    return 0;
}

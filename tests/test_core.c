#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "DSP.h"
#include "PowerPolicy.h"
#include "Animation.h"

static void testLegacyPower(void) {
    assert(!RTShouldRestoreLegacyPower(false, false, false));
    assert(!RTShouldRestoreLegacyPower(false, true, false));
    assert(!RTShouldRestoreLegacyPower(false, false, true));
    assert(!RTShouldRestoreLegacyPower(false, true, true));
    assert(!RTShouldRestoreLegacyPower(true, false, false));
    assert(RTShouldRestoreLegacyPower(true, true, false));
    assert(!RTShouldRestoreLegacyPower(true, false, true));
    assert(!RTShouldRestoreLegacyPower(true, true, true));
}

static void testAnimation(void) {
    for (unsigned i = 0; i <= 1000; i++) {
        double value = i / 100.0;
        assert(fabs(RTClampFactor(value) - value) < 1e-12);
        assert(fabs(RTScaledDuration(0.5, value) - 0.4 * value) < 1e-12);
        if (value >= 0.13) {
            double uiDuration = RTScaledDuration(0.5, value);
            double sbDuration = 0.5 / RTSmoothPlaybackSpeed(1.0, value);
            assert(fabs(uiDuration - sbDuration) < 1e-12);
        }
    }
    assert(RTClampFactor(-1.0) == 0.0);
    assert(RTClampFactor(11.0) == 10.0);
    assert(RTClampFactor(NAN) == 1.0);
    assert(RTClampFactor(INFINITY) == 1.0);
    assert(RTClampFactor(0.914) == 0.91);
    assert(RTClampFactor(0.916) == 0.92);
    assert(RTClampFactor(9.999) == 10.0);
    assert(RTScaledDuration(5.0, 0.0) == 5.0);
    assert(RTScaledDuration(0.05, 0.0) == 0.05);
    assert(RTScaledDuration(0.5, 0.0) == 0.0);
    assert(fabs(RTScaledDuration(0.3, 1.0) - 0.24) < 1e-12);
    assert(fabs(RTScaledDuration(0.12, 1.0) - 0.096) < 1e-12);
    assert(fabs(RTScaledDuration(1.0, 1.0) - 0.8) < 1e-12);
    assert(fabs(RTSmoothPlaybackSpeed(1.0, 1.0) - 1.25) < 1e-12);
    assert(fabs(RTSmoothPlaybackSpeed(1.0, 2.0) - 0.625) < 1e-12);
    assert(fabs(RTSmoothPlaybackSpeed(1.0, 0.5) - 2.5) < 1e-12);
    assert(RTSmoothPlaybackSpeed(1.0, 0.0) == 10.0);
    assert(RTSmoothPlaybackSpeed(NAN, 1.0) == 1.25);
    assert(RTSmoothPlaybackSpeed(INFINITY, 1.0) == 1.25);
    assert(RTSmoothPlaybackSpeed(100.0, 0.01) == 10.0);
    assert(RTSmoothPlaybackSpeed(0.01, 10.0) == 0.1);
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

    // Locking suspends all game power writes, including restore-on-exit.
    for (unsigned state = 0; state < 16; state++) {
        assert(RTGamePowerDecision(state & 1, state & 2, true, state & 4, state & 8)
               == RTGameNoChange);
    }
    // Lock/unlock without leaving the game must keep the suspended state.
    assert(RTGamePowerDecision(true, true, false, false, true) == RTGameNoChange);
    assert(RTGamePowerDecision(true, true, true, false, true) == RTGameNoChange);
    assert(RTGamePowerDecision(true, true, false, false, true) == RTGameNoChange);
    // Exiting the game or disabling the feature while unlocked still restores it.
    assert(RTGamePowerDecision(false, true, false, false, true) == RTGameRestorePower);
    assert(RTGamePowerDecision(false, true, false, true, true) == RTGameClearRestore);
    assert(RTGamePowerDecision(false, true, false, true, false) == RTGameNoChange);
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
    testLegacyPower();
    testAnimation();
    testGamePower();
    testDSP();
    puts("PASS: legacy power cleanup, locked-state no-op, game suspend/restore, animation 0..10/0.01, spring speed scaling, DSP response/stereo/headroom/reset");
    return 0;
}

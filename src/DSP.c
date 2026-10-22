#include "DSP.h"
#include <math.h>
#include <string.h>

static RTBiquad RTPeak(double rate, double frequency, double gain) {
    double a = pow(10.0, gain / 40.0);
    double omega = 6.283185307179586 * frequency / rate;
    double alpha = sin(omega) / (2.0 * 0.7071067811865476);
    double a0 = 1.0 + alpha / a;
    RTBiquad filter = {
        .b0 = (1.0 + alpha * a) / a0,
        .b1 = -2.0 * cos(omega) / a0,
        .b2 = (1.0 - alpha * a) / a0,
        .a1 = -2.0 * cos(omega) / a0,
        .a2 = (1.0 - alpha / a) / a0
    };
    return filter;
}

bool RTEQInit(RTEqualizer *eq, double sampleRate) {
    memset(eq, 0, sizeof(*eq));
    if (!isfinite(sampleRate) || sampleRate < 16000.0 || sampleRate > 192000.0) return false;
    eq->bass = RTPeak(sampleRate, 100.0, 2.0);
    eq->treble = RTPeak(sampleRate, 4000.0, 1.0);
    return true;
}

void RTEQReset(RTEqualizer *eq) {
    memset(eq->bass.z1, 0, sizeof(eq->bass.z1));
    memset(eq->bass.z2, 0, sizeof(eq->bass.z2));
    memset(eq->treble.z1, 0, sizeof(eq->treble.z1));
    memset(eq->treble.z2, 0, sizeof(eq->treble.z2));
}

static double RTFilter(RTBiquad *filter, unsigned channel, double sample) {
    double output = filter->b0 * sample + filter->z1[channel];
    filter->z1[channel] = filter->b1 * sample - filter->a1 * output + filter->z2[channel];
    filter->z2[channel] = filter->b2 * sample - filter->a2 * output;
    return output;
}

float RTEQSample(RTEqualizer *eq, unsigned channel, float sample) {
    if (channel > 1) return sample;
    if (!isfinite(sample)) {
        eq->bass.z1[channel] = eq->bass.z2[channel] = 0.0;
        eq->treble.z1[channel] = eq->treble.z2[channel] = 0.0;
        return 0.0f;
    }
    double output = RTFilter(&eq->treble, channel, RTFilter(&eq->bass, channel, sample * 0.70));
    return (float)fmax(-1.0, fmin(1.0, output));
}

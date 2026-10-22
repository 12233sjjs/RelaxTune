#ifndef RT_DSP_H
#define RT_DSP_H
#include <stdbool.h>

typedef struct {
    double b0, b1, b2, a1, a2;
    double z1[2], z2[2];
} RTBiquad;

typedef struct {
    RTBiquad bass, treble;
} RTEqualizer;

bool RTEQInit(RTEqualizer *eq, double sampleRate);
void RTEQReset(RTEqualizer *eq);
float RTEQSample(RTEqualizer *eq, unsigned channel, float sample);
#endif

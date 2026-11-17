#ifndef RT_ANIMATION_H
#define RT_ANIMATION_H
#include <math.h>

static inline double RTClampFactor(double factor) {
    if (!isfinite(factor)) return 0.0;
    return round(fmin(10.0, fmax(0.0, factor)) * 10.0) / 10.0;
}

// Acceleration level 0 preserves native timing; level 10 runs at 10x speed.
static inline double RTAnimationSpeed(double level) {
    return 1.0 + 0.9 * RTClampFactor(level);
}

static inline double RTScaledDuration(double duration, double factor) {
    return duration >= 0.12 && duration <= 1.0
        ? duration / RTAnimationSpeed(factor) : duration;
}

static inline double RTScaledDelay(double delay, double factor) {
    return isfinite(delay) && delay >= 0.0
        ? delay / RTAnimationSpeed(factor) : delay;
}

static inline double RTSmoothPlaybackSpeed(double speed, double factor) {
    if (!isfinite(speed) || speed <= 0.0) speed = 1.0;
    double scaled = speed * RTAnimationSpeed(factor);
    return isfinite(scaled) ? scaled : speed;
}
#endif

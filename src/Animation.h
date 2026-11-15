#ifndef RT_ANIMATION_H
#define RT_ANIMATION_H
#include <math.h>

static inline double RTClampFactor(double factor) {
    if (!isfinite(factor)) return 1.0;
    return round(fmin(10.0, fmax(0.0, factor)) * 100.0) / 100.0;
}

static inline double RTScaledDuration(double duration, double factor) {
    return duration >= 0.12 && duration <= 1.0 ? duration * RTClampFactor(factor) : duration;
}

static inline double RTSmoothPlaybackSpeed(double speed, double factor) {
    if (!isfinite(speed) || speed <= 0.0) speed = 1.0;
    factor = RTClampFactor(factor);
    if (factor <= 0.0) return 10.0;
    return fmin(10.0, fmax(0.1, speed / factor));
}
#endif

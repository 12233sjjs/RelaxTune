#ifndef RT_ANIMATION_H
#define RT_ANIMATION_H
#include <math.h>

static inline double RTClampFactor(double factor) {
    if (!isfinite(factor)) return 0.9;
    return round(fmin(10.0, fmax(0.0, factor)) * 100.0) / 100.0;
}

static inline double RTScaledDuration(double duration, double factor) {
    return duration >= 0.12 && duration <= 1.0 ? duration * RTClampFactor(factor) : duration;
}
#endif

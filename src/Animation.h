#ifndef RT_ANIMATION_H
#define RT_ANIMATION_H
#include <math.h>

static inline double RTClampFactor(double factor) {
    if (!isfinite(factor)) return 0.9;
    return round(fmin(10.0, fmax(0.0, factor)) * 100.0) / 100.0;
}

static inline double RTScaledDurationForFrameRate(double duration, double factor, double fps) {
    if (duration < 0.12 || duration > 1.0) return duration;
    double value = RTClampFactor(factor);
    if (value == 0.0) return 0.0;
    if (!isfinite(fps) || fps <= 0.0) return duration * value;
    double frame = 1.0 / fps;
    return fmax(frame, round(duration * value / frame) * frame);
}

static inline double RTScaledDuration(double duration, double factor) {
    return RTScaledDurationForFrameRate(duration, factor, 120.0);
}

static inline double RTFrameAlignedDuration(double duration, double fps) {
    if (!isfinite(duration) || duration <= 0.0 || !isfinite(fps) || fps <= 0.0) return duration;
    double frame = 1.0 / fps;
    return fmax(frame, round(duration / frame) * frame);
}

static inline double RTScaledSpringSpeed(double speed, double factor) {
    if (!isfinite(speed) || speed <= 0.0) return speed;
    return fmax(0.01, speed * RTClampFactor(factor));
}
#endif

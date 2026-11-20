#ifndef RT_ANIMATION_SETTINGS_H
#define RT_ANIMATION_SETTINGS_H
#import <Foundation/Foundation.h>
#import <objc/message.h>
#include "Animation.h"
#include <string.h>

static inline id RTCreateAnimationSettings(Class factoryClass, double duration, double delay,
                                           double speed, double factor, id timing) {
    SEL factory = NSSelectorFromString(@"settingsWithDuration:delay:timingFunction:");
    NSMethodSignature *signature = [factoryClass methodSignatureForSelector:factory];
    if (signature.numberOfArguments != 5 || signature.methodReturnType[0] != '@' ||
        strcmp([signature getArgumentTypeAtIndex:2], @encode(double)) != 0 ||
        strcmp([signature getArgumentTypeAtIndex:3], @encode(double)) != 0 ||
        [signature getArgumentTypeAtIndex:4][0] != '@' ||
        !isfinite(duration) || duration < 0.12 || duration > 1.0 ||
        !isfinite(delay) || delay < 0.0) return nil;
    // BSAnimationSettings is immutable; its speed setter is not available.
    double baseSpeed = isfinite(speed) && speed > 0.0 ? speed : 1.0;
    double accelerationSpeed = RTAnimationSpeed(factor);
    double scaledDuration = duration / (baseSpeed * accelerationSpeed);
    double scaledDelay = isfinite(delay) && delay >= 0.0
        ? delay / accelerationSpeed : delay;
    return ((id (*)(id, SEL, double, double, id))objc_msgSend)(
        factoryClass, factory, scaledDuration, scaledDelay, timing);
}
#endif

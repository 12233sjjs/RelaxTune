#include "PowerPolicy.h"

RTPowerAction RTPowerDecision(bool enabled, bool locked, bool charging,
                              bool currentLowPower, bool ownsLowPower) {
    if (ownsLowPower && !currentLowPower) return RTForgetOwnership;
    bool wanted = enabled && locked && !charging;
    if (ownsLowPower && !wanted) return RTRestorePower;
    if (wanted && !currentLowPower) return RTEnablePower;
    return RTNoChange;
}

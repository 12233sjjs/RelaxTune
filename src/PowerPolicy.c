#include "PowerPolicy.h"
#include <string.h>

RTPowerAction RTPowerDecision(bool enabled, bool locked, bool charging,
                              bool currentLowPower, bool ownsLowPower) {
    if (ownsLowPower && !currentLowPower) return RTForgetOwnership;
    bool wanted = enabled && locked && !charging;
    if (ownsLowPower && !wanted) return RTRestorePower;
    if (wanted && !currentLowPower) return RTEnablePower;
    return RTNoChange;
}

RTGamePowerAction RTGamePowerDecision(bool enabled, bool frontmostGame, bool locked,
                                      bool currentLowPower, bool restoreLowPower) {
    if (enabled && frontmostGame && !locked)
        return currentLowPower ? RTGameDisablePower : RTGameNoChange;
    if (restoreLowPower)
        return currentLowPower ? RTGameClearRestore : RTGameRestorePower;
    return RTGameNoChange;
}

bool RTIsPerformanceGame(const char *bundle) {
    return bundle && strcmp(bundle, "com.tencent.smoba") == 0;
}

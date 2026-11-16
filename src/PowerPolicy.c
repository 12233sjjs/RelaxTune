#include "PowerPolicy.h"
#include <string.h>

bool RTShouldRestoreLegacyPower(bool ownedLowPower, bool currentLowPower,
                                bool restoreManualLowPower) {
    return ownedLowPower && currentLowPower && !restoreManualLowPower;
}

RTGamePowerAction RTGamePowerDecision(bool enabled, bool frontmostGame, bool locked,
                                      bool currentLowPower, bool restoreLowPower) {
    if (locked) return RTGameNoChange;
    if (enabled && frontmostGame)
        return currentLowPower ? RTGameDisablePower : RTGameNoChange;
    if (restoreLowPower)
        return currentLowPower ? RTGameClearRestore : RTGameRestorePower;
    return RTGameNoChange;
}

bool RTIsPerformanceGame(const char *bundle) {
    return bundle && strcmp(bundle, "com.tencent.smoba") == 0;
}

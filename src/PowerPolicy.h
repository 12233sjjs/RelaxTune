#ifndef RT_POWER_POLICY_H
#define RT_POWER_POLICY_H
#include <stdbool.h>
bool RTShouldRestoreLegacyPower(bool ownedLowPower, bool currentLowPower,
                                bool restoreManualLowPower);
typedef enum {
    RTGameNoChange, RTGameDisablePower, RTGameRestorePower, RTGameClearRestore
} RTGamePowerAction;
RTGamePowerAction RTGamePowerDecision(bool enabled, bool frontmostGame, bool locked,
                                      bool currentLowPower, bool restoreLowPower);
bool RTIsPerformanceGame(const char *bundle);
#endif

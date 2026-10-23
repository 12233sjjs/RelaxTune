#ifndef RT_POWER_POLICY_H
#define RT_POWER_POLICY_H
#include <stdbool.h>
typedef enum { RTNoChange, RTEnablePower, RTRestorePower, RTForgetOwnership } RTPowerAction;
RTPowerAction RTPowerDecision(bool enabled, bool locked, bool charging,
                              bool currentLowPower, bool ownsLowPower);
typedef enum {
    RTGameNoChange, RTGameDisablePower, RTGameRestorePower, RTGameClearRestore
} RTGamePowerAction;
RTGamePowerAction RTGamePowerDecision(bool enabled, bool frontmostGame, bool locked,
                                      bool currentLowPower, bool restoreLowPower);
bool RTIsPerformanceGame(const char *bundle);
#endif

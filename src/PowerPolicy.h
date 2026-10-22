#ifndef RT_POWER_POLICY_H
#define RT_POWER_POLICY_H
#include <stdbool.h>
typedef enum { RTNoChange, RTEnablePower, RTRestorePower, RTForgetOwnership } RTPowerAction;
RTPowerAction RTPowerDecision(bool enabled, bool locked, bool charging,
                              bool currentLowPower, bool ownsLowPower);
#endif

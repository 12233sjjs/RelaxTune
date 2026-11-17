#import <Foundation/Foundation.h>
#include <stdatomic.h>

extern atomic_bool RTEnabled;
extern atomic_bool RTAnimations;
extern atomic_bool RTWakeAnimations;
extern atomic_bool RTUnlockAnimations;
extern atomic_bool RTAnimationExcluded;
extern atomic_bool RTNetwork;
extern atomic_bool RTTCPNoDelay;
extern atomic_bool RTHighRefresh;
extern atomic_bool RTAudio;
extern atomic_bool RTZombieReap;
extern _Atomic(double) RTAnimationFactor;
extern _Atomic(double) RTWakeAcceleration;
extern _Atomic(double) RTUnlockAcceleration;
void RTLoadSettings(void);
BOOL RTIsExcludedApp(NSString *identifier, NSDictionary *configuration);
BOOL RTShouldLoadAppHooks(void);
BOOL RTShouldLoadMainTweak(NSString *bundleIdentifier, BOOL isApplicationBundle);
BOOL RTIsAnimationExcluded(NSString *identifier, NSArray *excludedIdentifiers);
void RTRefreshRateDidChange(void);
void RTInstallAnimationHooks(BOOL springboard);

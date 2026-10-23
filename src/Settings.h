#import <Foundation/Foundation.h>
#include <stdatomic.h>

extern atomic_bool RTEnabled;
extern atomic_bool RTAnimations;
extern atomic_bool RTNetwork;
extern atomic_bool RTLowPower;
extern atomic_bool RTGamePerformance;
extern atomic_bool RTHighRefresh;
extern atomic_bool RTAudio;
extern _Atomic(double) RTAnimationFactor;
void RTLoadSettings(void);
BOOL RTIsApp(void);
void RTRefreshRateDidChange(void);

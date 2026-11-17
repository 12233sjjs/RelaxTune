#import <UIKit/UIKit.h>
#import <notify.h>
#import <sys/wait.h>
#import <dispatch/dispatch.h>
#import "Settings.h"
#include <stdlib.h>

static BOOL RTSpringBoard;
static dispatch_source_t RTZombieTimer;
static int RTRespringToken = -1;
static void RTUpdateZombieReaping(void);

static void RTSettingsChanged(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        RTLoadSettings();
        if (RTSpringBoard) RTRefreshRateDidChange();
        RTUpdateZombieReaping();
    });
}

static void RTUpdateZombieReaping(void) {
    if (!RTSpringBoard) return;
    BOOL enabled = atomic_load(&RTEnabled) && atomic_load(&RTZombieReap);
    if (enabled && !RTZombieTimer) {
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
        RTZombieTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(RTZombieTimer,
            dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
            5 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(RTZombieTimer, ^{
            int status;
            while (waitpid(-1, &status, WNOHANG) > 0) {}
        });
        dispatch_resume(RTZombieTimer);
    } else if (!enabled && RTZombieTimer) {
        dispatch_source_cancel(RTZombieTimer);
        RTZombieTimer = nil;
    }
}

%group RTApps

%hook NSURLSessionConfiguration
+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    if (atomic_load(&RTEnabled) && atomic_load(&RTNetwork)) config.waitsForConnectivity = YES;
    return config;
}
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    if (atomic_load(&RTEnabled) && atomic_load(&RTNetwork)) config.waitsForConnectivity = YES;
    return config;
}
%end
%end


%ctor {
    @autoreleasepool {
        NSBundle *mainBundle = NSBundle.mainBundle;
        NSString *bundleIdentifier = mainBundle.bundleIdentifier;
        BOOL isApplicationBundle = [mainBundle.bundlePath.pathExtension isEqualToString:@"app"];
        if (!RTShouldLoadMainTweak(bundleIdentifier, isApplicationBundle)) return;
        RTSpringBoard = [bundleIdentifier isEqualToString:@"com.apple.springboard"];
        RTLoadSettings();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            RTSettingsChanged, CFSTR("com.12233sjjs.relaxtune.changed"), NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        RTInstallAnimationHooks(RTSpringBoard);
        if (RTSpringBoard) {
            notify_register_dispatch("com.12233sjjs.relaxtune.respring", &RTRespringToken,
                                      dispatch_get_main_queue(), ^(int token) { exit(0); });
            RTUpdateZombieReaping();
        } else {
            %init(RTApps);
        }
    }
}

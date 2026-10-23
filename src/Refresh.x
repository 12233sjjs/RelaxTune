#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "Settings.h"

@interface RTFrameRequest : NSObject
@property(nonatomic) CAFrameRateRange range;
@property(nonatomic) NSInteger frames;
@property(nonatomic) BOOL usesRange;
@end
@implementation RTFrameRequest
@end

static NSHashTable<CADisplayLink *> *RTDisplayLinks;
static char RTFrameRequestKey;
static __thread BOOL RTApplyingRefresh;

static BOOL RTPrefer120(void) {
    return atomic_load(&RTEnabled) && atomic_load(&RTHighRefresh) &&
           UIScreen.mainScreen.maximumFramesPerSecond >= 120 &&
           !NSProcessInfo.processInfo.lowPowerModeEnabled;
}

// Keep the caller's request so disabling the option restores the original pacing.
static RTFrameRequest *RTTrackDisplayLink(CADisplayLink *link) {
    RTFrameRequest *request = objc_getAssociatedObject(link, &RTFrameRequestKey);
    if (!request) {
        request = [RTFrameRequest new];
        request.range = link.preferredFrameRateRange;
        request.usesRange = YES;
        objc_setAssociatedObject(link, &RTFrameRequestKey, request, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [RTDisplayLinks addObject:link];
    }
    return request;
}

static void RTApplyDisplayRequest(CADisplayLink *link, RTFrameRequest *request) {
    RTApplyingRefresh = YES;
    @try {
        if (RTPrefer120()) {
            link.preferredFrameRateRange = CAFrameRateRangeMake(120, 120, 120);
        } else if (request.usesRange) {
            link.preferredFrameRateRange = request.range;
        } else {
            link.preferredFramesPerSecond = request.frames;
        }
    } @finally {
        RTApplyingRefresh = NO;
    }
}

void RTRefreshRateDidChange(void) {
    if (!RTDisplayLinks) return;
    @synchronized (RTDisplayLinks) {
        for (CADisplayLink *link in RTDisplayLinks.allObjects)
            RTApplyDisplayRequest(link, RTTrackDisplayLink(link));
    }
}

%group RTRefreshHooks
%hook CADisplayLink
- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    @synchronized (RTDisplayLinks) {
        RTApplyDisplayRequest(self, RTTrackDisplayLink(self));
    }
    %orig;
}
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (RTApplyingRefresh) { %orig(range); return; }
    @synchronized (RTDisplayLinks) {
        RTFrameRequest *request = RTTrackDisplayLink(self);
        request.range = range;
        request.usesRange = YES;
        RTApplyDisplayRequest(self, request);
    }
}
- (void)setPreferredFramesPerSecond:(NSInteger)frames {
    if (RTApplyingRefresh) { %orig(frames); return; }
    @synchronized (RTDisplayLinks) {
        RTFrameRequest *request = RTTrackDisplayLink(self);
        request.frames = frames;
        request.usesRange = NO;
        RTApplyDisplayRequest(self, request);
    }
}
- (void)invalidate {
    @synchronized (RTDisplayLinks) {
        [RTDisplayLinks removeObject:self];
    }
    %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        RTLoadSettings();
        RTDisplayLinks = [NSHashTable weakObjectsHashTable];
        [NSNotificationCenter.defaultCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                RTRefreshRateDidChange();
            }];
        %init(RTRefreshHooks);
    }
}

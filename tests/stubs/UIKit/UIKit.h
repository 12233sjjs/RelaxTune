#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
typedef NS_ENUM(NSInteger, UIViewAnimationCurve) {
    UIViewAnimationCurveEaseInOut, UIViewAnimationCurveEaseIn, UIViewAnimationCurveEaseOut, UIViewAnimationCurveLinear
};
typedef NS_ENUM(NSInteger, UIViewAnimatingPosition) {
    UIViewAnimatingPositionEnd, UIViewAnimatingPositionStart, UIViewAnimatingPositionCurrent
};
typedef NSUInteger UIViewAnimationOptions;
enum {
    UIViewAnimationOptionBeginFromCurrentState = 1 << 2,
    UIViewAnimationOptionAllowUserInteraction = 1 << 1,
    UIViewAnimationOptionCurveEaseIn = 1 << 16,
    UIViewAnimationOptionCurveEaseOut = 2 << 16,
    UIViewAnimationOptionCurveLinear = 3 << 16
};
BOOL UIAccessibilityIsReduceMotionEnabled(void);
@protocol UITimingCurveProvider <NSObject>
@end
@interface UICubicTimingParameters : NSObject <UITimingCurveProvider>
@property UIViewAnimationCurve curve;
- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)curve;
@end
@interface UIScreen : NSObject
+ (instancetype)mainScreen;
@property NSInteger maximumFramesPerSecond;
@end
@interface UIView : NSObject
+ (void)animateWithDuration:(double)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(double)duration animations:(void (^)(void))animations completion:(void (^)(BOOL))completion;
+ (void)animateWithDuration:(double)duration delay:(double)delay options:(UIViewAnimationOptions)options
                animations:(void (^)(void))animations completion:(void (^)(BOOL))completion;
+ (void)animateWithDuration:(double)duration delay:(double)delay usingSpringWithDamping:(CGFloat)damping
     initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options
                animations:(void (^)(void))animations completion:(void (^)(BOOL))completion;
+ (void)_animateUsingSpringWithTension:(double)tension friction:(double)friction interactive:(BOOL)interactive
                           animations:(void (^)(void))animations completion:(void (^)(BOOL))completion;
@end
@interface UIViewPropertyAnimator : NSObject
@property double duration;
@property id<UITimingCurveProvider> timing;
- (instancetype)initWithDuration:(double)duration curve:(UIViewAnimationCurve)curve animations:(void (^)(void))animations;
- (instancetype)initWithDuration:(double)duration timingParameters:(id<UITimingCurveProvider>)timing;
- (instancetype)initWithDuration:(double)duration controlPoint1:(CGPoint)p1 controlPoint2:(CGPoint)p2 animations:(void (^)(void))animations;
- (instancetype)initWithDuration:(double)duration dampingRatio:(CGFloat)damping animations:(void (^)(void))animations;
+ (instancetype)runningPropertyAnimatorWithDuration:(double)duration delay:(double)delay options:(UIViewAnimationOptions)options
                                        animations:(void (^)(void))animations completion:(void (^)(UIViewAnimatingPosition))completion;
@end

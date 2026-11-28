#ifndef RT_TIME_CAPSULE_UIKIT_STUB_H
#define RT_TIME_CAPSULE_UIKIT_STUB_H
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
/* Fixture-only names: never export UIKit class names into a macOS process. */
#define UIView RTTimeCapsuleFixture_UIView
#define UIWindow RTTimeCapsuleFixture_UIWindow
#define UILabel RTTimeCapsuleFixture_UILabel
#define UIFont RTTimeCapsuleFixture_UIFont
#define UIApplication RTTimeCapsuleFixture_UIApplication

typedef NS_ENUM(NSInteger, UIApplicationState) {
    UIApplicationStateActive, UIApplicationStateInactive, UIApplicationStateBackground
};
@class UIWindow;
@interface UIView : NSObject
@property(nonatomic, weak) UIView *superview;
@property(nonatomic, weak) UIWindow *window;
@property(nonatomic) BOOL hidden;
@property(nonatomic) CGFloat alpha;
@property(nonatomic) CGRect bounds;
@property(nonatomic) CGRect frame;
@end
@interface UIWindow : UIView
@end
@interface UIFont : NSObject
@property(nonatomic) double characterWidth;
@property(nonatomic) double lineHeight;
@end
@interface UILabel : UIView
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSAttributedString *attributedText;
@property(nonatomic, strong) UIFont *font;
@property(nonatomic) NSInteger numberOfLines;
@property(nonatomic) BOOL adjustsFontSizeToFitWidth;
@property(nonatomic) CGFloat minimumScaleFactor;
@end
@interface UIApplication : NSObject
+ (instancetype)sharedApplication;
@property(nonatomic) UIApplicationState applicationState;
@end
FOUNDATION_EXPORT NSString *const NSFontAttributeName;
@interface NSString (RTTimeCapsuleFixtureSizing)
- (CGSize)sizeWithAttributes:(NSDictionary *)attributes;
@end
#endif

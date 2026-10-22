#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>
#include <math.h>
#include "Animation.h"

static CFStringRef const RTDomain = CFSTR("com.12233sjjs.relaxtune");

static id RTReadPreference(NSString *key) {
    CFPreferencesAppSynchronize(RTDomain);
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, RTDomain));
}

static void RTWritePreference(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, RTDomain);
    CFPreferencesAppSynchronize(RTDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.12233sjjs.relaxtune.changed"), NULL, NULL, YES);
}

@interface RTFactorCell : PSTableCell
@property(nonatomic, strong) UIStepper *factorStepper;
@end

@implementation RTFactorCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier];
    if (self) {
        _factorStepper = [[UIStepper alloc] init];
        _factorStepper.minimumValue = 0.0;
        _factorStepper.maximumValue = 10.0;
        _factorStepper.stepValue = 0.01;
        _factorStepper.wraps = NO;
        _factorStepper.accessibilityLabel = @"Animation duration multiplier";
        id saved = RTReadPreference(@"AnimationFactor");
        double factor = [saved isKindOfClass:NSNumber.class] ? [saved doubleValue] : 0.9;
        _factorStepper.value = RTClampFactor(factor);
        [_factorStepper addTarget:self action:@selector(factorChanged:) forControlEvents:UIControlEventValueChanged];
        self.accessoryView = _factorStepper;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self updateLabel];
    }
    return self;
}
- (void)updateLabel {
    self.textLabel.text = @"动画时长比例";
    self.detailTextLabel.text = [NSString stringWithFormat:@"%.2f ×", self.factorStepper.value];
}
- (void)factorChanged:(UIStepper *)stepper {
    stepper.value = RTClampFactor(stepper.value);
    RTWritePreference(@"AnimationFactor", @(stepper.value));
    [self updateLabel];
}
@end

@interface RTRootController : PSListController
@end

@implementation RTRootController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return RTReadPreference([specifier propertyForKey:@"key"]) ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    RTWritePreference([specifier propertyForKey:@"key"], value);
}
@end

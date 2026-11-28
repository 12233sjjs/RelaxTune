#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>
#include <math.h>
#include "Animation.h"

static CFStringRef const RTDomain = CFSTR("com.12233sjjs.relaxtune");

static BOOL RTIsPSListControllerSubclass(Class candidate) {
    Class baseClass = PSListController.class;
    for (Class currentClass = candidate; currentClass; currentClass = class_getSuperclass(currentClass)) {
        if (currentClass == baseClass) return YES;
    }
    return NO;
}

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
@property(nonatomic, copy) NSString *preferenceKey;
@property(nonatomic, copy) NSString *settingTitle;
@end

@implementation RTFactorCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier];
    if (self) {
        _factorStepper = [[UIStepper alloc] init];
        _factorStepper.minimumValue = 0.0;
        _factorStepper.maximumValue = 10.0;
        _factorStepper.stepValue = 0.1;
        _factorStepper.wraps = NO;
        _preferenceKey = [specifier propertyForKey:@"key"];
        _settingTitle = [specifier propertyForKey:@"label"];
        _factorStepper.accessibilityLabel = _settingTitle;
        id saved = RTReadPreference(_preferenceKey);
        double factor = [saved isKindOfClass:NSNumber.class] ? [saved doubleValue] : 0.0;
        _factorStepper.value = RTClampFactor(factor);
        [_factorStepper addTarget:self action:@selector(factorChanged:) forControlEvents:UIControlEventValueChanged];
        self.accessoryView = _factorStepper;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self updateLabel];
    }
    return self;
}
- (void)updateLabel {
    self.textLabel.text = self.settingTitle;
    self.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", self.factorStepper.value];
}
- (void)factorChanged:(UIStepper *)stepper {
    stepper.value = RTClampFactor(stepper.value);
    RTWritePreference(self.preferenceKey, @(stepper.value));
    [self updateLabel];
}
@end

@interface RTRootController : PSListController
@end

@implementation RTRootController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"注销" style:UIBarButtonItemStylePlain
                                       target:self action:@selector(rtRespring)];
}
- (void)rtRespring {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"注销 SpringBoard"
                                            message:@"保存设置并重新加载桌面？"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"注销" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        notify_post("com.12233sjjs.relaxtune.respring");
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
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
- (void)rtEditAnimationExclusions:(PSSpecifier *)specifier {
    id saved = RTReadPreference(@"AnimationExcludedApps");
    NSArray<NSString *> *identifiers = [saved isKindOfClass:NSArray.class] ? saved : @[];
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"动画屏蔽名单"
        message:identifiers.count ? [identifiers componentsJoinedByString:@"\n"] : @"名单为空"
        preferredStyle:UIAlertControllerStyleAlert];
    [menu addAction:[UIAlertAction actionWithTitle:@"添加 Bundle ID" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIAlertController *input = [UIAlertController alertControllerWithTitle:@"添加 Bundle ID"
            message:nil preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"com.example.app";
            field.autocapitalizationType = UITextAutocapitalizationTypeNone;
            field.autocorrectionType = UITextAutocorrectionTypeNo;
        }];
        [input addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *confirm) {
            NSString *identifier = [input.textFields.firstObject.text stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
                @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"] invertedSet];
            BOOL duplicate = [identifiers indexOfObjectPassingTest:^BOOL(NSString *entry, NSUInteger index, BOOL *stop) {
                return [entry caseInsensitiveCompare:identifier] == NSOrderedSame;
            }] != NSNotFound;
            if (!identifier.length || [identifier rangeOfCharacterFromSet:invalid].location != NSNotFound || duplicate) return;
            RTWritePreference(@"AnimationExcludedApps", [identifiers arrayByAddingObject:identifier]);
        }]];
        [self presentViewController:input animated:YES completion:nil];
    }]];
    if (identifiers.count) {
        [menu addAction:[UIAlertAction actionWithTitle:@"删除名单项" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            UIAlertController *remove = [UIAlertController alertControllerWithTitle:@"选择要删除的 Bundle ID"
                message:nil preferredStyle:UIAlertControllerStyleAlert];
            for (NSString *identifier in identifiers) {
                [remove addAction:[UIAlertAction actionWithTitle:identifier style:UIAlertActionStyleDestructive handler:^(UIAlertAction *selected) {
                    NSMutableArray *updated = [identifiers mutableCopy];
                    [updated removeObject:identifier];
                    RTWritePreference(@"AnimationExcludedApps", updated);
                }]];
            }
            [remove addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:remove animated:YES completion:nil];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)rtShowTimeCapsuleUnavailable {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"快捷时间胶囊不可用"
        message:@"请确认 DateInfo 1.3.10 或更新版本已安装，并重新载入设置。"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)rtOpenTimeCapsule:(PSSpecifier *)specifier {
    (void)specifier;
    NSBundle *relaxTuneBundle = [NSBundle bundleForClass:[self class]];
    NSURL *preferenceBundlesURL = [relaxTuneBundle.bundleURL URLByDeletingLastPathComponent];
    NSURL *capsuleURL = [preferenceBundlesURL URLByAppendingPathComponent:@"DateInfoPrefs.bundle"
                                                              isDirectory:YES];
    NSBundle *capsuleBundle = [NSBundle bundleWithURL:capsuleURL];
    if (!capsuleBundle) {
        [self rtShowTimeCapsuleUnavailable];
        return;
    }

    NSError *loadError = nil;
    if (![capsuleBundle isLoaded] && ![capsuleBundle loadAndReturnError:&loadError]) {
        [self rtShowTimeCapsuleUnavailable];
        return;
    }

    Class capsuleControllerClass = NSClassFromString(@"DIRootListController");
    if (!RTIsPSListControllerSubclass(capsuleControllerClass) || !self.navigationController) {
        [self rtShowTimeCapsuleUnavailable];
        return;
    }
    // A same-named class from another loaded preference bundle is not the donor.
    NSBundle *controllerBundle = [NSBundle bundleForClass:capsuleControllerClass];
    if (![controllerBundle.bundleURL.URLByStandardizingPath
            isEqual:capsuleBundle.bundleURL.URLByStandardizingPath]) {
        [self rtShowTimeCapsuleUnavailable];
        return;
    }
    UIViewController *capsuleController = [[capsuleControllerClass alloc] init];
    if (![capsuleController isKindOfClass:UIViewController.class]) {
        [self rtShowTimeCapsuleUnavailable];
        return;
    }
    [self.navigationController pushViewController:capsuleController animated:YES];
}
@end

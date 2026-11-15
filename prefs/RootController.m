#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>
#import <notify.h>
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
        double factor = [saved isKindOfClass:NSNumber.class] ? [saved doubleValue] : 1.0;
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

@interface RTAnimationExclusionController : UITableViewController
@property(nonatomic, copy) NSArray<NSString *> *identifiers;
@end

@implementation RTAnimationExclusionController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"动画屏蔽名单";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    id saved = RTReadPreference(@"AnimationExcludedApps");
    self.identifiers = [saved isKindOfClass:NSArray.class] ? saved : @[];
    self.tableView.allowsSelectionDuringEditing = NO;
    self.tableView.tableFooterView = [UIView new];
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.prompt = @"按 Bundle ID 屏蔽动画调整";
    self.navigationItem.rightBarButtonItems = @[
        self.editButtonItem,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
            target:self action:@selector(addIdentifier)]
    ];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.identifiers.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const reuse = @"AnimationExclusion";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    cell.textLabel.text = self.identifiers[indexPath.row];
    cell.detailTextLabel.text = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
- (void)saveIdentifiers {
    RTWritePreference(@"AnimationExcludedApps", self.identifiers);
}
- (void)addIdentifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加应用 Bundle ID"
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"例如 com.example.app";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *identifier = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
            @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"] invertedSet];
        BOOL duplicate = [self.identifiers indexOfObjectPassingTest:^BOOL(NSString *entry, NSUInteger index, BOOL *stop) {
            return [entry caseInsensitiveCompare:identifier] == NSOrderedSame;
        }] != NSNotFound;
        if (!identifier.length || [identifier rangeOfCharacterFromSet:invalid].location != NSNotFound || duplicate) return;
        self.identifiers = [self.identifiers arrayByAddingObject:identifier];
        [self saveIdentifiers];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *updated = [self.identifiers mutableCopy];
    [updated removeObjectAtIndex:indexPath.row];
    self.identifiers = updated;
    [self saveIdentifiers];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
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
@end

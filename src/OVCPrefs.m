#import "OVCPrefs.h"
#import "OVCTheme.h"

NSNotificationName const OVCPrefsDidChangeNotification = @"OVCPrefsDidChangeNotification";

static NSString * const kMonitoringEnabled = @"monitoringEnabled";
static NSString * const kAutoCopy = @"autoCopy";
static NSString * const kShowPanel = @"showPanel";
static NSString * const kRequiresKeyword = @"requiresKeyword";
static NSString * const kLaunchAtLogin = @"launchAtLogin";
static NSString * const kDockIcon = @"dockIcon";
static NSString * const kOnboarding = @"hasCompletedOnboarding";
static NSString * const kPanelDuration = @"panelDuration";
static NSString * const kPanelTheme = @"panelTheme";
static NSString * const kPanelSize = @"panelSize";
static NSString * const kPanelTransparency = @"panelTransparency";
static NSString * const kMinDigits = @"minDigits";
static NSString * const kAppLanguage = @"appLanguage";
static NSString * const kMaxDigits = @"maxDigits";

@implementation OVCPrefs

+ (instancetype)shared {
    static OVCPrefs *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OVCPrefs alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            kMonitoringEnabled: @YES,
            kAutoCopy: @YES,
            kShowPanel: @YES,
            kRequiresKeyword: @YES,
            kLaunchAtLogin: @NO,
            kDockIcon: @NO,
            kOnboarding: @NO,
            kPanelDuration: @8.0,
            kPanelTheme: @0,
            kPanelSize: @1,
            kPanelTransparency: @0.12,
            kMinDigits: @4,
            kMaxDigits: @8,
            kAppLanguage: @0,
        }];
    }
    return self;
}

- (NSUserDefaults *)defaults { return [NSUserDefaults standardUserDefaults]; }

- (void)notifyChanged {
    if ([NSThread isMainThread]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:OVCPrefsDidChangeNotification object:self];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:OVCPrefsDidChangeNotification object:self];
        });
    }
}

- (BOOL)monitoringEnabled { return [[self defaults] boolForKey:kMonitoringEnabled]; }
- (void)setMonitoringEnabled:(BOOL)value {
    [[self defaults] setBool:value forKey:kMonitoringEnabled];
    [self notifyChanged];
}

- (BOOL)autoCopy { return [[self defaults] boolForKey:kAutoCopy]; }
- (void)setAutoCopy:(BOOL)value {
    [[self defaults] setBool:value forKey:kAutoCopy];
    [self notifyChanged];
}

- (BOOL)showPanel { return [[self defaults] boolForKey:kShowPanel]; }
- (void)setShowPanel:(BOOL)value {
    [[self defaults] setBool:value forKey:kShowPanel];
    [self notifyChanged];
}

- (BOOL)requiresKeyword { return [[self defaults] boolForKey:kRequiresKeyword]; }
- (void)setRequiresKeyword:(BOOL)value {
    [[self defaults] setBool:value forKey:kRequiresKeyword];
    [self notifyChanged];
}

- (BOOL)launchAtLogin { return [[self defaults] boolForKey:kLaunchAtLogin]; }
- (void)setLaunchAtLogin:(BOOL)value {
    [[self defaults] setBool:value forKey:kLaunchAtLogin];
    [self notifyChanged];
}

- (BOOL)dockIcon { return [[self defaults] boolForKey:kDockIcon]; }
- (void)setDockIcon:(BOOL)value {
    [[self defaults] setBool:value forKey:kDockIcon];
    [self notifyChanged];
}

- (NSInteger)appLanguage {
    NSInteger value = [[self defaults] integerForKey:kAppLanguage];
    return MIN(OVCLanguageEnglish, MAX(OVCLanguageSystem, value));
}
- (void)setAppLanguage:(NSInteger)value {
    NSInteger clamped = MIN(OVCLanguageEnglish, MAX(OVCLanguageSystem, value));
    [[self defaults] setInteger:clamped forKey:kAppLanguage];
    [self notifyChanged];
    if ([NSThread isMainThread]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:OVCLanguageDidChangeNotification object:self];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:OVCLanguageDidChangeNotification object:self];
        });
    }
}

- (BOOL)hasCompletedOnboarding { return [[self defaults] boolForKey:kOnboarding]; }
- (void)setHasCompletedOnboarding:(BOOL)value {
    [[self defaults] setBool:value forKey:kOnboarding];
    [self notifyChanged];
}

- (double)panelDuration {
    double value = [[self defaults] doubleForKey:kPanelDuration];
    if (value < 1.0) { value = 1.0; }
    if (value > 20.0) { value = 20.0; }
    return value;
}
- (void)setPanelDuration:(double)value {
    double clamped = MIN(20.0, MAX(1.0, value));
    [[self defaults] setDouble:clamped forKey:kPanelDuration];
    [self notifyChanged];
}

- (NSInteger)panelTheme {
    NSInteger value = [[self defaults] integerForKey:kPanelTheme];
    return MIN(OVCPanelThemeCount - 1, MAX(0, value));
}
- (void)setPanelTheme:(NSInteger)value {
    [[self defaults] setInteger:MIN(OVCPanelThemeCount - 1, MAX(0, value)) forKey:kPanelTheme];
    [self notifyChanged];
}

- (NSInteger)panelSize {
    NSInteger value = [[self defaults] integerForKey:kPanelSize];
    return MIN(2, MAX(0, value));
}
- (void)setPanelSize:(NSInteger)value {
    [[self defaults] setInteger:MIN(2, MAX(0, value)) forKey:kPanelSize];
    [self notifyChanged];
}

- (double)panelTransparency {
    double value = [[self defaults] doubleForKey:kPanelTransparency];
    return MIN(1.0, MAX(0.0, value));
}
- (void)setPanelTransparency:(double)value {
    [[self defaults] setDouble:MIN(1.0, MAX(0.0, value)) forKey:kPanelTransparency];
    [self notifyChanged];
}

- (NSInteger)minDigits {
    NSInteger value = [[self defaults] integerForKey:kMinDigits];
    if (value < 4) { value = 4; }
    if (value > 6) { value = 6; }
    return value;
}
- (void)setMinDigits:(NSInteger)value {
    NSInteger clamped = MIN(6, MAX(4, value));
    [[self defaults] setInteger:clamped forKey:kMinDigits];
    if ([self maxDigits] < clamped) { [self setMaxDigits:clamped]; }
    [self notifyChanged];
}

- (NSInteger)maxDigits {
    NSInteger value = [[self defaults] integerForKey:kMaxDigits];
    if (value < 6) { value = 6; }
    if (value > 8) { value = 8; }
    return value;
}
- (void)setMaxDigits:(NSInteger)value {
    NSInteger clamped = MIN(8, MAX(6, value));
    [[self defaults] setInteger:clamped forKey:kMaxDigits];
    if ([self minDigits] > clamped) { [self setMinDigits:clamped]; }
    [self notifyChanged];
}

- (void)synchronize {
    [[self defaults] synchronize];
}

@end

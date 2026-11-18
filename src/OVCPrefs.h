#import <Foundation/Foundation.h>
#import "OVCLocalization.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const OVCPrefsDidChangeNotification;

/// 偏好的唯一入口。业务代码不得直接读写 NSUserDefaults。
@interface OVCPrefs : NSObject

@property (nonatomic, assign) BOOL monitoringEnabled;  // 默认 YES
@property (nonatomic, assign) BOOL autoCopy;            // 默认 YES
@property (nonatomic, assign) BOOL showPanel;           // 默认 YES
@property (nonatomic, assign) BOOL requiresKeyword;     // 默认 YES
@property (nonatomic, assign) BOOL launchAtLogin;       // 默认 NO
@property (nonatomic, assign) BOOL dockIcon;           // 菜单栏放不下时自动置 YES
@property (nonatomic, assign) BOOL hasCompletedOnboarding;
@property (nonatomic, assign) NSInteger appLanguage;     // 0 跟随系统 / 1 中文 / 2 English
@property (nonatomic, assign) double panelDuration;     // 1–20，默认 8
@property (nonatomic, assign) NSInteger panelTheme;      // 0–6，默认 0
@property (nonatomic, assign) NSInteger panelSize;       // 0–2，默认 1
@property (nonatomic, assign) double panelTransparency;  // 0–1.0，默认 0.12
@property (nonatomic, assign) NSInteger minDigits;      // 4–6，默认 4
@property (nonatomic, assign) NSInteger maxDigits;      // 6–8，默认 8

+ (instancetype)shared;

- (void)synchronize;

@end

NS_ASSUME_NONNULL_END

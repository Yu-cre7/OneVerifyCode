#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 通过系统 SMAppService 注册主 App 为登录项，显示在“系统设置 → 通用 → 登录项”。
/// 旧版 ~/Library/LaunchAgents plist 仅保留用于升级清理。
@interface OVCLaunchAgent : NSObject

+ (BOOL)isEnabled;
+ (BOOL)requiresApproval;
+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;
+ (NSString *)plistPath;

@end

NS_ASSUME_NONNULL_END

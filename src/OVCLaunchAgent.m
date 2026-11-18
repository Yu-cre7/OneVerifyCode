#import "OVCLaunchAgent.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation OVCLaunchAgent

+ (NSString *)plistPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/com.oneverifycode.app.plist"];
}

+ (SMAppService *)mainAppService {
    return [SMAppService mainAppService];
}

+ (BOOL)legacyAgentExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self plistPath]];
}

+ (BOOL)removeLegacyAgentWithError:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self plistPath];
    if (![fm fileExistsAtPath:path]) {
        return YES;
    }
    return [fm removeItemAtPath:path error:error];
}

+ (BOOL)isEnabled {
    // 系统“登录项”中的主 App 注册状态优先；旧版 LaunchAgent 仅用于升级迁移判断。
    if ([self mainAppService].status == SMAppServiceStatusEnabled) {
        return YES;
    }
    return [self legacyAgentExists];
}

+ (BOOL)requiresApproval {
    return [self mainAppService].status == SMAppServiceStatusRequiresApproval;
}

+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    SMAppService *service = [self mainAppService];

    if (!enabled) {
        // 只注销登录项，不 bootout 当前进程：主 App 注销后仍会继续运行。
        SMAppServiceStatus status = service.status;
        if (status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval) {
            NSError *unregisterError = nil;
            if (![service unregisterAndReturnError:&unregisterError] &&
                unregisterError.code != kSMErrorJobNotFound) {
                if (error) { *error = unregisterError; }
                return NO;
            }
        }
        return [self removeLegacyAgentWithError:error];
    }

    SMAppServiceStatus status = service.status;
    if (status != SMAppServiceStatusEnabled && status != SMAppServiceStatusRequiresApproval) {
        NSError *registerError = nil;
        BOOL registered = [service registerAndReturnError:&registerError];

        // 已注册但用户需要在“系统设置 → 登录项”中批准，也视为注册成功。
        if (!registered && status != SMAppServiceStatusRequiresApproval &&
            service.status != SMAppServiceStatusRequiresApproval &&
            registerError.code != kSMErrorAlreadyRegistered) {
            if (error) { *error = registerError; }
            return NO;
        }
    }

    // 成功注册主 App 后清理旧版 LaunchAgent，避免下次登录启动两份。
    if (![self removeLegacyAgentWithError:error]) {
        [service unregisterAndReturnError:NULL];
        return NO;
    }
    return YES;
}

@end

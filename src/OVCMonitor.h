#import <Foundation/Foundation.h>
#import "OVCCodeExtractor.h"

NS_ASSUME_NONNULL_BEGIN

@class OVCMessage;

@interface OVCMonitor : NSObject

/// 识别到验证码时在主线程回调。
@property (nonatomic, copy, nullable) void (^onCode)(OVCCode *code, OVCMessage *message);
/// 状态变化或错误时在主线程回调；error 为 nil 表示正常。
@property (nonatomic, copy, nullable) void (^onStatusChange)(NSError * _Nullable error);

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) int64_t lastRowID;

- (void)start;
- (void)stop;

/// 手动补扫最近 N 小时，返回识别到的验证码（不触发弹窗/剪贴板）。
- (NSArray<OVCCode *> *)scanLastHours:(NSInteger)hours messages:(NSArray<OVCMessage *> * _Nullable * _Nullable)messages;

@end

NS_ASSUME_NONNULL_END

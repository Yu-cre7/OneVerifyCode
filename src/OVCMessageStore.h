#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OVCMessage : NSObject

@property (nonatomic, assign) int64_t rowid;
@property (nonatomic, copy) NSString *guid;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) NSString *sender;
@property (nonatomic, copy, nullable) NSString *service;
@property (nonatomic, assign) NSTimeInterval date;   // Unix 秒
@property (nonatomic, assign) BOOL isFromMe;

@end

/// 只读访问 ~/Library/Messages/chat.db。任何情况下都不写入。
@interface OVCMessageStore : NSObject

@property (nonatomic, readonly, nullable) NSError *lastError;
@property (nonatomic, readonly) BOOL isOpen;

- (BOOL)openWithError:(NSError **)error;
- (void)close;

- (int64_t)currentMaxRowID;
- (NSArray<OVCMessage *> *)fetchAfterRowID:(int64_t)rowid limit:(NSInteger)limit;
- (NSArray<OVCMessage *> *)fetchSinceDate:(NSDate *)date limit:(NSInteger)limit;

+ (NSString *)maskedSender:(nullable NSString *)sender;

@end

/// 错误码
FOUNDATION_EXPORT NSString * const OVCErrorDomain;
FOUNDATION_EXPORT const NSInteger OVCErrorNoFullDiskAccess;   // 2001
FOUNDATION_EXPORT const NSInteger OVCErrorDatabaseMissing;     // 4001
FOUNDATION_EXPORT const NSInteger OVCErrorDatabaseUnreadable;  // 4002

NS_ASSUME_NONNULL_END

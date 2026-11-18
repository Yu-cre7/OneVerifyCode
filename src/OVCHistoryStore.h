#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OVCHistoryItem : NSObject

@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy, nullable) NSString *sender;
/// 脱敏后的短信摘要，最多 28 个字符；不保存短信正文。
@property (nonatomic, copy, nullable) NSString *summary;
@property (nonatomic, assign) NSTimeInterval date;
@property (nonatomic, copy, nullable) NSString *guid;

@end

@interface OVCHistoryStore : NSObject

@property (nonatomic, readonly) NSArray<OVCHistoryItem *> *items;

- (void)load;
- (void)addCode:(NSString *)code sender:(nullable NSString *)sender guid:(nullable NSString *)guid date:(NSDate *)date;
- (void)addCode:(NSString *)code
         sender:(nullable NSString *)sender
    messageText:(nullable NSString *)messageText
           guid:(nullable NSString *)guid
           date:(NSDate *)date;

/// 生成固定长度的脱敏摘要，验证码会替换为圆点。
+ (NSString *)summaryFromText:(nullable NSString *)text code:(nullable NSString *)code maxLength:(NSInteger)maxLength;
- (void)removeAll;
- (void)save;

@end

NS_ASSUME_NONNULL_END

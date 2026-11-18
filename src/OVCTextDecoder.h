#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 把 chat.db 的 attributedBody（typedstream 二进制）还原为可读文本。
/// macOS 13+ 大量短信正文只存在于该列，text 为 NULL。
@interface OVCTextDecoder : NSObject

+ (nullable NSString *)plainTextFromAttributedBody:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END

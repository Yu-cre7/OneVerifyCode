#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    NSInteger minDigits;
    NSInteger maxDigits;
    BOOL requiresKeyword;
    BOOL allowSpacedDigits;
} OVCExtractOptions;

FOUNDATION_EXPORT OVCExtractOptions OVCExtractOptionsDefault(void);

/// 一条被识别出的验证码。纯值对象，线程安全。
@interface OVCCode : NSObject

@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *keyword;
@property (nonatomic, assign) NSRange range;

- (instancetype)initWithCode:(NSString *)code keyword:(NSString *)keyword range:(NSRange)range;

@end

/// 纯函数提取器：不读偏好、不碰 UI，便于单元测试。
@interface OVCCodeExtractor : NSObject

+ (nullable OVCCode *)extractFromText:(NSString *)text options:(OVCExtractOptions)options;

/// 全角数字/标点归一化，暴露给测试与调试。
+ (NSString *)normalizedText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END

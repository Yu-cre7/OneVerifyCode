#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OVCLanguage) {
    OVCLanguageSystem = 0,
    OVCLanguageChinese = 1,
    OVCLanguageEnglish = 2,
};

extern NSNotificationName const OVCLanguageDidChangeNotification;

/// 以中文源文案为 key 取当前界面语言文案；中文模式原样返回。
FOUNDATION_EXPORT NSString *OVCStr(NSString *source);
/// 本地化格式串后用参数格式化。
FOUNDATION_EXPORT NSString *OVCStrFormat(NSString *source, ...);
FOUNDATION_EXPORT BOOL OVCIsEnglish(void);
FOUNDATION_EXPORT NSString *OVCResolvedLanguageCode(void);

NS_ASSUME_NONNULL_END

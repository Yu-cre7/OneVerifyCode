#import "OVCLocalization.h"

NSNotificationName const OVCLanguageDidChangeNotification = @"OVCLanguageDidChangeNotification";
static NSString * const OVCLanguagePrefKey = @"appLanguage";

NSString *OVCResolvedLanguageCode(void) {
    NSInteger preference = [[NSUserDefaults standardUserDefaults] integerForKey:OVCLanguagePrefKey];
    if (preference == OVCLanguageChinese) { return @"zh-Hans"; }
    if (preference == OVCLanguageEnglish) { return @"en"; }
    NSString *system = [NSLocale preferredLanguages].firstObject ?: @"en";
    return [system.lowercaseString hasPrefix:@"zh"] ? @"zh-Hans" : @"en";
}

BOOL OVCIsEnglish(void) {
    return [OVCResolvedLanguageCode() hasPrefix:@"en"];
}

static NSDictionary<NSString *, NSString *> *OVCEnglishStrings(void) {
    static NSDictionary *strings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Localizable"
                                                          ofType:@"strings"
                                                     inDirectory:nil
                                                forLocalization:@"en"];
        NSDictionary *loaded = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
        strings = [loaded isKindOfClass:[NSDictionary class]] ? loaded : @{};
    });
    return strings;
}

NSString *OVCStr(NSString *source) {
    if (source.length == 0) { return source ?: @""; }
    if (!OVCIsEnglish()) { return source; }
    NSString *translated = OVCEnglishStrings()[source];
    return translated.length > 0 ? translated : source;
}

NSString *OVCStrFormat(NSString *source, ...) {
    va_list arguments;
    va_start(arguments, source);
    NSString *result = [[NSString alloc] initWithFormat:OVCStr(source) arguments:arguments];
    va_end(arguments);
    return result;
}

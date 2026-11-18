#import "OVCCodeExtractor.h"

@implementation OVCCode

- (instancetype)initWithCode:(NSString *)code keyword:(NSString *)keyword range:(NSRange)range {
    self = [super init];
    if (self) {
        _code = [code copy];
        _keyword = [keyword copy];
        _range = range;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<OVCCode %@ keyword=%@ range=%@>",
            _code, _keyword, NSStringFromRange(_range)];
}

@end

OVCExtractOptions OVCExtractOptionsDefault(void) {
    OVCExtractOptions options;
    options.minDigits = 4;
    options.maxDigits = 8;
    options.requiresKeyword = YES;
    options.allowSpacedDigits = YES;
    return options;
}

typedef struct {
    NSInteger start;
    NSInteger length;
} OVCRangeCandidate;

static BOOL OVCIsASCIIDigit(unichar c) { return c >= '0' && c <= '9'; }
static BOOL OVCIsASCIIAlpha(unichar c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
static BOOL OVCIsASCIIAlnum(unichar c) { return OVCIsASCIIDigit(c) || OVCIsASCIIAlpha(c); }


@implementation OVCCodeExtractor

+ (NSString *)normalizedText:(NSString *)text {
    if (text.length == 0) { return @""; }

    NSMutableString *output = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0xFF10 && c <= 0xFF19) {                 // ０-９
            [output appendFormat:@"%C", (unichar)(c - 0xFF10 + '0')];
        } else if (c >= 0xFF21 && c <= 0xFF3A) {          // Ａ-Ｚ
            [output appendFormat:@"%C", (unichar)(c - 0xFF21 + 'A')];
        } else if (c >= 0xFF41 && c <= 0xFF5A) {          // ａ-ｚ
            [output appendFormat:@"%C", (unichar)(c - 0xFF41 + 'a')];
        } else if (c == 0xFF1A) {                          // ：
            [output appendString:@":"];
        } else if (c == 0xFF1B) {                          // ；
            [output appendString:@";"];
        } else if (c == 0xFF0C) {                          // ，
            [output appendString:@","];
        } else if (c == 0x3002) {                          // 。
            [output appendString:@"."];
        } else if (c == 0x200B || c == 0x200C || c == 0x200D || c == 0xFEFF) {
            continue;
        } else if (c == 0x00A0 || c == 0x3000) {
            [output appendString:@" "];
        } else {
            [output appendFormat:@"%C", c];
        }
    }
    return output;
}

+ (BOOL)isWordBoundaryBefore:(NSString *)text index:(NSInteger)index {
    if (index <= 0) { return YES; }
    unichar c = [text characterAtIndex:(NSUInteger)(index - 1)];
    return !OVCIsASCIIAlnum(c);
}

+ (BOOL)isWordBoundaryAfter:(NSString *)text index:(NSInteger)index length:(NSInteger)length {
    NSInteger next = index + length;
    if (next >= (NSInteger)text.length) { return YES; }
    unichar c = [text characterAtIndex:(NSUInteger)next];
    return !OVCIsASCIIAlnum(c);
}

+ (NSArray<NSArray<NSString *> *> *)keywordTable {
    // 第一项为展示用的关键词，其余为匹配别名（小写）。
    return @[
        @[@"验证码", @"验证码", @"驗證碼"],
        @[@"校验码", @"校验码", @"校驗碼"],
        @[@"动态码", @"动态码", @"動態碼"],
        @[@"动态密码", @"动态密码"],
        @[@"确认码", @"确认码", @"確認碼"],
        @[@"激活码", @"激活码"],
        @[@"安全码", @"安全码"],
        @[@"登录码", @"登录码", @"登入碼"],
        @[@"提取码", @"提取码"],
        @[@"验证代码", @"验证代码"],
        @[@"verification code", @"verification code", @"verify code", @"verification"],
        @[@"security code", @"security code"],
        @[@"one-time code", @"one-time code", @"one time code"],
        @[@"one-time password", @"one-time password", @"one time password"],
        @[@"passcode", @"passcode"],
        @[@"OTP", @"otp"],
        @[@"PIN", @"pin"],
        @[@"code", @"code"],
        @[@"password", @"password"],
    ];
}

+ (NSInteger)distanceToNearestKeywordIn:(NSArray<NSDictionary *> *)keywords
                          candidateStart:(NSInteger)start
                                 length:(NSInteger)length
                          keywordString:(NSString *__autoreleasing *)outKeyword {
    NSInteger candidateEnd = start + length;
    NSInteger best = NSIntegerMax;
    NSString *bestKeyword = nil;

    for (NSDictionary *entry in keywords) {
        NSRange kr = [entry[@"range"] rangeValue];
        NSInteger distance;
        if ((NSInteger)NSMaxRange(kr) <= start) {
            distance = start - (NSInteger)NSMaxRange(kr);
        } else if (candidateEnd <= (NSInteger)kr.location) {
            distance = ((NSInteger)kr.location - candidateEnd) * 2;
        } else {
            distance = 0;
        }
        if (distance < best) {
            best = distance;
            bestKeyword = entry[@"display"];
        }
    }
    if (outKeyword) { *outKeyword = bestKeyword; }
    return best;
}

+ (NSArray<NSDictionary *> *)keywordRangesInLowercaseText:(NSString *)lower {
    NSMutableArray<NSDictionary *> *ranges = [NSMutableArray array];
    NSArray<NSArray<NSString *> *> *table = [self keywordTable];
    for (NSArray<NSString *> *group in table) {
        for (NSUInteger i = 1; i < group.count; i++) {
            NSString *alias = group[i];
            NSRange search = NSMakeRange(0, lower.length);
            while (search.location < lower.length) {
                NSRange found = [lower rangeOfString:alias options:0 range:search];
                if (found.location == NSNotFound) { break; }
                BOOL ascii = alias.length > 0 && [alias characterAtIndex:0] < 128;
                BOOL ok = YES;
                if (ascii) {
                    ok = [self isWordBoundaryBefore:lower index:(NSInteger)found.location] &&
                         [self isWordBoundaryAfter:lower index:(NSInteger)found.location length:(NSInteger)found.length];
                }
                if (ok) {
                    [ranges addObject:@{@"range": [NSValue valueWithRange:found],
                                        @"display": group.firstObject}];
                }
                NSUInteger next = NSMaxRange(found);
                if (next <= search.location) { next = search.location + 1; }
                search = NSMakeRange(next, lower.length - next);
            }
        }
    }
    return ranges;
}

+ (BOOL)isPlausibleYear:(NSString *)digits {
    if (digits.length != 4) { return NO; }
    NSInteger value = digits.integerValue;
    return (value >= 1900 && value <= 2099);
}

+ (BOOL)hasBadContextForCandidateIn:(NSString *)text
                              start:(NSInteger)start
                             length:(NSInteger)length {
    NSInteger end = start + length;
    if (start > 0) {
        unichar before = [text characterAtIndex:(NSUInteger)(start - 1)];
        if (before == 0x00A5 || before == '$' || before == 0xFFE5) { return YES; }
        if (before == '*' || before == 0xFF0A) { return YES; }   // 138****8000 之类的脱敏号码
        // 日期：2024-11-17
        if (before == '-' || before == '/' || before == 0x5E74 /*年*/) {
            NSInteger probe = start - 2;
            NSInteger digits = 0;
            while (probe >= 0 && OVCIsASCIIDigit([text characterAtIndex:(NSUInteger)probe])) {
                digits++;
                probe--;
            }
            if (digits == 4) { return YES; }
        }
    }
    if (end < (NSInteger)text.length) {
        unichar after = [text characterAtIndex:(NSUInteger)end];
        NSUInteger tailLength = MIN((NSUInteger)8, text.length - (NSUInteger)end);
        NSString *rawTail = [text substringWithRange:NSMakeRange((NSUInteger)end, tailLength)];
        NSString *afterString = [rawTail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (after == '-' || after == '/' || after == 0x5E74 /*年*/) { return YES; }
        if ([afterString hasPrefix:@"元"] || [afterString hasPrefix:@"块"] ||
            [afterString hasPrefix:@"万"] || [afterString hasPrefix:@"%"] ||
            [afterString hasPrefix:@"余"] || [afterString hasPrefix:@"人"] ||
            [afterString hasPrefix:@"次"] || [afterString hasPrefix:@"件"]) {
            return YES;
        }
        if ([afterString hasPrefix:@"分钟"] || [afterString hasPrefix:@"小时"] ||
            [afterString hasPrefix:@"秒钟"] || [afterString hasPrefix:@"秒"]) {
            return YES;
        }
    }
    return NO;
}

+ (nullable OVCCode *)extractFromText:(NSString *)rawText options:(OVCExtractOptions)options {
    if (rawText.length == 0) { return nil; }

    NSString *text = [self normalizedText:rawText];
    if (text.length == 0 || text.length > 4000) {
        text = [text substringToIndex:MIN(text.length, (NSUInteger)4000)];
    }
    NSString *lower = text.lowercaseString;
    NSArray<NSDictionary *> *keywordRanges = [self keywordRangesInLowercaseText:lower];

    if (options.requiresKeyword && keywordRanges.count == 0) {
        return nil;
    }

    NSInteger minDigits = MAX(3, options.minDigits);
    NSInteger maxDigits = MAX(minDigits, options.maxDigits);

    NSInteger bestScore = NSIntegerMin;
    NSInteger bestStart = NSNotFound;
    NSInteger bestLength = 0;
    NSString *bestKeyword = nil;
    NSString *bestCode = nil;

    // 1) 连续数字
    NSInteger i = 0;
    while (i < (NSInteger)text.length) {
        unichar c = [text characterAtIndex:(NSUInteger)i];
        if (!OVCIsASCIIDigit(c)) { i++; continue; }
        NSInteger start = i;
        while (i < (NSInteger)text.length && OVCIsASCIIDigit([text characterAtIndex:(NSUInteger)i])) { i++; }
        NSInteger length = i - start;
        if (length < minDigits || length > maxDigits) { continue; }

        NSString *digits = [text substringWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)length)];
        if ([self hasBadContextForCandidateIn:text start:start length:length]) { continue; }

        NSString *keyword = nil;
        NSInteger distance = [self distanceToNearestKeywordIn:keywordRanges
                                               candidateStart:start
                                                      length:length
                                               keywordString:&keyword];
        if (options.requiresKeyword && distance > 60) { continue; }
        // 四位年份只有在远离关键词时才排除，避免把 2024 这类真实验证码误杀
        if ([self isPlausibleYear:digits] && distance > 12) { continue; }

        NSInteger score = 0;
        if (distance <= 3) { score += 120; }
        else if (distance <= 12) { score += 90; }
        else if (distance <= 30) { score += 55; }
        else if (distance <= 60) { score += 20; }

        if (length == 6) { score += 16; }
        else if (length == 4) { score += 6; }
        else if (length == 5) { score += 8; }
        else if (length == 8) { score += 4; }

        if (start >= 2) {
            NSString *prefix = [text substringWithRange:NSMakeRange((NSUInteger)start - 2, 2)];
            if ([prefix containsString:@":"] || [prefix containsString:@"："]) { score += 12; }
        }
        if (score > bestScore) {
            bestScore = score;
            bestStart = start;
            bestLength = length;
            bestKeyword = keyword ?: @"验证码";
            bestCode = digits;
        }
    }

    // 2) 空格/短横分隔的 3+3（如 “123 456”）
    if (options.allowSpacedDigits && minDigits <= 6 && maxDigits >= 6) {
        NSRegularExpression *spaced = [NSRegularExpression regularExpressionWithPattern:@"(?<![0-9])([0-9]{3})[ \\u00A0-]([0-9]{3})(?![0-9])"
                                                                               options:0 error:NULL];
        NSArray<NSTextCheckingResult *> *matches = [spaced matchesInString:text options:0 range:NSMakeRange(0, text.length)];
        for (NSTextCheckingResult *match in matches) {
            NSString *digits = [[text substringWithRange:[match rangeAtIndex:1]]
                                stringByAppendingString:[text substringWithRange:[match rangeAtIndex:2]]];
            NSInteger start = (NSInteger)match.range.location;
            if ([self isPlausibleYear:digits]) { continue; }
            NSString *keyword = nil;
            NSInteger distance = [self distanceToNearestKeywordIn:keywordRanges
                                                   candidateStart:start length:6 keywordString:&keyword];
            if (options.requiresKeyword && distance > 60) { continue; }
            NSInteger score = (distance <= 12 ? 110 : 40) + 20;
            if (score > bestScore) {
                bestScore = score;
                bestStart = start;
                bestLength = (NSInteger)match.range.length;
                bestKeyword = keyword ?: @"验证码";
                bestCode = digits;
            }
        }
    }

    // 3) 字母数字混合码（仅在有关键词且没有找到纯数字时）
    if (bestCode == nil && keywordRanges.count > 0 && maxDigits >= 6) {
        NSRegularExpression *alnum = [NSRegularExpression regularExpressionWithPattern:@"(?<![A-Za-z0-9])([A-Za-z0-9]{6,8})(?![A-Za-z0-9])"
                                                                              options:0 error:NULL];
        NSArray<NSTextCheckingResult *> *matches = [alnum matchesInString:lower options:0 range:NSMakeRange(0, lower.length)];
        for (NSTextCheckingResult *match in matches) {
            NSString *token = [text substringWithRange:match.range].uppercaseString;
            NSInteger letters = 0;
            NSInteger digits = 0;
            for (NSUInteger k = 0; k < token.length; k++) {
                unichar c = [token characterAtIndex:k];
                if (OVCIsASCIIAlpha(c)) { letters++; }
                if (OVCIsASCIIDigit(c)) { digits++; }
            }
            if (letters < 2 || digits < 2) { continue; }
            NSString *keyword = nil;
            NSInteger distance = [self distanceToNearestKeywordIn:keywordRanges
                                                   candidateStart:(NSInteger)match.range.location
                                                          length:(NSInteger)match.range.length
                                                   keywordString:&keyword];
            if (distance > 30) { continue; }
            bestScore = 80 - distance;
            bestStart = (NSInteger)match.range.location;
            bestLength = (NSInteger)match.range.length;
            bestKeyword = keyword ?: @"验证码";
            bestCode = token;
            break;
        }
    }

    if (bestCode.length == 0) { return nil; }

    NSRange range = NSMakeRange((NSUInteger)MAX(0, bestStart), (NSUInteger)MAX(0, bestLength));
    return [[OVCCode alloc] initWithCode:bestCode keyword:bestKeyword ?: @"验证码" range:range];
}

@end

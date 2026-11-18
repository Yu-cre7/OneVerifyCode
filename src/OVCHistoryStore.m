#import "OVCHistoryStore.h"

@interface OVCHistoryItem ()
@end

@implementation OVCHistoryItem
@end

@interface OVCHistoryStore ()
@property (nonatomic, strong) NSMutableArray<OVCHistoryItem *> *mutableItems;
@property (nonatomic, strong) NSURL *fileURL;
@end

@implementation OVCHistoryStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableItems = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *support = [fm URLForDirectory:NSApplicationSupportDirectory
                                    inDomain:NSUserDomainMask
                           appropriateForURL:nil
                                      create:YES
                                       error:NULL];
        NSURL *dir = [support URLByAppendingPathComponent:@"OneVerifyCode" isDirectory:YES];
        [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        _fileURL = [dir URLByAppendingPathComponent:@"history.json"];
    }
    return self;
}

- (NSArray<OVCHistoryItem *> *)items {
    return [self.mutableItems copy];
}

- (void)load {
    [self.mutableItems removeAllObjects];
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
    if (data.length == 0) { return; }

    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        [self quarantineCorruptFile];
        return;
    }
    NSArray *rawItems = ((NSDictionary *)json)[@"items"];
    if (![rawItems isKindOfClass:[NSArray class]]) { return; }

    for (id raw in rawItems) {
        if (![raw isKindOfClass:[NSDictionary class]]) { continue; }
        NSDictionary *dict = raw;
        NSString *code = dict[@"code"];
        if (![code isKindOfClass:[NSString class]] || code.length == 0) { continue; }
        OVCHistoryItem *item = [OVCHistoryItem new];
        item.code = code;
        item.sender = [dict[@"sender"] isKindOfClass:[NSString class]] ? dict[@"sender"] : nil;
        item.summary = [dict[@"summary"] isKindOfClass:[NSString class]] ? dict[@"summary"] : nil;
        item.guid = [dict[@"guid"] isKindOfClass:[NSString class]] ? dict[@"guid"] : nil;
        item.date = [dict[@"date"] isKindOfClass:[NSNumber class]] ? [dict[@"date"] doubleValue] : 0;
        [self.mutableItems addObject:item];
    }
}

- (void)quarantineCorruptFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *name = [NSString stringWithFormat:@"history.corrupt-%.0f.json", [NSDate date].timeIntervalSince1970];
    NSURL *backup = [[self.fileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:name];
    [fm moveItemAtURL:self.fileURL toURL:backup error:NULL];
}

- (void)addCode:(NSString *)code sender:(NSString *)sender guid:(NSString *)guid date:(NSDate *)date {
    [self addCode:code sender:sender messageText:nil guid:guid date:date];
}

- (void)addCode:(NSString *)code
         sender:(NSString *)sender
    messageText:(NSString *)messageText
           guid:(NSString *)guid
           date:(NSDate *)date {
    if (code.length == 0) { return; }

    // 相同 guid 或 30 秒内相同验证码不重复记录
    for (OVCHistoryItem *existing in self.mutableItems) {
        if (guid.length > 0 && [existing.guid isEqualToString:guid]) { return; }
        if ([existing.code isEqualToString:code] && fabs(existing.date - date.timeIntervalSince1970) < 30) { return; }
    }

    OVCHistoryItem *item = [OVCHistoryItem new];
    item.code = code;
    item.sender = sender;
    item.summary = [OVCHistoryStore summaryFromText:messageText code:code maxLength:28];
    item.guid = guid;
    item.date = date.timeIntervalSince1970;
    [self.mutableItems insertObject:item atIndex:0];

    while (self.mutableItems.count > 50) {
        [self.mutableItems removeLastObject];
    }
    [self save];
}

+ (NSString *)summaryFromText:(NSString *)text code:(NSString *)code maxLength:(NSInteger)maxLength {
    if (text.length == 0) { return @""; }
    NSMutableString *clean = [text mutableCopy];
    [clean replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, clean.length)];
    while ([clean containsString:@"  "]) {
        [clean replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, clean.length)];
    }
    NSString *trimmed = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length > 0) {
        NSString *mask = @"";
        for (NSUInteger i = 0; i < code.length; i++) { mask = [mask stringByAppendingString:@"•"]; }
        trimmed = [trimmed stringByReplacingOccurrencesOfString:code withString:mask];
        // 短信里偶尔会出现“123 456”这种带分隔符的验证码，按原顺序匹配并整体脱敏。
        NSMutableString *pattern = [NSMutableString string];
        for (NSUInteger i = 0; i < code.length; i++) {
            if (i > 0) { [pattern appendString:@"\\s*"]; }
            [pattern appendFormat:@"%C", [code characterAtIndex:i]];
        }
        NSRegularExpression *spaced = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
        if (spaced) {
            trimmed = [spaced stringByReplacingMatchesInString:trimmed
                                                       options:0
                                                         range:NSMakeRange(0, trimmed.length)
                                                  withTemplate:mask];
        }
    }
    // 兜底：任何 4–8 位连续数字都视为敏感数字，避免格式化后的验证码残留。
    NSRegularExpression *digits = [NSRegularExpression regularExpressionWithPattern:@"[0-9]{4,8}" options:0 error:NULL];
    if (digits) {
        NSArray<NSTextCheckingResult *> *matches = [digits matchesInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
        NSMutableString *masked = [trimmed mutableCopy];
        for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
            NSString *replacement = [@"" stringByPaddingToLength:match.range.length withString:@"•" startingAtIndex:0];
            [masked replaceCharactersInRange:match.range withString:replacement];
        }
        trimmed = masked;
    }
    if (maxLength <= 1) { return trimmed; }
    if (trimmed.length <= (NSUInteger)maxLength) { return trimmed; }
    // 按组合字符截断，避免把 emoji 或中文代理对截成半个字。
    NSRange range = [trimmed rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, (NSUInteger)maxLength - 1)];
    return [[trimmed substringWithRange:range] stringByAppendingString:@"…"];
}

- (void)removeAll {
    [self.mutableItems removeAllObjects];
    [self save];
}

- (void)save {
    NSMutableArray *payload = [NSMutableArray arrayWithCapacity:self.mutableItems.count];
    for (OVCHistoryItem *item in self.mutableItems) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"code"] = item.code ?: @"";
        dict[@"date"] = @(item.date);
        if (item.sender) { dict[@"sender"] = item.sender; }
        if (item.summary) { dict[@"summary"] = item.summary; }
        if (item.guid) { dict[@"guid"] = item.guid; }
        [payload addObject:dict];
    }
    NSDictionary *root = @{@"version": @1, @"items": payload};
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:NULL];
    if (!data) { return; }
    [data writeToURL:self.fileURL options:NSDataWritingAtomic error:NULL];
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0600}
                                     ofItemAtPath:self.fileURL.path
                                            error:NULL];
}

@end

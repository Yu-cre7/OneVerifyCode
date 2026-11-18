#import "OVCTextDecoder.h"

@implementation OVCTextDecoder

static BOOL OVCByteIsPrintableASCII(unsigned char b) {
    return b >= 0x20 && b <= 0x7E;
}

/// typedstream 会在字符串前写 0x84 0x01 0x2B（NSString 类引用）与 0x96 0x8x 长度。
/// 直接按“可打印 UTF-8 片段”提取更稳，再过滤掉类名/属性名等元数据。
+ (NSString *)plainTextFromAttributedBody:(NSData *)data {
    if (data.length == 0) { return nil; }

    const unsigned char *bytes = data.bytes;
    NSUInteger length = data.length;
    NSMutableData *run = [NSMutableData dataWithCapacity:128];
    NSMutableArray<NSString *> *runs = [NSMutableArray array];

    for (NSUInteger i = 0; i < length; ) {
        unsigned char b = bytes[i];
        BOOL appended = NO;

        if (OVCByteIsPrintableASCII(b) || b == 0x0A || b == 0x09) {
            [run appendBytes:&b length:1];
            i += 1;
            appended = YES;
        } else if (b >= 0xC2 && b <= 0xF4) {
            NSUInteger expected = 0;
            if (b < 0xE0) { expected = 2; }
            else if (b < 0xF0) { expected = 3; }
            else { expected = 4; }

            BOOL valid = (i + expected <= length);
            for (NSUInteger k = 1; valid && k < expected; k++) {
                unsigned char continuation = bytes[i + k];
                if (continuation < 0x80 || continuation > 0xBF) { valid = NO; }
            }
            if (valid) {
                [run appendBytes:(bytes + i) length:expected];
                i += expected;
                appended = YES;
            }
        }

        if (!appended) {
            if (run.length >= 3) {
                NSString *piece = [[NSString alloc] initWithData:run encoding:NSUTF8StringEncoding];
                if (piece.length >= 3) { [runs addObject:piece]; }
            }
            [run setLength:0];
            i += 1;
        }
    }
    if (run.length >= 3) {
        NSString *piece = [[NSString alloc] initWithData:run encoding:NSUTF8StringEncoding];
        if (piece.length >= 3) { [runs addObject:piece]; }
    }

    NSArray<NSString *> *noise = @[
        @"streamtyped", @"NSMutableAttributedString", @"NSAttributedString", @"NSString",
        @"NSObject", @"NSDictionary", @"NSMutableDictionary", @"NSNumber", @"NSValue",
        @"NSData", @"NSURL", @"NSFont", @"NSColor", @"NSShadow", @"NSParagraphStyle",
        @"NSMutableParagraphStyle", @"NSWritingDirection", @"NSAttachment",
        @"__kIMMessagePartAttributeName", @"__kIMFileTransferGUIDAttributeName",
        @"__kIMBaseWritingDirectionAttributeName", @"__kIMDataDetectedAttributeName",
        @"__kIMEmojiImageURLAttributeName", @"NSCharacterSet", @"NSNull",
        @"NSKeyedArchiver", @"NSUnarchiver", @"bplist00"
    ];

    NSMutableArray<NSString *> *cleaned = [NSMutableArray array];
    for (NSString *piece in runs) {
        NSString *value = piece;
        for (NSString *token in noise) {
            value = [value stringByReplacingOccurrencesOfString:token withString:@""];
        }
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length < 2) { continue; }
        if ([value rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location == NSNotFound &&
            [value rangeOfCharacterFromSet:[self cjkCharacterSet]].location == NSNotFound) {
            continue;
        }
        [cleaned addObject:value];
    }

    if (cleaned.count == 0) { return nil; }

    // 取字符数最多的一段：正文通常显著长于属性名残片。
    NSString *best = cleaned.firstObject;
    for (NSString *piece in cleaned) {
        if (piece.length > best.length) { best = piece; }
    }
    return best;
}

+ (NSCharacterSet *)cjkCharacterSet {
    static NSCharacterSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *mutable = [NSMutableCharacterSet new];
        [mutable addCharactersInRange:NSMakeRange(0x4E00, 0x9FFF - 0x4E00)];
        [mutable addCharactersInRange:NSMakeRange(0x3000, 0x303F - 0x3000)];
        [mutable addCharactersInRange:NSMakeRange(0xFF00, 0xFFEF - 0xFF00)];
        set = [mutable copy];
    });
    return set;
}

@end

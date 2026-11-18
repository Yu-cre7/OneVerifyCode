#import <Foundation/Foundation.h>
#import "OVCCodeExtractor.h"
#import "OVCTextDecoder.h"

static int failures = 0;
static int total = 0;

static void expectCode(NSString *text, NSString *expected) {
    total++;
    OVCExtractOptions options = OVCExtractOptionsDefault();
    OVCCode *code = [OVCCodeExtractor extractFromText:text options:options];
    if (expected == nil) {
        if (code) {
            failures++;
            printf("FAIL  %s\n      expected nil, got %s\n", text.UTF8String, code.code.UTF8String);
        } else {
            printf("ok    %s -> nil\n", text.UTF8String);
        }
        return;
    }
    if (![code.code isEqualToString:expected]) {
        failures++;
        printf("FAIL  %s\n      expected %s, got %s\n",
               text.UTF8String, expected.UTF8String, code.code.UTF8String ?: "(nil)");
    } else {
        printf("ok    %s -> %s\n", text.UTF8String, code.code.UTF8String);
    }
}

static NSData *syntheticAttributedBody(void) {
    unsigned char prefix[] = {
        0x04, 0x0b, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6d, 0x74, 0x79, 0x70, 0x65, 0x64,
        0x81, 0xe8, 0x03, 0x84, 0x01, 0x40,
        0x84, 0x84, 0x84, 0x12,
        0x4e, 0x53, 0x41, 0x74, 0x74, 0x72, 0x69, 0x62, 0x75, 0x74, 0x65, 0x64,
        0x53, 0x74, 0x72, 0x69, 0x6e, 0x67,
        0x00, 0x84, 0x84, 0x08,
        0x4e, 0x53, 0x4f, 0x62, 0x6a, 0x65, 0x63, 0x74,
        0x00, 0x85, 0x92, 0x84, 0x84, 0x84, 0x08,
        0x4e, 0x53, 0x53, 0x74, 0x72, 0x69, 0x6e, 0x67,
        0x01, 0x94, 0x84, 0x01, 0x2b, 0x96, 0x10
    };
    NSMutableData *data = [NSMutableData dataWithBytes:prefix length:sizeof(prefix)];
    [data appendData:[@"验证码 482913" dataUsingEncoding:NSUTF8StringEncoding]];
    unsigned char suffix[] = {0x86, 0x84};
    [data appendBytes:suffix length:sizeof(suffix)];
    return data;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        printf("== 提取规则 ==\n");

        expectCode(@"【支付宝】验证码 123456，5分钟内有效。", @"123456");
        expectCode(@"您的验证码为：4821，请勿泄露。", @"4821");
        expectCode(@"Verification code: 998877", @"998877");
        expectCode(@"G-998877 is your Google verification code.", @"998877");
        expectCode(@"验证码 123 456", @"123456");
        expectCode(@"验证码 123-456", @"123456");
        expectCode(@"【京东】您的验证码是１２３４５６", @"123456");
        expectCode(@"Your code is 1234. Do not share.", @"1234");
        expectCode(@"验证码：12345678", @"12345678");
        expectCode(@"验证码 123", nil);
        expectCode(@"您的订单 202411170001 已发货", nil);
        expectCode(@"会议时间 2024-11-17 14:30", nil);
        expectCode(@"入住日期 2024 年 11 月", nil);
        expectCode(@"您的验证码已发送至 138****8000", nil);
        expectCode(@"验证码 000000", @"000000");
        expectCode(@"Your OTP is 654321", @"654321");
        expectCode(@"PIN: 8899", @"8899");
        expectCode(@"【美团】验证码：5566。如非本人操作请忽略。", @"5566");
        expectCode(@"code: 12AB34", @"12AB34");
        expectCode(@"验证码 AB12CD，请勿泄露", @"AB12CD");
        expectCode(@"验证码：123456，客服电话 400-800-1234", @"123456");
        expectCode(@"订单号 123456789 验证码 654321", @"654321");
        expectCode(@"你的验证码是 123456789", nil);
        expectCode(@"【Apple】Your Apple ID code is: 123456.", @"123456");
        expectCode(@"验证码 12345", @"12345");
        expectCode(@"验证码 88776655", @"88776655");
        expectCode(@"【淘宝】验证码 654321，本验证码 5 分钟内有效", @"654321");
        expectCode(@"没有关键词 123456", nil);
        expectCode(@"验证码 999999 金额 5000 元", @"999999");
        expectCode(@"【银行】验证码 2024，请勿告知他人", @"2024");
        expectCode(@"2024年验证码 1234", @"1234");
        expectCode(@"验证码：123456。验证码：654321", @"123456");
        expectCode(@"验证码 123456 验证码 654321", @"123456");
        expectCode(@"Your verification code is 482913", @"482913");
        expectCode(@"【微信】验证码 8877，用于登录。", @"8877");

        printf("\n== 宽松模式（不要求关键词）==\n");
        OVCExtractOptions loose = OVCExtractOptionsDefault();
        loose.requiresKeyword = NO;
        total++;
        OVCCode *looseCode = [OVCCodeExtractor extractFromText:@"入住日期 2024 年" options:loose];
        if (looseCode) {
            failures++;
            printf("FAIL  宽松模式不应把年份当验证码，实际 %s\n", looseCode.code.UTF8String);
        } else {
            printf("ok    宽松模式排除年份\n");
        }

        printf("\n== attributedBody 解码 ==\n");
        NSData *blob = syntheticAttributedBody();
        NSString *decoded = [OVCTextDecoder plainTextFromAttributedBody:blob];
        total++;
        if (decoded.length == 0 || [decoded rangeOfString:@"482913"].location == NSNotFound) {
            failures++;
            printf("FAIL  解码结果异常：%s\n", decoded.UTF8String ?: "(nil)");
        } else {
            printf("ok    解码得到：%s\n", decoded.UTF8String);
            OVCCode *code = [OVCCodeExtractor extractFromText:decoded options:OVCExtractOptionsDefault()];
            total++;
            if (![code.code isEqualToString:@"482913"]) {
                failures++;
                printf("FAIL  解码后再提取失败\n");
            } else {
                printf("ok    解码后再提取 -> 482913\n");
            }
        }

        printf("\n== 全角归一化 ==\n");
        total++;
        NSString *normalized = [OVCCodeExtractor normalizedText:@"验证码：１２３４５６"];
        if (![normalized isEqualToString:@"验证码:123456"]) {
            failures++;
            printf("FAIL  归一化得到 %s\n", normalized.UTF8String);
        } else {
            printf("ok    归一化 -> %s\n", normalized.UTF8String);
        }

        printf("\n结果：%d/%d 通过，%d 失败\n", total - failures, total, failures);
        return failures == 0 ? 0 : 1;
    }
}

#import <Foundation/Foundation.h>
#import "OVCHistoryStore.h"

static int failures = 0;
static int total = 0;

static void expect(BOOL condition, NSString *label) {
    total++;
    if (condition) {
        printf("ok    %s\n", label.UTF8String);
    } else {
        failures++;
        printf("FAIL  %s\n", label.UTF8String);
    }
}

int main(void) {
    @autoreleasepool {
        printf("== 历史摘要 ==\n");
        NSString *text = @"【快手科技】您的验证码为：123456，请您注意不要泄露，5分钟有效";
        NSString *summary = [OVCHistoryStore summaryFromText:text code:@"123456" maxLength:28];
        expect(summary.length <= 28, @"摘要不超过 28 个字符");
        expect([summary rangeOfString:@"123456"].location == NSNotFound, @"摘要不包含完整验证码");
        expect([summary rangeOfString:@"••••••"].location != NSNotFound, @"验证码替换为圆点");
        expect([summary rangeOfString:@"快手科技"].location != NSNotFound, @"保留服务来源");

        NSString *masked = [OVCHistoryStore summaryFromText:@"验证码 123 456 已发送" code:@"123456" maxLength:28];
        expect([masked rangeOfString:@"123"].location == NSNotFound, @"兜底屏蔽格式化数字");

        NSString *multiline = [OVCHistoryStore summaryFromText:@"【测试】\n您的验证码为：987654\n请勿泄露" code:@"987654" maxLength:28];
        expect([multiline rangeOfString:@"\n"].location == NSNotFound, @"换行折叠为空格");
        expect(multiline.length <= 28, @"折叠后长度受限");

        printf("\n结果：%d/%d 通过，%d 失败\n", total - failures, total, failures);
        return failures == 0 ? 0 : 1;
    }
}

#import <Cocoa/Cocoa.h>
#import <string.h>
#import "OVCAppDelegate.h"
#import "OVCRenderDump.h"
#import "OVCMessageStore.h"
#import "OVCCodeExtractor.h"
#import "OVCPrefs.h"
#import "OVCFocusLocator.h"
#import "OVCLaunchAgent.h"
#import "OVCPanelController.h"
#import "OVCStatusController.h"
#import "OVCHistoryStore.h"
#import "OVCLocalization.h"

static int OVCRunSelfTest(void) {
    printf("== 一码自检 ==\n");

    OVCMessageStore *store = [[OVCMessageStore alloc] init];
    NSError *error = nil;
    BOOL opened = [store openWithError:&error];
    printf("短信库: %s\n", opened ? "可读取" : error.localizedDescription.UTF8String);
    if (!opened) { return 1; }
    printf("最大 ROWID: %lld\n", (long long)[store currentMaxRowID]);

    NSArray<OVCMessage *> *messages = [store fetchSinceDate:[NSDate dateWithTimeIntervalSinceNow:-7 * 86400] limit:300];
    printf("最近 7 天消息: %lu\n", (unsigned long)messages.count);

    OVCPrefs *prefs = [OVCPrefs shared];
    OVCExtractOptions options = OVCExtractOptionsDefault();
    options.minDigits = prefs.minDigits;
    options.maxDigits = prefs.maxDigits;
    options.requiresKeyword = prefs.requiresKeyword;

    NSInteger withText = 0;
    NSInteger found = 0;
    for (OVCMessage *message in messages) {
        if (message.text.length == 0) { continue; }
        withText++;
        OVCCode *code = [OVCCodeExtractor extractFromText:message.text options:options];
        if (!code) { continue; }
        found++;
        if (found <= 3) {
            NSString *masked = [OVCMessageStore maskedSender:message.sender];
            printf("  样例: %s***%s  来源 %s\n",
                   [[code.code substringToIndex:1] UTF8String],
                   [[code.code substringFromIndex:MAX(1, (NSInteger)code.code.length - 1)] UTF8String],
                   masked.UTF8String);
        }
    }
    printf("有正文: %ld，识别验证码: %ld\n", (long)withText, (long)found);
    printf("辅助功能: %s\n", [OVCFocusLocator accessibilityTrusted] ? "已授权" : "未授权");
    printf("开机启动: %s\n", [OVCLaunchAgent isEnabled] ? "已开启" : "关闭");
    printf("完全磁盘访问: %s\n", opened ? "已授权" : "未授权");
    [store close];
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

        if (argc > 1 && strcmp(argv[1], "--render-previews") == 0) {
            NSString *directory = (argc > 2)
                ? [NSString stringWithUTF8String:argv[2]]
                : [NSTemporaryDirectory() stringByAppendingPathComponent:@"evc-previews"];
            int result = OVCRenderPreviews(directory);
            fprintf(stdout, "previews:%s (%s)\n", result == 0 ? "ok" : "failed", directory.UTF8String);
            return result;
        }

        if (argc > 1 && strcmp(argv[1], "--self-test") == 0) {
            return OVCRunSelfTest();
        }

        if (argc > 1 && strcmp(argv[1], "--preview-menu") == 0) {
            OVCStatusController *status = [[OVCStatusController alloc] init];
            status.statusText = OVCStr(@"监听中 · 今日 3 条");
            status.monitoringEnabled = YES;
            NSMutableArray<OVCHistoryItem *> *items = [NSMutableArray array];
            NSArray<NSString *> *codes = @[@"482913", @"7264", @"193847"];
            NSArray<NSString *> *sources = @[OVCStr(@"短信 · 1069****01"), OVCStr(@"短信 · 9558**"), @"iMessage · hu***@icloud.com"];
            NSTimeInterval now = [NSDate date].timeIntervalSince1970;
            for (NSInteger i = 0; i < 3; i++) {
                OVCHistoryItem *item = [[OVCHistoryItem alloc] init];
                item.code = codes[(NSUInteger)i];
                item.sender = sources[(NSUInteger)i];
                item.summary = OVCStr(@"【示例】验证码为：••••••，请勿泄露");
                item.date = now - 120 - i * 600;
                item.guid = [NSString stringWithFormat:@"preview-%ld", (long)i];
                [items addObject:item];
            }
            status.recentItems = items;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [status showPreviewMenuAtPoint:NSMakePoint(1050, 900)];
            });
            [application run];
            return 0;
        }

        if (argc > 1 && strcmp(argv[1], "--lang-test") == 0) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            printf("bundle=%s\n", NSBundle.mainBundle.bundleIdentifier.UTF8String);
            printf("defaults=%ld resolved=%s\n", (long)[defaults integerForKey:@"appLanguage"], OVCResolvedLanguageCode().UTF8String);
            NSString *path = [NSBundle.mainBundle pathForResource:@"Localizable" ofType:@"strings" inDirectory:nil forLocalization:@"en"];
            printf("path=%s\n", path.UTF8String ?: "nil");
            NSDictionary *d = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
            printf("count=%lu str=%s\n", (unsigned long)d.count, OVCStr(@"外观").UTF8String);
            return 0;
        }


        if (argc > 1 && strcmp(argv[1], "--demo-panel") == 0) {
            OVCPanelController *panel = [[OVCPanelController alloc] init];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [panel presentCode:@"482913" sender:@"1069***213" duration:8];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
            [application run];
            return 0;
        }

        OVCAppDelegate *delegate = [[OVCAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}

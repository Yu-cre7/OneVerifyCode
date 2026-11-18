#import "OVCAppDelegate.h"
#import "OVCLocalization.h"
#import "OVCTheme.h"
#import "OVCPrefs.h"
#import "OVCHistoryStore.h"
#import "OVCMonitor.h"
#import "OVCMessageStore.h"
#import "OVCCodeExtractor.h"
#import "OVCPanelController.h"
#import "OVCSettingsWindow.h"
#import "OVCStatusController.h"
#import "OVCFocusLocator.h"
#import "OVCLaunchAgent.h"

static void OVCLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"%@", message);

    static NSString *logPath = nil;
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs"];
        logPath = [directory stringByAppendingPathComponent:@"OneVerifyCode.log"];
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });

    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:[NSDate date]], message];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:logPath]) {
        [fm createFileAtPath:logPath contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (handle) {
        @try {
            [handle seekToEndOfFile];
            [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        } @catch (NSException *exception) {
            // 日志失败不应影响主流程
        }
        [handle closeFile];
    }
}

static void OVCCopyText(NSString *text) {
    if (text.length == 0) { return; }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];
}

@interface OVCAppDelegate () <OVCStatusControllerDelegate>
@property (nonatomic, strong) OVCPrefs *prefs;
@property (nonatomic, strong) OVCHistoryStore *history;
@property (nonatomic, strong) OVCMonitor *monitor;
@property (nonatomic, strong) OVCPanelController *panel;
@property (nonatomic, strong) OVCStatusController *status;
@property (nonatomic, strong) OVCSettingsWindow *settings;
@property (nonatomic, strong) OVCMessageStore *probeStore;
@property (nonatomic, strong, nullable) NSTimer *refreshTimer;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, copy, nullable) NSString *lastErrorMessage;
@property (nonatomic, assign) BOOL statusError;
@property (nonatomic, assign) BOOL lastFDA;
@property (nonatomic, assign) BOOL lastAX;
@end

@implementation OVCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    OVCLog(OVCStr(@"一码启动，version %@"), NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"?");

    self.prefs = [OVCPrefs shared];
    self.history = [[OVCHistoryStore alloc] init];
    [self.history load];

    self.panel = [[OVCPanelController alloc] init];
    self.settings = [[OVCSettingsWindow alloc] init];
    [self wireSettingsCallbacks];

    self.status = [[OVCStatusController alloc] init];
    self.status.delegate = self;
    [self.status install];
    [self applyActivationPolicy];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf ensureStatusItemAccessible];
    });

    self.probeStore = [[OVCMessageStore alloc] init];

    // 从旧版 LaunchAgent 升级到 SMAppService 登录项；只在已安装位置执行，
    // 避免开发构建（build/stage）被误注册进系统登录项。
    if (self.prefs.launchAtLogin && [NSBundle.mainBundle.bundlePath hasPrefix:@"/Applications/"]) {
        NSError *loginItemError = nil;
        if (![OVCLaunchAgent setEnabled:YES error:&loginItemError]) {
            OVCLog(OVCStr(@"登录项迁移失败：%@"), loginItemError.localizedDescription);
            self.prefs.launchAtLogin = NO;
        } else if ([OVCLaunchAgent requiresApproval]) {
            OVCLog(OVCStr(@"登录项等待系统设置批准"));
        }
    }

    [self startMonitor];
    [self refreshStatusUI];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(prefsDidChange:)
                                                 name:OVCPrefsDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(languageDidChange:)
                                                 name:OVCLanguageDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:nil];

    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                         target:self
                                                       selector:@selector(periodicRefresh:)
                                                       userInfo:nil
                                                        repeats:YES];
    self.refreshTimer.tolerance = 1.0;

    if (!self.prefs.hasCompletedOnboarding) {
        self.prefs.hasCompletedOnboarding = YES;
        [self.settings show];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    [self.monitor stop];
    [self.history save];
    [self.probeStore close];
    OVCLog(OVCStr(@"一码退出"));
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [NSApp activateIgnoringOtherApps:YES];
    [self.settings show];
    return YES;
}

#pragma mark - Dock 兜底

- (void)applyActivationPolicy {
    NSApplicationActivationPolicy policy = self.prefs.dockIcon ? NSApplicationActivationPolicyRegular
                                                               : NSApplicationActivationPolicyAccessory;
    if (NSApp.activationPolicy == policy) { return; }
    BOOL ok = [NSApp setActivationPolicy:policy];
    OVCLog(OVCStr(@"显示方式切换为%@（ok=%d，当前=%ld）"),
           policy == NSApplicationActivationPolicyRegular ? OVCStr(@"Dock + 菜单栏") : OVCStr(@"仅菜单栏"),
           ok, (long)NSApp.activationPolicy);
}

/// 菜单栏被占满时，系统会把状态项排到屏幕外；此时必须在 Dock 留一个入口。
- (void)ensureStatusItemAccessible {
    [self applyActivationPolicy];
    if (self.prefs.dockIcon) { return; }
    BOOL visible = [self.status isStatusItemVisible];
    NSRect frame = [self.status statusItemFrame];
    OVCLog(OVCStr(@"状态项检测：x=%.1f y=%.1f w=%.1f h=%.1f visible=%d"),
           frame.origin.x, frame.origin.y, frame.size.width, frame.size.height, visible);
    if (visible) { return; }
    OVCLog(OVCStr(@"状态项不在屏幕内，自动显示 Dock 图标"));
    self.prefs.dockIcon = YES;
}

- (void)statusController:(OVCStatusController *)controller didToggleDockIcon:(BOOL)enabled {
    // 菜单栏已经放不下时，Dock 图标是唯一入口，不能关掉。
    if (!enabled && ![self.status isStatusItemVisible]) {
        self.prefs.dockIcon = YES;
        [self applyActivationPolicy];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = OVCStr(@"暂时不能隐藏 Dock 图标");
        alert.informativeText = OVCStr(@"菜单栏空间不足，一码的状态图标没有显示在屏幕内。Dock 图标是当前唯一入口，请先在菜单栏腾出空间再关闭。");
        [alert addButtonWithTitle:OVCStr(@"好")];
        [NSApp activateIgnoringOtherApps:YES];
        [alert runModal];
        [self.settings reload];
        OVCLog(OVCStr(@"Dock 图标隐藏被拒绝：菜单栏状态项不可见"));
        return;
    }
    self.prefs.dockIcon = enabled;
    [self applyActivationPolicy];
    OVCLog(OVCStr(@"Dock 图标已%@"), enabled ? OVCStr(@"显示") : OVCStr(@"隐藏"));
}

#pragma mark - 装配

- (void)wireSettingsCallbacks {
    __weak typeof(self) weakSelf = self;

    self.settings.onRequestFullDiskAccess = ^{
        [OVCFocusLocator openFullDiskAccessSettings];
    };
    self.settings.onRequestAccessibility = ^{
        [OVCFocusLocator promptAccessibilityIfNeeded];
        [OVCFocusLocator openAccessibilitySettings];
    };
    self.settings.onScan = ^(NSInteger hours) {
        [weakSelf performScan:hours];
    };
    self.settings.onClearHistory = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        [self.history removeAll];
        [self.settings reload];
        [self refreshStatusUI];
        OVCLog(OVCStr(@"历史记录已清空"));
    };
    self.settings.onToggleLaunchAtLogin = ^(BOOL enabled) {
        [weakSelf applyLaunchAtLogin:enabled];
    };
    self.settings.onToggleMonitoring = ^(BOOL enabled) {
        weakSelf.prefs.monitoringEnabled = enabled;
    };
    self.settings.onToggleDockIcon = ^(BOOL enabled) {
        [weakSelf statusController:weakSelf.status didToggleDockIcon:enabled];
    };
    self.settings.onQuit = ^{
        [NSApp terminate:nil];
    };
}

- (void)startMonitor {
    if (!self.prefs.monitoringEnabled) {
        OVCLog(OVCStr(@"监听处于关闭状态"));
        return;
    }
    if (self.monitor.isRunning) { return; }

    if (!self.monitor) {
        self.monitor = [[OVCMonitor alloc] init];
        __weak typeof(self) weakSelf = self;
        self.monitor.onCode = ^(OVCCode *code, OVCMessage *message) {
            [weakSelf handleCode:code message:message];
        };
        self.monitor.onStatusChange = ^(NSError *error) {
            [weakSelf handleMonitorStatus:error];
        };
    }
    [self.monitor start];
    OVCLog(OVCStr(@"监听已启动"));
}

- (void)stopMonitor {
    if (!self.monitor.isRunning) { return; }
    [self.monitor stop];
    [self.panel dismiss];
    OVCLog(OVCStr(@"监听已关闭"));
}

#pragma mark - 事件

- (void)handleCode:(OVCCode *)code message:(OVCMessage *)message {
    NSString *masked = [OVCMessageStore maskedSender:message.sender];
    NSString *service = [[message.service lowercaseString] containsString:@"sms"] ? OVCStr(@"短信") : @"iMessage";
    NSString *source = [NSString stringWithFormat:@"%@ · %@", service, masked];

    OVCLog(OVCStr(@"识别验证码（关键词 %@，来源 %@）"), code.keyword, masked);

    if (self.prefs.autoCopy) {
        OVCCopyText(code.code);
    }

    [self.history addCode:code.code sender:source messageText:message.text guid:message.guid date:[NSDate date]];
    [self refreshStatusUI];
    [self.settings reload];

    if (self.prefs.showPanel) {
        [self.panel presentCode:code.code sender:masked duration:self.prefs.panelDuration];
    }
}

- (void)handleMonitorStatus:(NSError *)error {
    if (error) {
        self.statusError = YES;
        self.lastErrorMessage = error.localizedDescription;
        OVCLog(OVCStr(@"监听异常 [%ld] %@"), (long)error.code, error.localizedDescription);
    } else {
        if (self.statusError) { OVCLog(OVCStr(@"监听恢复正常")); }
        self.statusError = NO;
        self.lastErrorMessage = nil;
    }
    [self refreshStatusUI];
}

- (void)prefsDidChange:(NSNotification *)notification {
    [self applyActivationPolicy];
    if (self.prefs.monitoringEnabled) {
        [self startMonitor];
    } else {
        [self stopMonitor];
    }
    [self refreshStatusUI];
    [self.settings reload];
}

- (void)languageDidChange:(NSNotification *)notification {
    [self.panel dismiss];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.settings reloadLocalization];
        [self.status refresh];
        [self refreshStatusUI];
    });
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self refreshStatusUI];
}

- (void)periodicRefresh:(NSTimer *)timer {
    [self refreshStatusUI];
}

- (void)refreshStatusUI {
    BOOL fda = [self.probeStore openWithError:NULL];
    BOOL ax = [OVCFocusLocator accessibilityTrusted];

    if (!self.prefs.monitoringEnabled) {
        self.statusText = OVCStr(@"监听已关闭");
        self.statusError = NO;
    } else if (!fda) {
        self.statusText = OVCStr(@"需要授权：完全磁盘访问");
        self.statusError = YES;
    } else if (self.statusError && self.lastErrorMessage.length > 0) {
        self.statusText = self.lastErrorMessage;
    } else {
        self.statusText = [NSString stringWithFormat:OVCStr(@"监听中 · 今日 %ld 条"), (long)[self todayCount]];
    }

    self.status.statusText = self.statusText;
    self.status.hasError = self.statusError;
    self.status.monitoringEnabled = self.prefs.monitoringEnabled;
    self.status.recentItems = self.history.items;
    self.status.fullDiskAccessGranted = fda;
    self.status.accessibilityGranted = ax;
    [self.status refresh];

    self.settings.statusText = self.statusText;
    self.settings.monitoringEnabled = self.prefs.monitoringEnabled;
    self.settings.fullDiskAccessGranted = fda;
    self.settings.accessibilityGranted = ax;
    self.settings.historyItems = self.history.items;

    if (fda != self.lastFDA || ax != self.lastAX) {
        self.lastFDA = fda;
        self.lastAX = ax;
        [self.settings reload];
    }
}

- (NSInteger)todayCount {
    NSDate *start = [NSCalendar.currentCalendar startOfDayForDate:[NSDate date]];
    NSTimeInterval threshold = start.timeIntervalSince1970;
    NSInteger count = 0;
    for (OVCHistoryItem *item in self.history.items) {
        if (item.date >= threshold) { count++; }
    }
    return count;
}

- (void)applyLaunchAtLogin:(BOOL)enabled {
    NSError *error = nil;
    if (![OVCLaunchAgent setEnabled:enabled error:&error]) {
        self.prefs.launchAtLogin = !enabled;
        OVCLog(OVCStr(@"开机启动设置失败：%@"), error.localizedDescription);
        [self showMessage:OVCStr(@"开机启动设置失败") info:error.localizedDescription ?: OVCStr(@"请稍后重试。")];
        return;
    }
    OVCLog(OVCStr(@"开机启动已%@"), enabled ? OVCStr(@"开启") : OVCStr(@"关闭"));
    if (enabled && [OVCLaunchAgent requiresApproval]) {
        [self showMessage:OVCStr(@"已加入登录项")
                    info:OVCStr(@"请在“系统设置 → 通用 → 登录项”中允许一码。")];
    }
}

- (void)performScan:(NSInteger)hours {
    OVCMessageStore *store = [[OVCMessageStore alloc] init];
    NSError *error = nil;
    if (![store openWithError:&error]) {
        [self showMessage:OVCStr(@"无法读取短信") info:error.localizedDescription ?: OVCStr(@"请检查“完全磁盘访问”权限。")];
        return;
    }

    NSDate *since = [NSDate dateWithTimeIntervalSinceNow:-hours * 3600.0];
    NSArray<OVCMessage *> *messages = [store fetchSinceDate:since limit:300];
    [store close];

    OVCPrefs *prefs = self.prefs;
    OVCExtractOptions options = OVCExtractOptionsDefault();
    options.minDigits = prefs.minDigits;
    options.maxDigits = prefs.maxDigits;
    options.requiresKeyword = prefs.requiresKeyword;

    NSInteger found = 0;
    for (OVCMessage *message in messages) {
        if (message.text.length == 0) { continue; }
        OVCCode *code = [OVCCodeExtractor extractFromText:message.text options:options];
        if (!code) { continue; }
        NSString *masked = [OVCMessageStore maskedSender:message.sender];
        NSString *service = [[message.service lowercaseString] containsString:@"sms"] ? OVCStr(@"短信") : @"iMessage";
        NSString *source = [NSString stringWithFormat:@"%@ · %@", service, masked];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:message.date];
        [self.history addCode:code.code sender:source messageText:message.text guid:message.guid date:date];
        found++;
    }

    [self refreshStatusUI];
    [self.settings reload];
    OVCLog(OVCStr(@"补扫 %ld 小时：%lu 条消息，识别 %ld 条验证码"), (long)hours, (unsigned long)messages.count, (long)found);

    NSString *info = found > 0
        ? [NSString stringWithFormat:OVCStr(@"最近 %ld 小时共识别到 %ld 条验证码，已加入记录。"), (long)hours, (long)found]
        : [NSString stringWithFormat:OVCStr(@"最近 %ld 小时没有识别到新的验证码。"), (long)hours];
    [self showMessage:OVCStr(@"扫描完成") info:info];
}

- (void)showMessage:(NSString *)title info:(NSString *)info {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = info;
    [alert addButtonWithTitle:OVCStr(@"好")];
    [alert runModal];
}

#pragma mark - OVCStatusControllerDelegate

- (void)statusControllerDidRequestSettings:(OVCStatusController *)controller {
    [self refreshStatusUI];
    [self.settings show];
}

- (void)statusController:(OVCStatusController *)controller didRequestSettingsSection:(NSInteger)section {
    [self refreshStatusUI];
    [self.settings showSection:section];
}

- (void)statusControllerDidRequestAbout:(OVCStatusController *)controller {
    [self refreshStatusUI];
    [self.settings showSection:5];
}

- (void)statusControllerDidRequestQuit:(OVCStatusController *)controller {
    [NSApp terminate:nil];
}

- (void)statusControllerDidRequestScan:(OVCStatusController *)controller {
    [self performScan:24];
}

- (void)statusController:(OVCStatusController *)controller didSelectRecentCode:(NSString *)code {
    OVCLog(OVCStr(@"从菜单复制验证码"));
}

- (void)statusController:(OVCStatusController *)controller didToggleMonitoring:(BOOL)enabled {
    self.prefs.monitoringEnabled = enabled;
    [self reflectMonitoringState];
}

- (void)reflectMonitoringState {
    if (!self.prefs.monitoringEnabled) {
        [self stopMonitor];
    } else {
        [self startMonitor];
    }
    [self refreshStatusUI];
    [self.settings reload];
}

- (void)statusControllerDidRequestFullDiskAccess:(OVCStatusController *)controller {
    [OVCFocusLocator openFullDiskAccessSettings];
}

- (void)statusControllerDidRequestAccessibility:(OVCStatusController *)controller {
    [OVCFocusLocator promptAccessibilityIfNeeded];
    [OVCFocusLocator openAccessibilitySettings];
}

- (void)statusController:(OVCStatusController *)controller didToggleLaunchAtLogin:(BOOL)enabled {
    [self applyLaunchAtLogin:enabled];
}

@end

#import "OVCStatusController.h"
#import "OVCLocalization.h"
#import "OVCTheme.h"
#import "OVCIconFactory.h"
#import "OVCPrefs.h"
#import "OVCHistoryStore.h"
#import "OVCFocusLocator.h"

@interface OVCStatusController () <NSMenuDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;
@end

@implementation OVCStatusController

- (instancetype)init {
    self = [super init];
    if (self) {
        _statusText = OVCStr(@"正在启动…");
        _monitoringEnabled = YES;
        _recentItems = @[];
    }
    return self;
}

- (void)install {
    if (self.statusItem) { return; }
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [OVCIconFactory statusBarImage];
    self.statusItem.button.imagePosition = NSImageOnly;
    self.statusItem.button.toolTip = OVCStr(@"一码 · 短信验证码");

    NSMenu *menu = [[NSMenu alloc] initWithTitle:OVCStr(@"一码")];
    menu.delegate = self;
    menu.autoenablesItems = NO;
    self.menu = menu;
    self.statusItem.menu = menu;
}

- (void)remove {
    if (self.statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
        self.statusItem = nil;
    }
}

- (NSRect)statusItemFrame {
    NSWindow *window = self.statusItem.button.window;
    return window ? window.frame : NSZeroRect;
}

- (BOOL)isStatusItemVisible {
    NSWindow *window = self.statusItem.button.window;
    if (!window) { return NO; }
    NSScreen *screen = window.screen ?: NSScreen.mainScreen;
    if (!screen) { return NO; }
    NSRect frame = window.frame;
    NSRect visible = screen.frame;
    return frame.origin.x >= 0 && NSMaxX(frame) <= NSMaxX(visible) && NSIntersectsRect(frame, visible);
}

- (void)refresh {
    // 菜单在下次打开时重建；这里只更新图标提示。
    self.statusItem.button.toolTip = self.statusText;
}

- (void)showPreviewMenuAtPoint:(NSPoint)point {
    if (!self.menu) {
        NSMenu *menu = [[NSMenu alloc] initWithTitle:OVCStr(@"一码")];
        menu.delegate = self;
        menu.autoenablesItems = NO;
        self.menu = menu;
    }
    [self menuNeedsUpdate:self.menu];
    [self.menu popUpMenuPositioningItem:nil atLocation:point inView:nil];
}

static NSString *OVCMenuSummary(NSString *text, NSUInteger maxLength) {
    if (text.length <= maxLength) { return text ?: @""; }
    NSRange range = [text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, maxLength - 1)];
    return [[text substringWithRange:range] stringByAppendingString:@"…"];
}

static NSImage *OVCMenuIcon(NSString *name) {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    image = [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13
                                                                                                weight:NSFontWeightRegular]];
    image.template = YES;
    return image;
}

static NSImage *OVCDotImage(NSColor *color) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(9, 9)];
    [image lockFocus];
    [color setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1.5, 1.5, 6, 6)] fill];
    [image unlockFocus];
    return image;
}

- (NSMenuItem *)addItem:(NSString *)title action:(nullable SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    [self.menu addItem:item];
    return item;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];

    NSColor *dotColor = !self.monitoringEnabled
        ? OVCColor(OVCColorTokenTextTertiary)
        : (self.hasError ? OVCColor(OVCColorTokenDanger) : OVCColor(OVCColorTokenSuccess));
    NSMenuItem *status = [[NSMenuItem alloc] initWithTitle:self.statusText action:nil keyEquivalent:@""];
    status.enabled = NO;
    status.image = OVCDotImage(dotColor);
    [menu addItem:status];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *monitor = [self addItem:OVCStr(@"监听短信") action:@selector(toggleMonitoring:) key:@""];
    monitor.image = OVCMenuIcon(@"antenna.radiowaves.left.and.right");
    monitor.state = self.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *scan = [self addItem:OVCStr(@"扫描最近 24 小时") action:@selector(scanNow:) key:@""];
    scan.image = OVCMenuIcon(@"arrow.clockwise");

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *recent = [[NSMenuItem alloc] initWithTitle:OVCStr(@"最近验证码") action:nil keyEquivalent:@""];
    recent.image = OVCMenuIcon(@"clock.arrow.circlepath");
    NSMenu *recentMenu = [[NSMenu alloc] initWithTitle:OVCStr(@"最近验证码")];
    recentMenu.autoenablesItems = NO;
    if (self.recentItems.count == 0) {
        NSMenuItem *empty = [[NSMenuItem alloc] initWithTitle:OVCStr(@"还没有记录") action:nil keyEquivalent:@""];
        empty.enabled = NO;
        [recentMenu addItem:empty];
    } else {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm";
        NSUInteger limit = MIN(self.recentItems.count, (NSUInteger)5);
        for (NSUInteger i = 0; i < limit; i++) {
            OVCHistoryItem *item = self.recentItems[i];
            NSString *time = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:item.date]];
            NSString *summary = item.summary.length > 0 ? OVCMenuSummary(item.summary, 18) : time;
            NSString *title = [NSString stringWithFormat:@"%@   %@", item.code, summary];
            NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:title
                                                           action:@selector(copyRecent:)
                                                    keyEquivalent:@""];
            entry.target = self;
            entry.representedObject = item.code;
            entry.toolTip = [NSString stringWithFormat:@"%@ · %@", item.sender ?: OVCStr(@"未知来源"), time];
            [recentMenu addItem:entry];
        }
        [recentMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *all = [[NSMenuItem alloc] initWithTitle:OVCStr(@"查看全部记录…") action:@selector(openRecords:) keyEquivalent:@""];
        all.target = self;
        [recentMenu addItem:all];
    }
    recent.submenu = recentMenu;
    [menu addItem:recent];

    [menu addItem:[NSMenuItem separatorItem]];

    OVCPrefs *prefs = [OVCPrefs shared];
    NSMenuItem *autoCopy = [self addItem:OVCStr(@"自动复制到剪贴板") action:@selector(toggleAutoCopy:) key:@""];
    autoCopy.image = OVCMenuIcon(@"doc.on.doc");
    autoCopy.state = prefs.autoCopy ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *panel = [self addItem:OVCStr(@"在输入框旁弹出提示") action:@selector(togglePanel:) key:@""];
    panel.image = OVCMenuIcon(@"rectangle.on.rectangle");
    panel.state = prefs.showPanel ? NSControlStateValueOn : NSControlStateValueOff;

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settings = [self addItem:OVCStr(@"设置…") action:@selector(openSettings:) key:@","];
    settings.image = OVCMenuIcon(@"gearshape");

    NSMenuItem *about = [self addItem:OVCStr(@"关于一码") action:@selector(openAbout:) key:@""];
    about.image = OVCMenuIcon(@"info.circle");

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [self addItem:OVCStr(@"退出一码") action:@selector(quit:) key:@"q"];
    quit.image = OVCMenuIcon(@"power");
}

- (void)toggleMonitoring:(NSMenuItem *)sender {
    BOOL enabled = sender.state != NSControlStateValueOn;
    if ([self.delegate respondsToSelector:@selector(statusController:didToggleMonitoring:)]) {
        [self.delegate statusController:self didToggleMonitoring:enabled];
    }
}

- (void)toggleAutoCopy:(NSMenuItem *)sender {
    OVCPrefs *prefs = [OVCPrefs shared];
    prefs.autoCopy = !prefs.autoCopy;
    [self refresh];
}

- (void)togglePanel:(NSMenuItem *)sender {
    OVCPrefs *prefs = [OVCPrefs shared];
    prefs.showPanel = !prefs.showPanel;
    [self refresh];
}

- (void)toggleDockIcon:(NSMenuItem *)sender {
    BOOL enabled = sender.state != NSControlStateValueOn;
    [self.delegate statusController:self didToggleDockIcon:enabled];
}

- (void)toggleLaunchAtLogin:(NSMenuItem *)sender {
    OVCPrefs *prefs = [OVCPrefs shared];
    BOOL next = !prefs.launchAtLogin;
    prefs.launchAtLogin = next;
    if ([self.delegate respondsToSelector:@selector(statusController:didToggleLaunchAtLogin:)]) {
        [self.delegate statusController:self didToggleLaunchAtLogin:next];
    }
    [self refresh];
}

- (void)copyRecent:(NSMenuItem *)sender {
    NSString *code = sender.representedObject;
    if (![code isKindOfClass:[NSString class]] || code.length == 0) { return; }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:code forType:NSPasteboardTypeString];
    if ([self.delegate respondsToSelector:@selector(statusController:didSelectRecentCode:)]) {
        [self.delegate statusController:self didSelectRecentCode:code];
    }
}

- (void)scanNow:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusControllerDidRequestScan:)]) {
        [self.delegate statusControllerDidRequestScan:self];
    }
}

- (void)openSettings:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusControllerDidRequestSettings:)]) {
        [self.delegate statusControllerDidRequestSettings:self];
    }
}

- (void)openRecords:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusController:didRequestSettingsSection:)]) {
        [self.delegate statusController:self didRequestSettingsSection:4];
    }
}

- (void)openAbout:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusControllerDidRequestAbout:)]) {
        [self.delegate statusControllerDidRequestAbout:self];
    }
}

- (void)openFullDiskAccess:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusControllerDidRequestFullDiskAccess:)]) {
        [self.delegate statusControllerDidRequestFullDiskAccess:self];
    }
}

- (void)openAccessibility:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusControllerDidRequestAccessibility:)]) {
        [self.delegate statusControllerDidRequestAccessibility:self];
    }
}

- (void)quit:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(statusControllerDidRequestQuit:)]) {
        [self.delegate statusControllerDidRequestQuit:self];
    }
}

@end

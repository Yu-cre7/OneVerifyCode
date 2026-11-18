#import "OVCRenderDump.h"
#import "OVCSettingsWindow.h"
#import "OVCHistoryStore.h"
#import "OVCPanelController.h"
#import "OVCIconFactory.h"
#import "OVCTheme.h"
#import "OVCLocalization.h"
#import "OVCPrefs.h"

#pragma mark - 离屏容器

@interface OVCBackdropView : NSView
@end

@implementation OVCBackdropView

- (void)drawRect:(NSRect)dirtyRect {
    [OVCColor(OVCColorTokenSurfaceAlt) setFill];
    NSRectFill(self.bounds);
}

@end

static BOOL OVCWritePNG(NSBitmapImageRep *rep, NSString *path) {
    if (!rep) { return NO; }
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return png != nil && [png writeToFile:path atomically:YES];
}

static NSBitmapImageRep *OVCCapture(NSView *view) {
    [view layoutSubtreeIfNeeded];
    NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    if (!rep) { return nil; }
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
    return rep;
}

static NSWindow *OVCOffscreenWindow(NSView *view, NSAppearanceName appearanceName) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:view.bounds
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.appearance = [NSAppearance appearanceNamed:appearanceName];
    window.contentView = view;
    [window setFrameOrigin:NSMakePoint(-30000, -30000)];
    [window orderFront:nil];
    [view layoutSubtreeIfNeeded];
    return window;
}

static NSArray<OVCHistoryItem *> *OVCSampleHistory(void) {
    NSArray<NSString *> *codes = @[@"482913", @"7264", @"193847"];
    NSArray<NSString *> *sources = @[OVCStr(@"短信 · 1069****01"), OVCStr(@"短信 · 9558**"), @"iMessage · hu***@icloud.com"];
    NSArray<NSString *> *summaries = @[OVCStr(@"【快手科技】您的验证码为：••••••，5 分钟…"), OVCStr(@"【京东】您的验证码为：••••，请勿泄露…"), OVCStr(@"您的 Apple ID 验证码为：••••••，请勿…")];
    NSMutableArray<OVCHistoryItem *> *items = [NSMutableArray array];
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    for (NSInteger i = 0; i < 3; i++) {
        OVCHistoryItem *item = [OVCHistoryItem new];
        item.code = codes[(NSUInteger)i];
        item.sender = sources[(NSUInteger)i];
        item.summary = summaries[(NSUInteger)i];
        item.date = now - 180 - i * 1500;
        item.guid = [NSString stringWithFormat:@"demo-%ld", (long)i];
        [items addObject:item];
    }
    return items;
}

int OVCRenderPreviews(NSString *directory) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) { return 1; }

    OVCPrefs *prefs = [OVCPrefs shared];
    prefs.monitoringEnabled = YES;
    prefs.autoCopy = YES;
    prefs.showPanel = YES;
    prefs.panelTheme = OVCPanelThemeAurora;
    prefs.panelSize = OVCPanelSizeStandard;
    prefs.panelTransparency = 0.28;
    prefs.panelDuration = 8.0;

    OVCSettingsWindow *settings = [[OVCSettingsWindow alloc] init];
    settings.historyItems = OVCSampleHistory();
    settings.fullDiskAccessGranted = YES;
    settings.accessibilityGranted = YES;
    settings.monitoringEnabled = YES;
    settings.statusText = OVCStr(@"监听中 · 今日 3 条");

    NSArray<NSArray<NSString *> *> *pages = @[
        @[@"0", @"settings-permission-light.png", NSAppearanceNameAqua],
        @[@"1", @"settings-behavior-light.png", NSAppearanceNameAqua],
        @[@"2", @"settings-appearance-light.png", NSAppearanceNameAqua],
        @[@"3", @"settings-rules-light.png", NSAppearanceNameAqua],
        @[@"4", @"settings-records-light.png", NSAppearanceNameAqua],
        @[@"5", @"settings-about-light.png", NSAppearanceNameAqua],
        @[@"0", @"settings-permission-dark.png", NSAppearanceNameDarkAqua],
        @[@"1", @"settings-behavior-dark.png", NSAppearanceNameDarkAqua],
        @[@"2", @"settings-appearance-dark.png", NSAppearanceNameDarkAqua],
        @[@"3", @"settings-rules-dark.png", NSAppearanceNameDarkAqua],
        @[@"4", @"settings-records-dark.png", NSAppearanceNameDarkAqua],
        @[@"5", @"settings-about-dark.png", NSAppearanceNameDarkAqua],
    ];
    for (NSArray<NSString *> *page in pages) {
        NSView *view = [settings previewContentViewWithAppearance:page[2] section:page[0].integerValue];
        NSWindow *window = OVCOffscreenWindow(view, page[2]);
        if (!OVCWritePNG(OVCCapture(view), [directory stringByAppendingPathComponent:page[1]])) { return 1; }
        [window orderOut:nil];
    }

    OVCSettingsWindow *permission = [[OVCSettingsWindow alloc] init];
    permission.historyItems = OVCSampleHistory();
    permission.fullDiskAccessGranted = NO;
    permission.accessibilityGranted = NO;
    permission.monitoringEnabled = YES;
    permission.statusText = OVCStr(@"需要授权：完全磁盘访问");
    NSView *permissionView = [permission previewContentViewWithAppearance:NSAppearanceNameAqua section:0];
    NSWindow *permissionWindow = OVCOffscreenWindow(permissionView, NSAppearanceNameAqua);
    if (!OVCWritePNG(OVCCapture(permissionView),
                     [directory stringByAppendingPathComponent:@"settings-permission-needed-light.png"])) {
        return 1;
    }
    [permissionWindow orderOut:nil];

    NSView *permissionDarkView = [permission previewContentViewWithAppearance:NSAppearanceNameDarkAqua section:0];
    NSWindow *permissionDarkWindow = OVCOffscreenWindow(permissionDarkView, NSAppearanceNameDarkAqua);
    if (!OVCWritePNG(OVCCapture(permissionDarkView),
                     [directory stringByAppendingPathComponent:@"settings-permission-needed-dark.png"])) {
        return 1;
    }
    [permissionDarkWindow orderOut:nil];

    OVCSettingsWindow *off = [[OVCSettingsWindow alloc] init];
    off.historyItems = OVCSampleHistory();
    off.fullDiskAccessGranted = YES;
    off.accessibilityGranted = YES;
    off.monitoringEnabled = NO;
    off.statusText = OVCStr(@"监听已关闭");
    NSView *offView = [off previewContentViewWithAppearance:NSAppearanceNameAqua section:1];
    NSWindow *offWindow = OVCOffscreenWindow(offView, NSAppearanceNameAqua);
    if (!OVCWritePNG(OVCCapture(offView),
                     [directory stringByAppendingPathComponent:@"settings-monitoring-off-light.png"])) {
        return 1;
    }
    [offWindow orderOut:nil];

    OVCSettingsWindow *empty = [[OVCSettingsWindow alloc] init];
    empty.historyItems = @[];
    empty.fullDiskAccessGranted = YES;
    empty.accessibilityGranted = YES;
    empty.monitoringEnabled = YES;
    empty.statusText = OVCStr(@"监听中 · 今日 0 条");
    NSView *emptyView = [empty previewContentViewWithAppearance:NSAppearanceNameAqua section:4];
    NSWindow *emptyWindow = OVCOffscreenWindow(emptyView, NSAppearanceNameAqua);
    if (!OVCWritePNG(OVCCapture(emptyView),
                     [directory stringByAppendingPathComponent:@"settings-records-empty-light.png"])) {
        return 1;
    }
    [emptyWindow orderOut:nil];

    OVCPanelController *panel = [[OVCPanelController alloc] init];
    NSArray<NSString *> *themeNames = @[@"aurora", @"twilight", @"mint", @"amber", @"graphite", @"white", @"black"];
    for (NSInteger theme = 0; theme < OVCPanelThemeCount; theme++) {
        NSView *card = [panel previewViewWithCode:@"482913"
                                          sender:@"1069***213"
                                         seconds:8
                                           theme:(OVCPanelTheme)theme
                                            size:OVCPanelSizeStandard
                                    transparency:0.12];
        OVCBackdropView *backdrop = [[OVCBackdropView alloc] initWithFrame:NSMakeRect(0, 0, card.frame.size.width + 40, card.frame.size.height + 40)];
        card.frame = NSMakeRect(20, 20, card.frame.size.width, card.frame.size.height);
        [backdrop addSubview:card];
        NSString *name = [NSString stringWithFormat:@"panel-%@-light.png", themeNames[(NSUInteger)theme]];
        NSWindow *window = OVCOffscreenWindow(backdrop, NSAppearanceNameAqua);
        if (!OVCWritePNG(OVCCapture(backdrop), [directory stringByAppendingPathComponent:name])) { return 1; }
        [window orderOut:nil];
    }
    for (NSInteger theme = 0; theme < OVCPanelThemeCount; theme += 1) {
        NSView *card = [panel previewViewWithCode:@"482913"
                                          sender:@"1069***213"
                                         seconds:8
                                           theme:(OVCPanelTheme)theme
                                            size:OVCPanelSizeStandard
                                    transparency:0.20];
        OVCBackdropView *backdrop = [[OVCBackdropView alloc] initWithFrame:NSMakeRect(0, 0, card.frame.size.width + 40, card.frame.size.height + 40)];
        card.frame = NSMakeRect(20, 20, card.frame.size.width, card.frame.size.height);
        [backdrop addSubview:card];
        NSString *name = [NSString stringWithFormat:@"panel-%@-dark.png", themeNames[(NSUInteger)theme]];
        NSWindow *window = OVCOffscreenWindow(backdrop, NSAppearanceNameDarkAqua);
        if (!OVCWritePNG(OVCCapture(backdrop), [directory stringByAppendingPathComponent:name])) { return 1; }
        [window orderOut:nil];
    }
    for (NSArray<NSString *> *pair in @[@[NSAppearanceNameAqua, @"panel-light.png"],
                                        @[NSAppearanceNameDarkAqua, @"panel-dark.png"]]) {
        NSView *card = [panel previewViewWithCode:@"482913"
                                          sender:@"1069***213"
                                         seconds:8
                                           theme:OVCPanelThemeAurora
                                            size:OVCPanelSizeStandard
                                    transparency:0.12];
        OVCBackdropView *backdrop = [[OVCBackdropView alloc] initWithFrame:NSMakeRect(0, 0, card.frame.size.width + 40, card.frame.size.height + 40)];
        card.frame = NSMakeRect(20, 20, card.frame.size.width, card.frame.size.height);
        [backdrop addSubview:card];
        NSWindow *window = OVCOffscreenWindow(backdrop, pair[0]);
        if (!OVCWritePNG(OVCCapture(backdrop), [directory stringByAppendingPathComponent:pair[1]])) { return 1; }
        [window orderOut:nil];
    }

    for (NSInteger size = 0; size < OVCPanelSizeCount; size++) {
        NSView *card = [panel previewViewWithCode:@"482913"
                                          sender:@"1069***213"
                                         seconds:8
                                           theme:OVCPanelThemeAurora
                                            size:(OVCPanelSizePreset)size
                                    transparency:0.12];
        OVCBackdropView *backdrop = [[OVCBackdropView alloc] initWithFrame:NSMakeRect(0, 0, card.frame.size.width + 40, card.frame.size.height + 40)];
        card.frame = NSMakeRect(20, 20, card.frame.size.width, card.frame.size.height);
        [backdrop addSubview:card];
        NSString *name = [NSString stringWithFormat:@"panel-size-%@.png", OVCPanelSizeName((OVCPanelSizePreset)size)];
        NSWindow *window = OVCOffscreenWindow(backdrop, NSAppearanceNameAqua);
        if (!OVCWritePNG(OVCCapture(backdrop), [directory stringByAppendingPathComponent:name])) { return 1; }
        [window orderOut:nil];
    }

    NSURL *iconURL = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"icon-1024.png"]];
    if (![OVCIconFactory writeAppIconPNGToURL:iconURL pixelSize:1024 error:&error]) { return 1; }

    NSURL *statusURL = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"statusbar@4x.png"]];
    if (![OVCIconFactory writeStatusBarPNGToURL:statusURL scale:4.0 error:&error]) { return 1; }

    return 0;
}

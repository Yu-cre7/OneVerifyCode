#import "OVCPanelController.h"
#import "OVCLocalization.h"
#import "OVCTheme.h"
#import "OVCPrefs.h"
#import "OVCFocusLocator.h"
#import <QuartzCore/QuartzCore.h>

static NSImage *OVCPanelMaskImage(NSSize size, CGFloat radius) {
    return [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [[NSColor blackColor] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];
        return YES;
    }];
}

#pragma mark - 卡片内容

@interface OVCPanelContentView : NSView
@property (nonatomic, strong) NSTextField *sourceLabel;
@property (nonatomic, strong) NSTextField *codeLabel;
@property (nonatomic, copy) NSString *codeString;
@property (nonatomic, assign) OVCPanelTheme theme;
@property (nonatomic, assign) OVCPanelSizePreset sizePreset;
@property (nonatomic, assign) CGFloat backgroundOpacity;
@property (nonatomic, assign) CGFloat progress;   // 1 → 0
@property (nonatomic, assign) BOOL pressed;
@property (nonatomic, copy, nullable) void (^onActivate)(void);
- (void)applyTheme;
@end

@implementation OVCPanelContentView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = OVCPanelThemeAurora;
        _sizePreset = OVCPanelSizeStandard;
        _backgroundOpacity = 0.88;
        _sourceLabel = [NSTextField labelWithString:OVCStr(@"一码")];
        _sourceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _sourceLabel.alignment = NSTextAlignmentCenter;
        _codeLabel = [NSTextField labelWithString:@""];
        _codeLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _codeLabel.alignment = NSTextAlignmentCenter;
        [self addSubview:_sourceLabel];
        [self addSubview:_codeLabel];
        _progress = 1.0;
        [self applyTheme];
    }
    return self;
}

- (BOOL)isFlipped { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)applyTheme {
    CGFloat sourceSize = OVCPanelSourceFontSizeForPreset(self.sizePreset);
    CGFloat codeSize = OVCPanelCodeFontSizeForPreset(self.sizePreset);
    self.sourceLabel.font = [NSFont systemFontOfSize:sourceSize weight:NSFontWeightMedium];
    self.sourceLabel.textColor = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextSecondary);
    self.codeLabel.font = [NSFont monospacedSystemFontOfSize:codeSize weight:NSFontWeightSemibold];
    self.codeLabel.textColor = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextPrimary);
    [self refreshCodeStyle];
    [self setNeedsLayout:YES];
    [self setNeedsDisplay:YES];
}

- (void)refreshCodeStyle {
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraph.alignment = NSTextAlignmentCenter;
    CGFloat codeSize = OVCPanelCodeFontSizeForPreset(self.sizePreset);
    NSAttributedString *codeText = [[NSAttributedString alloc] initWithString:self.codeString ?: @""
                                                                   attributes:@{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:codeSize weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextPrimary),
        NSKernAttributeName: @(codeSize * 0.08),
        NSParagraphStyleAttributeName: paragraph,
    }];
    self.codeLabel.attributedStringValue = codeText;
}

- (void)setCodeString:(NSString *)codeString {
    _codeString = [codeString copy];
    [self refreshCodeStyle];
}

- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGFloat codeSize = OVCPanelCodeFontSizeForPreset(self.sizePreset);
    CGFloat sourceSize = OVCPanelSourceFontSizeForPreset(self.sizePreset);
    CGFloat codeHeight = ceil(codeSize * 1.18) + 8;
    CGFloat sourceHeight = ceil(sourceSize * 1.3) + 2;
    CGFloat gap = 3;
    CGFloat contentHeight = codeHeight + gap + sourceHeight;
    CGFloat codeY = floor((height - contentHeight) / 2) + 2;
    CGFloat sourceY = codeY + codeHeight + gap;
    self.codeLabel.frame = NSMakeRect(8, codeY, width - 16, codeHeight);
    self.sourceLabel.frame = NSMakeRect(10, sourceY, width - 20, sourceHeight);
    [self.window invalidateCursorRectsForView:self];
}

- (NSRect)codeRect {
    return NSInsetRect(self.codeLabel.frame, -8, -7);
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:[self codeRect] cursor:NSCursor.pointingHandCursor];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (NSPointInRect(point, [self codeRect])) {
        self.pressed = YES;
        [self setNeedsDisplay:YES];
        return;
    }
    [super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event {
    if (!self.pressed) { return; }
    self.pressed = NO;
    [self setNeedsDisplay:YES];
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (NSPointInRect(point, [self codeRect]) && self.onActivate) {
        // 等本轮鼠标事件结束再收起卡片，避免 mouseUp 落到下层 App。
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onActivate();
        });
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    CGFloat radius = OVCPanelCornerRadiusForPreset(self.sizePreset);
    NSRect card = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:card xRadius:radius yRadius:radius];

    CGFloat opacity = self.pressed ? MIN(1.0, self.backgroundOpacity + 0.08) : self.backgroundOpacity;
    if (OVCPanelThemeUsesOpaqueBackground(self.theme)) { opacity = 1.0; }
    NSColor *start = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientStart);
    NSColor *end = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientEnd);
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[start colorWithAlphaComponent:opacity]
                                                        endingColor:[end colorWithAlphaComponent:opacity]];
    [gradient drawInBezierPath:path angle:-48];

    // 纯白/纯黑保持干净，不叠加主题柔光。
    BOOL pure = OVCPanelThemeUsesOpaqueBackground(self.theme);
    NSColor *accent = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleAccent);
    if (!pure) {
        NSGradient *glow = [[NSGradient alloc] initWithStartingColor:[accent colorWithAlphaComponent:0.16 * opacity]
                                                         endingColor:[accent colorWithAlphaComponent:0.0]];
        [glow drawInBezierPath:path relativeCenterPosition:NSMakePoint(-0.58, 0.62)];
    }

    NSColor *highlight = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleHighlight);
    [[highlight colorWithAlphaComponent:0.34 * opacity] setStroke];
    path.lineWidth = 1.0;
    [path stroke];

    // 底部自动关闭进度条
    CGFloat barHeight = 2.5;
    NSRect track = NSMakeRect(14, 6, self.bounds.size.width - 28, barHeight);
    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:track
                                                              xRadius:barHeight / 2
                                                              yRadius:barHeight / 2];
    [[OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextPrimary) colorWithAlphaComponent:0.10] setFill];
    [trackPath fill];

    CGFloat progress = MAX(0.0, MIN(1.0, self.progress));
    if (progress > 0.001) {
        NSRect fillRect = track;
        fillRect.size.width = track.size.width * progress;
        NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect
                                                                 xRadius:barHeight / 2
                                                                 yRadius:barHeight / 2];
        [accent setFill];
        [fillPath fill];
    }
}

@end

#pragma mark - 无边框面板

@interface OVCFloatingPanel : NSPanel
@end

@implementation OVCFloatingPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
- (BOOL)isFloatingPanel { return YES; }
- (BOOL)becomesKeyOnlyIfNeeded { return YES; }
@end

#pragma mark - 控制器

@interface OVCPanelController ()
@property (nonatomic, strong, nullable) OVCFloatingPanel *panel;
@property (nonatomic, strong, nullable) NSVisualEffectView *effectView;
@property (nonatomic, strong, nullable) OVCPanelContentView *contentView;
@property (nonatomic, strong, nullable) NSTimer *timer;
@property (nonatomic, assign) NSTimeInterval remaining;
@property (nonatomic, assign) NSTimeInterval total;
@property (nonatomic, copy, nullable) NSString *currentCode;
@property (nonatomic, strong, nullable) NSRunningApplication *targetApp;
@end

@implementation OVCPanelController

- (void)dealloc {
    [_timer invalidate];
}

- (void)applyPreferencesToView:(OVCPanelContentView *)view {
    OVCPrefs *prefs = [OVCPrefs shared];
    view.theme = (OVCPanelTheme)prefs.panelTheme;
    view.sizePreset = (OVCPanelSizePreset)prefs.panelSize;
    view.backgroundOpacity = 1.0 - prefs.panelTransparency;
    [view applyTheme];
}

- (OVCPanelContentView *)buildContentViewWithTheme:(OVCPanelTheme)theme
                                              size:(OVCPanelSizePreset)size
                                      transparency:(double)transparency {
    NSSize panelSize = OVCPanelSizeForPreset(size);
    OVCPanelContentView *view = [[OVCPanelContentView alloc] initWithFrame:NSMakeRect(0, 0, panelSize.width, panelSize.height)];
    view.theme = theme;
    view.sizePreset = size;
    view.backgroundOpacity = 1.0 - transparency;
    [view applyTheme];
    __weak typeof(self) weakSelf = self;
    view.onActivate = ^{
        [weakSelf handleActivate];
    };
    return view;
}

- (OVCPanelContentView *)buildContentView {
    OVCPrefs *prefs = [OVCPrefs shared];
    return [self buildContentViewWithTheme:(OVCPanelTheme)prefs.panelTheme
                                      size:(OVCPanelSizePreset)prefs.panelSize
                              transparency:prefs.panelTransparency];
}

- (void)ensurePanel {
    if (self.panel) { return; }

    OVCPrefs *prefs = [OVCPrefs shared];
    NSSize panelSize = OVCPanelSizeForPreset((OVCPanelSizePreset)prefs.panelSize);
    CGFloat radius = OVCPanelCornerRadiusForPreset((OVCPanelSizePreset)prefs.panelSize);

    OVCFloatingPanel *panel = [[OVCFloatingPanel alloc] initWithContentRect:NSMakeRect(0, 0, panelSize.width, panelSize.height)
                                                                  styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                                    backing:NSBackingStoreBuffered
                                                                      defer:NO];
    panel.opaque = NO;
    panel.backgroundColor = [NSColor clearColor];
    panel.hasShadow = NO;
    panel.level = NSStatusWindowLevel;
    panel.hidesOnDeactivate = NO;
    panel.movableByWindowBackground = NO;
    panel.acceptsMouseMovedEvents = YES;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                               NSWindowCollectionBehaviorFullScreenAuxiliary |
                               NSWindowCollectionBehaviorStationary;
    panel.animationBehavior = NSWindowAnimationBehaviorNone;

    NSVisualEffectView *effect = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, panelSize.width, panelSize.height)];
    effect.material = NSVisualEffectMaterialPopover;
    effect.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effect.state = NSVisualEffectStateActive;
    effect.wantsLayer = YES;
    effect.maskImage = OVCPanelMaskImage(panelSize, radius);
    effect.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    OVCPanelContentView *view = [self buildContentView];
    view.frame = effect.bounds;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [effect addSubview:view];

    panel.contentView = effect;
    self.panel = panel;
    self.effectView = effect;
    self.contentView = view;
}

- (void)updatePanelGeometry {
    if (!self.panel || !self.contentView) { return; }
    OVCPrefs *prefs = [OVCPrefs shared];
    OVCPanelSizePreset preset = (OVCPanelSizePreset)prefs.panelSize;
    NSSize size = OVCPanelSizeForPreset(preset);
    CGFloat radius = OVCPanelCornerRadiusForPreset(preset);
    NSRect frame = self.panel.frame;
    if (!NSEqualSizes(frame.size, size)) {
        frame.size = size;
        [self.panel setFrame:frame display:NO];
    }
    self.effectView.frame = NSMakeRect(0, 0, size.width, size.height);
    self.effectView.maskImage = OVCPanelMaskImage(size, radius);
    self.contentView.frame = self.effectView.bounds;
    [self applyPreferencesToView:self.contentView];
}

- (void)configureView:(OVCPanelContentView *)view code:(NSString *)code sender:(NSString *)sender {
    if (!view) { return; }
    NSString *source = sender.length > 0 ? [NSString stringWithFormat:OVCStr(@"一码 · %@"), sender] : OVCStr(@"一码");
    view.sourceLabel.stringValue = source;
    view.codeString = code ?: @"";
    [view applyTheme];
}

- (void)presentCode:(NSString *)code sender:(NSString *)sender duration:(NSTimeInterval)duration {
    if (code.length == 0) { return; }
    [self ensurePanel];
    [self updatePanelGeometry];
    [self configureView:self.contentView code:code sender:sender];

    self.currentCode = code;
    self.total = MAX(1.0, duration);
    self.remaining = self.total;
    self.contentView.progress = 1.0;
    [self.contentView setNeedsDisplay:YES];

    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    NSString *ownBundle = NSBundle.mainBundle.bundleIdentifier;
    self.targetApp = ([front.bundleIdentifier isEqualToString:ownBundle]) ? nil : front;

    [self positionPanel];
    [self.panel setAlphaValue:0.0];
    [self.panel orderFrontRegardless];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = OVCPanelInDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        self.panel.animator.alphaValue = 1.0;
    } completionHandler:nil];

    [self startCountdown];
}

- (void)startCountdown {
    [self.timer invalidate];
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { [timer invalidate]; return; }
        self.remaining -= 0.05;
        if (self.remaining <= 0) {
            [timer invalidate];
            self.timer = nil;
            [self dismiss];
            return;
        }
        self.contentView.progress = (CGFloat)(self.remaining / MAX(0.05, self.total));
        [self.contentView setNeedsDisplay:YES];
    }];
}

- (void)positionPanel {
    if (!self.panel) { return; }
    NSSize size = self.panel.frame.size;
    CGRect focus = [OVCFocusLocator focusedTextInputRect];
    NSScreen *screen = nil;
    NSPoint origin = NSZeroPoint;

    if (!CGRectIsEmpty(focus)) {
        screen = [self screenForRect:focus];
        CGFloat x = focus.origin.x;
        CGFloat y = focus.origin.y - size.height - 8.0;
        NSRect visible = screen.visibleFrame;
        if (y < visible.origin.y + 8.0) {
            y = CGRectGetMaxY(focus) + 8.0;
        }
        origin = NSMakePoint(x, y);
    } else {
        screen = [NSScreen mainScreen] ?: NSScreen.screens.firstObject;
        NSPoint mouse = NSEvent.mouseLocation;
        origin = NSMakePoint(mouse.x + 12.0, mouse.y - size.height - 12.0);
    }

    if (!screen) { screen = NSScreen.screens.firstObject; }
    NSRect visible = screen.visibleFrame;
    origin.x = MIN(MAX(origin.x, visible.origin.x + 8.0), NSMaxX(visible) - size.width - 8.0);
    origin.y = MIN(MAX(origin.y, visible.origin.y + 8.0), NSMaxY(visible) - size.height - 8.0);

    [self.panel setFrame:NSMakeRect(round(origin.x), round(origin.y), size.width, size.height) display:YES];
}

- (NSScreen *)screenForRect:(CGRect)rect {
    for (NSScreen *screen in NSScreen.screens) {
        if (CGRectIntersectsRect(screen.frame, rect)) { return screen; }
    }
    return [NSScreen mainScreen] ?: NSScreen.screens.firstObject;
}

- (void)dismiss {
    [self.timer invalidate];
    self.timer = nil;
    self.remaining = 0;
    if (!self.panel || !self.panel.isVisible) { return; }

    OVCFloatingPanel *panel = self.panel;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = OVCPanelOutDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        panel.animator.alphaValue = 0.0;
    } completionHandler:^{
        [panel orderOut:nil];
    }];
}

- (void)copyToPasteboard {
    if (self.currentCode.length == 0) { return; }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:self.currentCode forType:NSPasteboardTypeString];
}

- (void)handleActivate {
    NSString *code = [self.currentCode copy];
    if (code.length == 0) { return; }
    [self copyToPasteboard];

    NSRunningApplication *target = self.targetApp;
    BOOL trusted = [OVCFocusLocator accessibilityTrusted];
    [self dismiss];

    if (!trusted) {
        [OVCFocusLocator promptAccessibilityIfNeeded];
        [self showAccessibilityAlert];
        return;
    }

    if (target && !target.isTerminated && !target.isActive) {
        [target activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [OVCFocusLocator sendPasteShortcut];
    });
}

- (void)showAccessibilityAlert {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = OVCStr(@"需要“辅助功能”权限");
    alert.informativeText = OVCStr(@"一码已把验证码复制到剪贴板。若要点击验证码自动填入，请在“系统设置 → 隐私与安全性 → 辅助功能”中勾选一码，然后重试。");
    [alert addButtonWithTitle:OVCStr(@"打开系统设置")];
    [alert addButtonWithTitle:OVCStr(@"好")];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [OVCFocusLocator openAccessibilitySettings];
    }
}

- (NSView *)previewViewWithCode:(NSString *)code sender:(NSString *)sender seconds:(NSInteger)seconds {
    OVCPrefs *prefs = [OVCPrefs shared];
    return [self previewViewWithCode:code
                              sender:sender
                             seconds:seconds
                               theme:(OVCPanelTheme)prefs.panelTheme
                                size:(OVCPanelSizePreset)prefs.panelSize
                        transparency:prefs.panelTransparency];
}

- (NSView *)previewViewWithCode:(NSString *)code
                         sender:(NSString *)sender
                        seconds:(NSInteger)seconds
                          theme:(OVCPanelTheme)theme
                           size:(OVCPanelSizePreset)size
                   transparency:(double)transparency {
    OVCPanelContentView *view = [self buildContentViewWithTheme:theme size:size transparency:transparency];
    [self configureView:view code:code sender:sender];
    view.progress = 1.0;
    [view layoutSubtreeIfNeeded];
    return view;
}

@end

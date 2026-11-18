#import "OVCSettingsWindow.h"
#import "OVCLocalization.h"
#import "OVCTheme.h"
#import "OVCIconFactory.h"
#import "OVCPrefs.h"
#import "OVCHistoryStore.h"
#import "OVCFocusLocator.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat OVCWindowWidth = 820.0;
static const CGFloat OVCWindowHeight = 600.0;
static const CGFloat OVCSidebarWidth = 220.0;
static const CGFloat OVCPageInset = 24.0;
static const CGFloat OVCPageWidth = 552.0;
static const CGFloat OVCPageHeight = 480.0;
static NSString * const OVCGitHubRepositoryURL = @"https://github.com/Yu-cre7/OneVerifyCode";
static NSString * const OVCGitHubRepositoryDisplay = @"github.com/Yu-cre7/OneVerifyCode";

static NSTextField *OVCMakeLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:OVCStr(text ?: @"")];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.maximumNumberOfLines = 1;
    label.usesSingleLineMode = YES;
    label.cell.truncatesLastVisibleLine = YES;
    return label;
}

static NSTextField *OVCMakeMultilineLabel(NSString *text, NSFont *font, NSColor *color, NSInteger lines) {
    NSTextField *label = OVCMakeLabel(text, font, color);
    label.maximumNumberOfLines = lines;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.usesSingleLineMode = NO;
    label.cell.wraps = YES;
    return label;
}

static NSImageView *OVCMakeSymbol(NSString *name, CGFloat size, NSColor *color) {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:size
                                                                                        weight:NSFontWeightMedium];
    image = [image imageWithSymbolConfiguration:config];
    NSImageView *view = [[NSImageView alloc] initWithFrame:NSZeroRect];
    view.image = image;
    view.contentTintColor = color;
    view.imageScaling = NSImageScaleProportionallyUpOrDown;
    return view;
}

static NSButton *OVCMakeButton(NSString *title, id target, SEL action) {
    NSButton *button = [NSButton buttonWithTitle:OVCStr(title) target:target action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeSmall;
    button.font = OVCFontCaptionMedium();
    return button;
}

static NSSwitch *OVCMakeSwitch(id target, SEL action) {
    NSSwitch *toggle = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    toggle.controlSize = NSControlSizeSmall;
    toggle.target = target;
    toggle.action = action;
    return toggle;
}

#pragma mark - 基础绘制

@interface OVCSettingsCardView : NSView
@property (nonatomic, assign) CGFloat radius;
@end

@implementation OVCSettingsCardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) { _radius = OVCRadiusCard; }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5)
                                                         xRadius:self.radius
                                                         yRadius:self.radius];
    [OVCColor(OVCColorTokenSurfaceAlt) setFill];
    [path fill];
    [OVCColor(OVCColorTokenStroke) setStroke];
    path.lineWidth = 1.0;
    [path stroke];
}

@end

@interface OVCSeparatorView : NSView
@end

@implementation OVCSeparatorView
- (void)drawRect:(NSRect)dirtyRect {
    [OVCColor(OVCColorTokenStroke) setFill];
    NSRectFillUsingOperation(NSMakeRect(0, 0, self.bounds.size.width, 1), NSCompositingOperationSourceOver);
}
@end

@interface OVCAccentRuleView : NSView
@end

@implementation OVCAccentRuleView
- (void)drawRect:(NSRect)dirtyRect {
    [OVCColor(OVCColorTokenAccent) setFill];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
}
@end

@interface OVCBadgeView : NSView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSInteger tone; // 0 neutral, 1 success, 2 warning
- (CGFloat)preferredWidth;
@end

@implementation OVCBadgeView
- (void)setText:(NSString *)text {
    _text = [text copy];
    [self setNeedsDisplay:YES];
}
- (void)setTone:(NSInteger)tone {
    _tone = tone;
    [self setNeedsDisplay:YES];
}
- (CGFloat)preferredWidth {
    NSDictionary *attributes = @{NSFontAttributeName: OVCFontCaptionMedium()};
    CGFloat width = [(self.text ?: @"") sizeWithAttributes:attributes].width;
    return MAX(54.0, ceil(width) + 20.0);
}
- (void)drawRect:(NSRect)dirtyRect {
    NSColor *tone = self.tone == 1 ? OVCColor(OVCColorTokenSuccess)
                   : (self.tone == 2 ? OVCColor(OVCColorTokenWarning) : OVCColor(OVCColorTokenTextSecondary));
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5)
                                                         xRadius:self.bounds.size.height / 2
                                                         yRadius:self.bounds.size.height / 2];
    [[tone colorWithAlphaComponent:0.10] setFill];
    [path fill];
    [[tone colorWithAlphaComponent:0.22] setStroke];
    path.lineWidth = 0.8;
    [path stroke];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:self.text ?: @""
                                                                 attributes:@{
        NSFontAttributeName: OVCFontCaptionMedium(),
        NSForegroundColorAttributeName: tone,
        NSParagraphStyleAttributeName: paragraph,
    }];
    NSSize size = string.size;
    [string drawInRect:NSMakeRect(0, (self.bounds.size.height - size.height) / 2 + 0.5, self.bounds.size.width, size.height)];
}
@end

#pragma mark - 权限操作按钮

/// 小型描边按钮：固定 28pt 高，宽度由文字决定，避免原生按钮在宽卡片里被拉成色块。
@interface OVCPillButton : NSButton
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, assign) BOOL emphasized;
@property (nonatomic, assign) BOOL hovered;
@property (nonatomic, assign) BOOL pressed;
- (CGFloat)preferredWidth;
@end

@implementation OVCPillButton
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.transparent = YES;
        self.buttonType = NSButtonTypeMomentaryPushIn;
        self.focusRingType = NSFocusRingTypeExterior;
        self.title = @"";
        self.emphasized = YES;
    }
    return self;
}
- (void)setDisplayTitle:(NSString *)displayTitle {
    _displayTitle = [displayTitle copy];
    self.title = @"";
    self.accessibilityLabel = displayTitle;
    [self setNeedsDisplay:YES];
}
- (void)setEmphasized:(BOOL)emphasized {
    _emphasized = emphasized;
    [self setNeedsDisplay:YES];
}
- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    [self setNeedsDisplay:YES];
}
- (CGFloat)preferredWidth {
    NSDictionary *attributes = @{NSFontAttributeName: OVCFontBodyMedium()};
    CGFloat textWidth = ceil([(self.displayTitle ?: @"") sizeWithAttributes:attributes].width);
    return MAX(120.0, textWidth + 42.0);
}
- (NSRect)focusRingMaskBounds {
    return NSInsetRect(self.bounds, 2, 2);
}
- (void)drawFocusRingMask {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:[self focusRingMaskBounds]
                                                         xRadius:OVCRadiusButton
                                                         yRadius:OVCRadiusButton];
    [path fill];
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                          owner:self
                                                       userInfo:nil]];
}
- (void)mouseEntered:(NSEvent *)event {
    if (!self.enabled) return;
    self.hovered = YES;
    [self setNeedsDisplay:YES];
    [[NSCursor pointingHandCursor] set];
}
- (void)mouseExited:(NSEvent *)event {
    self.hovered = NO;
    [self setNeedsDisplay:YES];
    [[NSCursor arrowCursor] set];
}
- (void)mouseDown:(NSEvent *)event {
    if (!self.enabled) return;
    self.pressed = YES;
    [self setNeedsDisplay:YES];
    [super mouseDown:event];
    self.pressed = NO;
    [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = NSInsetRect(self.bounds, 0.5, 0.5);
    CGFloat radius = MIN(OVCRadiusButton, NSHeight(rect) / 2.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
    NSColor *accent = OVCColor(OVCColorTokenAccent);
    NSColor *accentPressed = OVCColor(OVCColorTokenAccentPressed);
    NSColor *foreground = OVCColor(OVCColorTokenOnAccent);

    if (!self.enabled) {
        [OVCColor(OVCColorTokenSurfaceAlt) setFill];
        [path fill];
        [OVCColor(OVCColorTokenStroke) setStroke];
        path.lineWidth = 0.8;
        [path stroke];
        foreground = OVCColor(OVCColorTokenTextTertiary);
    } else if (self.emphasized) {
        [(self.pressed || self.hovered ? accentPressed : accent) setFill];
        [path fill];
        [accentPressed setStroke];
        path.lineWidth = 0.8;
        [path stroke];
    } else {
        [[accent colorWithAlphaComponent:(self.pressed || self.hovered) ? 0.16 : 0.09] setFill];
        [path fill];
        [[accent colorWithAlphaComponent:0.22] setStroke];
        path.lineWidth = 0.8;
        [path stroke];
        foreground = accent;
    }

    CGFloat arrowWidth = 10.0;
    CGFloat padding = 13.0;
    CGFloat textWidth = MAX(0, NSWidth(self.bounds) - padding * 2 - arrowWidth - 6.0);
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:self.displayTitle ?: @""
                                                                 attributes:@{
        NSFontAttributeName: OVCFontBodyMedium(),
        NSForegroundColorAttributeName: foreground,
        NSParagraphStyleAttributeName: paragraph,
    }];
    NSRect textRect = NSMakeRect(padding,
                                 (NSHeight(self.bounds) - string.size.height) / 2.0 + 0.5,
                                 textWidth,
                                 string.size.height);
    [string drawInRect:textRect];

    CGFloat ax = NSWidth(self.bounds) - padding - 8.0;
    CGFloat ay = (NSHeight(self.bounds) - 8.0) / 2.0;
    [foreground setStroke];
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    arrow.lineWidth = 1.35;
    arrow.lineCapStyle = NSLineCapStyleRound;
    [arrow moveToPoint:NSMakePoint(ax, ay)];
    [arrow lineToPoint:NSMakePoint(ax + 7.0, ay + 7.0)];
    [arrow moveToPoint:NSMakePoint(ax + 2.0, ay + 7.0)];
    [arrow lineToPoint:NSMakePoint(ax + 7.0, ay + 7.0)];
    [arrow lineToPoint:NSMakePoint(ax + 7.0, ay + 2.0)];
    [arrow stroke];
}
@end

@interface OVCStatusPillView : NSView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSInteger tone; // 0 neutral, 1 success, 2 warning, 3 danger
@end

@implementation OVCStatusPillView
- (void)setText:(NSString *)text {
    _text = [text copy];
    [self setNeedsDisplay:YES];
}
- (void)setTone:(NSInteger)tone {
    _tone = tone;
    [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    NSColor *tone = self.tone == 1 ? OVCColor(OVCColorTokenSuccess)
                   : (self.tone == 2 ? OVCColor(OVCColorTokenWarning)
                   : (self.tone == 3 ? OVCColor(OVCColorTokenDanger) : OVCColor(OVCColorTokenTextTertiary)));
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5)
                                                         xRadius:self.bounds.size.height / 2
                                                         yRadius:self.bounds.size.height / 2];
    [[tone colorWithAlphaComponent:0.10] setFill];
    [path fill];
    [[tone colorWithAlphaComponent:0.20] setStroke];
    path.lineWidth = 0.8;
    [path stroke];

    [tone setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(11, (self.bounds.size.height - 6) / 2, 6, 6)] fill];

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:self.text ?: @""
                                                                 attributes:@{
        NSFontAttributeName: OVCFontCaptionMedium(),
        NSForegroundColorAttributeName: OVCColor(OVCColorTokenTextSecondary),
        NSParagraphStyleAttributeName: paragraph,
    }];
    [string drawInRect:NSMakeRect(23, (self.bounds.size.height - string.size.height) / 2 + 0.5,
                                  self.bounds.size.width - 33, string.size.height)];
}
@end

@interface OVCToastView : NSView
@property (nonatomic, copy) NSString *text;
@end

@implementation OVCToastView
- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5)
                                                         xRadius:self.bounds.size.height / 2
                                                         yRadius:self.bounds.size.height / 2];
    [[OVCColor(OVCColorTokenTextPrimary) colorWithAlphaComponent:0.90] setFill];
    [path fill];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:self.text ?: @""
                                                                 attributes:@{
        NSFontAttributeName: OVCFontCaptionMedium(),
        NSForegroundColorAttributeName: OVCColor(OVCColorTokenSurface),
        NSParagraphStyleAttributeName: paragraph,
    }];
    [string drawInRect:NSMakeRect(12, (self.bounds.size.height - string.size.height) / 2, self.bounds.size.width - 24, string.size.height)];
}
@end

#pragma mark - 页面协议

@class OVCSettingsView;

@protocol OVCSettingsPageHost <NSObject>
- (void)pageOpenFullDiskAccess;
- (void)pageOpenAccessibility;
- (void)pageToggleMonitoring:(BOOL)enabled;
- (void)pageToggleAutoCopy:(BOOL)enabled;
- (void)pageTogglePanel:(BOOL)enabled;
- (void)pageToggleLaunchAtLogin:(BOOL)enabled;
- (void)pageToggleDockIcon:(BOOL)enabled;
- (void)pageChangeDuration:(double)duration;
- (void)pageSetPanelTheme:(NSInteger)theme;
- (void)pageSetPanelSize:(NSInteger)size;
- (void)pageSetPanelTransparency:(double)value;
- (void)pageChangeMinDigits:(NSInteger)minDigits maxDigits:(NSInteger)maxDigits;
- (void)pageToggleKeyword:(BOOL)enabled;
- (void)pageScan;
- (void)pageClearHistory;
- (void)pageShowToast:(NSString *)text;
@end

@interface OVCPageView : NSView
@property (nonatomic, weak, nullable) id<OVCSettingsPageHost> host;
@property (nonatomic, assign) BOOL monitoringEnabled;
- (void)refresh;
- (void)setMonitoringEnabled:(BOOL)enabled;
@end

@implementation OVCPageView
- (BOOL)isFlipped { return NO; }
- (void)setMonitoringEnabled:(BOOL)enabled {
    _monitoringEnabled = enabled;
}
- (void)refresh {}
@end

#pragma mark - 权限页

@interface OVCIconCircleView : NSView
@property (nonatomic, strong) NSColor *fillColor;
@property (nonatomic, strong) NSColor *strokeColor;
@end

@implementation OVCIconCircleView
- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(self.bounds, 0.5, 0.5)];
    [(self.fillColor ?: [OVCColor(OVCColorTokenAccentSoft) colorWithAlphaComponent:0.8]) setFill];
    [path fill];
    if (self.strokeColor) {
        [self.strokeColor setStroke];
        path.lineWidth = 1.0;
        [path stroke];
    }
}
@end

@interface OVCPermissionTileView : NSView
@property (nonatomic, assign) BOOL granted;
@property (nonatomic, strong) NSView *iconCircle;
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *detailLabel;
@property (nonatomic, strong) OVCBadgeView *badge;
@property (nonatomic, strong) OVCPillButton *actionButton;
@property (nonatomic, strong) NSImageView *stateIcon;
@property (nonatomic, strong) NSTextField *stateLabel;
@end

@implementation OVCPermissionTileView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _iconCircle = [[OVCIconCircleView alloc] initWithFrame:NSZeroRect];
        _iconView = OVCMakeSymbol(@"checkmark.shield", 17, OVCColor(OVCColorTokenAccent));
        _titleLabel = OVCMakeLabel(@"", OVCFontSubhead(), OVCColor(OVCColorTokenTextPrimary));
        _detailLabel = OVCMakeMultilineLabel(@"", OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary), 2);
        _badge = [[OVCBadgeView alloc] initWithFrame:NSZeroRect];
        _actionButton = [[OVCPillButton alloc] initWithFrame:NSZeroRect];
        _actionButton.displayTitle = OVCStr(@"打开系统设置");
        _stateIcon = OVCMakeSymbol(@"checkmark.circle.fill", 12, OVCColor(OVCColorTokenSuccess));
        _stateLabel = OVCMakeLabel(OVCStr(@"无需操作"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        _stateIcon.hidden = YES;
        _stateLabel.hidden = YES;
        for (NSView *view in @[_iconCircle, _iconView, _titleLabel, _detailLabel, _badge, _actionButton, _stateIcon, _stateLabel]) {
            [self addSubview:view];
        }
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.iconCircle.frame = NSMakeRect(16, height - 50, 36, 36);
    self.iconView.frame = NSMakeRect(25, height - 41, 18, 18);
    CGFloat badgeWidth = [self.badge preferredWidth];
    self.badge.frame = NSMakeRect(width - 16 - badgeWidth, height - 43, badgeWidth, 20);
    self.titleLabel.frame = NSMakeRect(16, height - 82, width - 32, 20);
    self.detailLabel.frame = NSMakeRect(16, height - 114, width - 32, 30);
    CGFloat actionWidth = MIN(width - 32, [self.actionButton preferredWidth]);
    self.actionButton.frame = NSMakeRect(16, 16, actionWidth, 28);
    self.stateIcon.frame = NSMakeRect(16, 23, 12, 12);
    self.stateLabel.frame = NSMakeRect(34, 21, width - 50, 16);
}
- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5)
                                                         xRadius:OVCRadiusCard
                                                         yRadius:OVCRadiusCard];
    [OVCColor(OVCColorTokenSurfaceAlt) setFill];
    [path fill];
    [OVCColor(OVCColorTokenStroke) setStroke];
    path.lineWidth = 1.0;
    [path stroke];
}
@end

@interface OVCPermissionPage : OVCPageView
@property (nonatomic, strong) OVCPermissionTileView *fdaTile;
@property (nonatomic, strong) OVCPermissionTileView *axTile;
@property (nonatomic, strong) OVCSettingsCardView *privacyCard;
@property (nonatomic, copy) NSArray<NSView *> *privacyPromiseViews;
@property (nonatomic, strong) NSImageView *privacyShield;
@property (nonatomic, strong) NSTextField *privacyTitleLabel;
@property (nonatomic, strong) NSTextField *privacyDetailLabel;
@property (nonatomic, strong) NSImageView *hintIcon;
@property (nonatomic, strong) NSTextField *hintLabel;
@property (nonatomic, strong) OVCAccentRuleView *manifestoRule;
@property (nonatomic, strong) NSTextField *manifestoTitle;
@property (nonatomic, strong) NSTextField *manifestoDetail;
- (void)setFullDiskAccess:(BOOL)fda accessibility:(BOOL)ax;
@end

@implementation OVCPermissionPage
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _fdaTile = [[OVCPermissionTileView alloc] initWithFrame:NSZeroRect];
        _fdaTile.titleLabel.stringValue = OVCStr(@"完全磁盘访问");
        _fdaTile.detailLabel.stringValue = OVCStr(@"只读读取短信数据库，不修改、不上传。");
        _fdaTile.iconView.image = [NSImage imageWithSystemSymbolName:@"lock.shield" accessibilityDescription:nil];
        _fdaTile.actionButton.target = self;
        _fdaTile.actionButton.action = @selector(openFDA:);

        _axTile = [[OVCPermissionTileView alloc] initWithFrame:NSZeroRect];
        _axTile.titleLabel.stringValue = OVCStr(@"辅助功能");
        _axTile.detailLabel.stringValue = OVCStr(@"定位当前输入框，并把验证码填进去。");
        _axTile.iconView.image = [NSImage imageWithSystemSymbolName:@"accessibility" accessibilityDescription:nil];
        _axTile.actionButton.target = self;
        _axTile.actionButton.action = @selector(openAX:);

        OVCSettingsCardView *privacy = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        privacy.radius = OVCRadiusCard;
        NSImageView *shield = OVCMakeSymbol(@"checkmark.shield.fill", 17, OVCColor(OVCColorTokenSuccess));
        NSTextField *privacyTitle = OVCMakeLabel(OVCStr(@"隐私承诺"), OVCFontSubhead(), OVCColor(OVCColorTokenTextPrimary));
        NSTextField *privacyDetail = OVCMakeLabel(OVCStr(@"所有处理都在本机完成"), OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
        NSArray<NSString *> *promises = @[OVCStr(@"短信库只读"), OVCStr(@"不联网"), OVCStr(@"日志不含验证码")];
        NSMutableArray<NSView *> *promiseViews = [NSMutableArray array];
        for (NSString *promise in promises) {
            NSImageView *check = OVCMakeSymbol(@"checkmark.circle.fill", 12, OVCColor(OVCColorTokenSuccess));
            NSTextField *label = OVCMakeLabel(promise, OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
            [promiseViews addObject:check];
            [promiseViews addObject:label];
            [privacy addSubview:check];
            [privacy addSubview:label];
        }
        [privacy addSubview:shield];
        [privacy addSubview:privacyTitle];
        [privacy addSubview:privacyDetail];
        self.privacyShield = shield;
        self.privacyTitleLabel = privacyTitle;
        self.privacyDetailLabel = privacyDetail;
        self.privacyCard = privacy;
        self.privacyPromiseViews = promiseViews;

        self.hintLabel = OVCMakeLabel(OVCStr(@"权限变更后无需重启，状态会每 3 秒自动刷新。"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        self.hintIcon = OVCMakeSymbol(@"info.circle", 12, OVCColor(OVCColorTokenTextTertiary));
        self.manifestoRule = [[OVCAccentRuleView alloc] initWithFrame:NSZeroRect];
        self.manifestoTitle = OVCMakeLabel(OVCStr(@"验证码只在你的 Mac 上停留。"), OVCFontTitle(), OVCColor(OVCColorTokenTextPrimary));
        self.manifestoDetail = OVCMakeLabel(OVCStr(@"读取、识别、填入，全程本机完成；不联网，也不保存短信正文。"), OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));

        [self addSubview:_fdaTile];
        [self addSubview:_axTile];
        [self addSubview:privacy];
        [self addSubview:self.hintIcon];
        [self addSubview:self.hintLabel];
        [self addSubview:self.manifestoRule];
        [self addSubview:self.manifestoTitle];
        [self addSubview:self.manifestoDetail];
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.fdaTile.frame = NSMakeRect(0, height - 172, (width - 16) / 2, 172);
    self.axTile.frame = NSMakeRect((width + 16) / 2, height - 172, (width - 16) / 2, 172);
    self.privacyCard.frame = NSMakeRect(0, height - 296, width, 108);
    self.hintIcon.frame = NSMakeRect(2, height - 328, 12, 12);
    self.hintLabel.frame = NSMakeRect(20, height - 331, width - 20, 16);
    self.manifestoRule.frame = NSMakeRect(2, 56, 2, 54);
    self.manifestoTitle.frame = NSMakeRect(18, 86, width - 20, 22);
    self.manifestoDetail.frame = NSMakeRect(18, 64, width - 20, 16);

    NSArray<NSView *> *promises = self.privacyPromiseViews;
    CGFloat startX = 44;
    CGFloat chipWidth = (width - 88) / 3;
    for (NSInteger i = 0; i < 3; i++) {
        NSView *check = promises[(NSUInteger)(i * 2)];
        NSView *label = promises[(NSUInteger)(i * 2 + 1)];
        check.frame = NSMakeRect(startX + i * chipWidth, 18, 12, 12);
        label.frame = NSMakeRect(startX + i * chipWidth + 17, 16, chipWidth - 20, 16);
    }
    self.privacyShield.frame = NSMakeRect(18, 70, 17, 17);
    self.privacyTitleLabel.frame = NSMakeRect(44, 72, 180, 18);
    self.privacyDetailLabel.frame = NSMakeRect(44, 54, 260, 16);
}
- (void)setFullDiskAccess:(BOOL)fda accessibility:(BOOL)ax {
    [self updateTile:self.fdaTile granted:fda];
    [self updateTile:self.axTile granted:ax];
}
- (void)updateTile:(OVCPermissionTileView *)tile granted:(BOOL)granted {
    tile.granted = granted;
    tile.badge.text = granted ? OVCStr(@"已允许") : OVCStr(@"待授权");
    tile.badge.tone = granted ? 1 : 2;
    tile.actionButton.displayTitle = OVCStr(@"打开系统设置");
    tile.actionButton.enabled = !granted;
    tile.actionButton.hidden = granted;
    tile.stateIcon.hidden = !granted;
    tile.stateLabel.hidden = !granted;
    ((OVCIconCircleView *)tile.iconCircle).fillColor = [OVCColor(granted ? OVCColorTokenSuccess : OVCColorTokenWarning) colorWithAlphaComponent:0.10];
    tile.iconView.contentTintColor = OVCColor(granted ? OVCColorTokenSuccess : OVCColorTokenWarning);
}
- (void)openFDA:(id)sender { [self.host pageOpenFullDiskAccess]; }
- (void)openAX:(id)sender { [self.host pageOpenAccessibility]; }
@end

#pragma mark - 行为页

@interface OVCSettingRowView : NSView
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *subtitleLabel;
@property (nonatomic, strong) NSTextField *valueLabel;
@property (nonatomic, strong) NSControl *control;
@property (nonatomic, strong) NSView *separator;
@property (nonatomic, assign) BOOL showsSeparator;
- (instancetype)initWithSymbol:(NSString *)symbol
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                       control:(NSControl *)control
                    showsValue:(BOOL)showsValue;
- (void)layoutForHeight:(CGFloat)height;
@end

@implementation OVCSettingRowView
- (instancetype)initWithSymbol:(NSString *)symbol
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                       control:(NSControl *)control
                    showsValue:(BOOL)showsValue {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _iconView = OVCMakeSymbol(symbol, 15, OVCColor(OVCColorTokenTextSecondary));
        _titleLabel = OVCMakeLabel(title, OVCFontBodyMedium(), OVCColor(OVCColorTokenTextPrimary));
        _subtitleLabel = OVCMakeLabel(subtitle, OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
        _control = control;
        _control.translatesAutoresizingMaskIntoConstraints = YES;
        _showsSeparator = YES;
        _separator = [[OVCSeparatorView alloc] initWithFrame:NSZeroRect];
        [self addSubview:_iconView];
        [self addSubview:_titleLabel];
        [self addSubview:_subtitleLabel];
        [self addSubview:_control];
        [self addSubview:_separator];
        if (showsValue) {
            _valueLabel = OVCMakeLabel(OVCStr(@"8 秒"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
            _valueLabel.alignment = NSTextAlignmentRight;
            [self addSubview:_valueLabel];
        }
    }
    return self;
}
- (void)layout {
    [super layout];
    [self layoutForHeight:self.bounds.size.height];
}
- (void)layoutForHeight:(CGFloat)height {
    CGFloat width = self.bounds.size.width;
    CGFloat textWidth = self.valueLabel ? 230 : (width - 130);
    self.iconView.frame = NSMakeRect(18, (height - 16) / 2, 16, 16);
    self.titleLabel.frame = NSMakeRect(48, height - 25, textWidth, 17);
    self.subtitleLabel.frame = NSMakeRect(48, 7, textWidth, 15);
    self.control.frame = NSMakeRect(width - 58, (height - 24) / 2, 40, 24);
    if (self.valueLabel) {
        self.control.frame = NSMakeRect(300, (height - 22) / 2, 150, 22);
        self.valueLabel.frame = NSMakeRect(458, (height - 16) / 2, 50, 16);
    }
    self.separator.frame = NSMakeRect(48, 0, width - 66, 1);
    self.separator.hidden = !self.showsSeparator;
}
@end

@interface OVCBehaviorPage : OVCPageView
@property (nonatomic, strong) NSSwitch *monitorSwitch;
@property (nonatomic, strong) NSSwitch *autoCopySwitch;
@property (nonatomic, strong) NSSwitch *panelSwitch;
@property (nonatomic, strong) NSSwitch *loginSwitch;
@property (nonatomic, strong) NSSwitch *dockSwitch;
@property (nonatomic, strong) NSSlider *durationSlider;
@property (nonatomic, strong) NSTextField *durationValue;
@property (nonatomic, strong) NSTextField *heroTitle;
@property (nonatomic, strong) NSTextField *heroSubtitle;
@property (nonatomic, strong) NSView *heroIconCircle;
@property (nonatomic, strong) NSImageView *heroIcon;
@property (nonatomic, strong) NSView *heroCard;
@property (nonatomic, strong) NSView *reminderCard;
@property (nonatomic, strong) NSView *systemCard;
@property (nonatomic, strong) OVCSettingRowView *durationRow;
@property (nonatomic, copy) NSArray<OVCSettingRowView *> *reminderRows;
@property (nonatomic, copy) NSArray<OVCSettingRowView *> *systemRows;
@property (nonatomic, strong) NSTextField *reminderLabel;
@property (nonatomic, strong) NSTextField *systemLabel;
@property (nonatomic, strong) NSTextField *footnoteLabel;
@end

@implementation OVCBehaviorPage
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.heroCard = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        self.heroIconCircle = [[OVCIconCircleView alloc] initWithFrame:NSZeroRect];
        self.heroIcon = OVCMakeSymbol(@"antenna.radiowaves.left.and.right", 18, OVCColor(OVCColorTokenAccent));
        self.heroTitle = OVCMakeLabel(OVCStr(@"监听短信"), OVCFontSubhead(), OVCColor(OVCColorTokenTextPrimary));
        self.heroSubtitle = OVCMakeLabel(OVCStr(@"从 iPhone 转发到本机的短信中提取验证码"), OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
        self.monitorSwitch = OVCMakeSwitch(self, @selector(toggleMonitoring:));
        self.monitorSwitch.controlSize = NSControlSizeRegular;
        for (NSView *view in @[self.heroIconCircle, self.heroIcon, self.heroTitle, self.heroSubtitle, self.monitorSwitch]) {
            [self.heroCard addSubview:view];
        }

        self.reminderLabel = OVCMakeLabel(OVCStr(@"提醒"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        self.reminderCard = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        self.autoCopySwitch = OVCMakeSwitch(self, @selector(toggleAutoCopy:));
        OVCSettingRowView *copyRow = [[OVCSettingRowView alloc] initWithSymbol:@"doc.on.doc"
                                                                        title:OVCStr(@"自动复制到剪贴板")
                                                                     subtitle:OVCStr(@"识别后立即写入系统剪贴板")
                                                                      control:self.autoCopySwitch
                                                                   showsValue:NO];
        self.panelSwitch = OVCMakeSwitch(self, @selector(togglePanel:));
        OVCSettingRowView *panelRow = [[OVCSettingRowView alloc] initWithSymbol:@"rectangle.on.rectangle"
                                                                         title:OVCStr(@"在输入框旁弹出提示")
                                                                      subtitle:OVCStr(@"紧凑卡片，点击数字即可填入")
                                                                       control:self.panelSwitch
                                                                    showsValue:NO];
        panelRow.showsSeparator = NO;

        self.durationSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
        self.durationSlider.minValue = 1;
        self.durationSlider.maxValue = 20;
        self.durationSlider.continuous = YES;
        self.durationSlider.target = self;
        self.durationSlider.action = @selector(changeDuration:);
        self.durationSlider.controlSize = NSControlSizeSmall;
        self.durationRow = [[OVCSettingRowView alloc] initWithSymbol:@"timer"
                                                               title:OVCStr(@"提示停留")
                                                            subtitle:OVCStr(@"底部进度条走完后自动收起")
                                                             control:self.durationSlider
                                                          showsValue:YES];
        self.durationValue = self.durationRow.valueLabel;
        self.durationRow.showsSeparator = NO;
        self.reminderRows = @[copyRow, panelRow];
        [self.reminderCard addSubview:copyRow];
        [self.reminderCard addSubview:panelRow];
        [self.reminderCard addSubview:self.durationRow];

        self.systemLabel = OVCMakeLabel(OVCStr(@"系统"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        self.systemCard = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        self.loginSwitch = OVCMakeSwitch(self, @selector(toggleLogin:));
        OVCSettingRowView *loginRow = [[OVCSettingRowView alloc] initWithSymbol:@"power"
                                                                         title:OVCStr(@"开机自动启动")
                                                                      subtitle:OVCStr(@"登录后在菜单栏静默运行")
                                                                       control:self.loginSwitch
                                                                    showsValue:NO];
        self.dockSwitch = OVCMakeSwitch(self, @selector(toggleDockIcon:));
        OVCSettingRowView *dockRow = [[OVCSettingRowView alloc] initWithSymbol:@"dock.rectangle"
                                                                        title:OVCStr(@"在 Dock 中显示图标")
                                                                     subtitle:OVCStr(@"菜单栏空间不足时作为备用入口")
                                                                      control:self.dockSwitch
                                                                   showsValue:NO];
        dockRow.showsSeparator = NO;
        self.systemRows = @[loginRow, dockRow];
        [self.systemCard addSubview:loginRow];
        [self.systemCard addSubview:dockRow];

        self.footnoteLabel = OVCMakeLabel(OVCStr(@"设置即时生效 · 无需重启一码"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        for (NSView *view in @[self.heroCard, self.reminderLabel, self.reminderCard,
                               self.systemLabel, self.systemCard, self.footnoteLabel]) {
            [self addSubview:view];
        }
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.heroCard.frame = NSMakeRect(0, height - 86, width, 86);
    self.heroIconCircle.frame = NSMakeRect(18, 23, 40, 40);
    self.heroIcon.frame = NSMakeRect(29, 34, 18, 18);
    self.heroTitle.frame = NSMakeRect(72, 48, 280, 18);
    self.heroSubtitle.frame = NSMakeRect(72, 28, 360, 16);
    self.monitorSwitch.frame = NSMakeRect(width - 64, 31, 40, 24);

    self.reminderLabel.frame = NSMakeRect(2, height - 110, 100, 16);
    self.reminderCard.frame = NSMakeRect(0, 208, width, 146);
    self.systemLabel.frame = NSMakeRect(2, 184, 100, 16);
    self.systemCard.frame = NSMakeRect(0, 78, width, 96);
    self.footnoteLabel.frame = NSMakeRect(2, 48, 300, 16);

    CGFloat reminderH = self.reminderCard.bounds.size.height;
    NSArray<NSNumber *> *reminderHeights = @[@48, @48, @50];
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat rowHeight = reminderHeights[(NSUInteger)i].doubleValue;
        CGFloat y = i < 2 ? reminderH - (i + 1) * 48 : 0;
        OVCSettingRowView *row = i < 2 ? self.reminderRows[(NSUInteger)i] : self.durationRow;
        row.frame = NSMakeRect(0, y, width, rowHeight);
        [row layoutForHeight:rowHeight];
    }
    CGFloat systemH = self.systemCard.bounds.size.height;
    for (NSInteger i = 0; i < 2; i++) {
        OVCSettingRowView *row = self.systemRows[(NSUInteger)i];
        row.frame = NSMakeRect(0, systemH - (i + 1) * 48, width, 48);
        [row layoutForHeight:48];
    }
}
- (void)refresh {
    OVCPrefs *prefs = [OVCPrefs shared];
    self.monitorSwitch.state = self.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.autoCopySwitch.state = prefs.autoCopy ? NSControlStateValueOn : NSControlStateValueOff;
    self.panelSwitch.state = prefs.showPanel ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginSwitch.state = prefs.launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
    self.dockSwitch.state = prefs.dockIcon ? NSControlStateValueOn : NSControlStateValueOff;
    self.durationSlider.doubleValue = prefs.panelDuration;
    self.durationValue.stringValue = [NSString stringWithFormat:OVCStr(@"%.0f 秒"), prefs.panelDuration];
    [self updateAvailability];
}
- (void)setMonitoringEnabled:(BOOL)enabled {
    [super setMonitoringEnabled:enabled];
    [self updateAvailability];
}
- (void)updateAvailability {
    BOOL on = self.monitoringEnabled;
    BOOL panel = self.panelSwitch.state == NSControlStateValueOn;
    self.heroSubtitle.stringValue = on ? OVCStr(@"从 iPhone 转发到本机的短信中提取验证码") : OVCStr(@"已暂停。打开开关后继续监听。");
    ((OVCIconCircleView *)self.heroIconCircle).fillColor = [OVCColor(on ? OVCColorTokenAccent : OVCColorTokenTextTertiary) colorWithAlphaComponent:0.10];
    self.heroIcon.contentTintColor = OVCColor(on ? OVCColorTokenAccent : OVCColorTokenTextTertiary);
    for (NSControl *control in @[self.autoCopySwitch, self.panelSwitch, self.loginSwitch, self.dockSwitch]) {
        control.enabled = on;
    }
    self.reminderCard.alphaValue = on ? 1.0 : 0.48;
    self.systemCard.alphaValue = on ? 1.0 : 0.48;
    self.durationSlider.enabled = on && panel;
    self.durationRow.alphaValue = (on && panel) ? 1.0 : 0.42;
}
- (void)toggleMonitoring:(NSSwitch *)sender { [self.host pageToggleMonitoring:sender.state == NSControlStateValueOn]; }
- (void)toggleAutoCopy:(NSSwitch *)sender { [self.host pageToggleAutoCopy:sender.state == NSControlStateValueOn]; }
- (void)togglePanel:(NSSwitch *)sender { [self.host pageTogglePanel:sender.state == NSControlStateValueOn]; [self updateAvailability]; }
- (void)toggleLogin:(NSSwitch *)sender { [self.host pageToggleLaunchAtLogin:sender.state == NSControlStateValueOn]; }
- (void)toggleDockIcon:(NSSwitch *)sender { [self.host pageToggleDockIcon:sender.state == NSControlStateValueOn]; }
- (void)changeDuration:(NSSlider *)sender {
    [self.host pageChangeDuration:round(sender.doubleValue)];
    self.durationValue.stringValue = [NSString stringWithFormat:OVCStr(@"%.0f 秒"), round(sender.doubleValue)];
}
@end

#pragma mark - 规则页

@interface OVCRulesPage : OVCPageView
@property (nonatomic, strong) NSPopUpButton *minPopup;
@property (nonatomic, strong) NSPopUpButton *maxPopup;
@property (nonatomic, strong) NSSwitch *keywordSwitch;
@property (nonatomic, strong) OVCSettingsCardView *lengthCard;
@property (nonatomic, strong) OVCIconCircleView *lengthIconBg;
@property (nonatomic, strong) NSImageView *lengthIcon;
@property (nonatomic, strong) NSTextField *lengthTitle;
@property (nonatomic, strong) NSTextField *lengthDetail;
@property (nonatomic, strong) NSTextField *lengthDash;
@property (nonatomic, strong) OVCSettingsCardView *keywordCard;
@property (nonatomic, strong) OVCIconCircleView *keywordIconBg;
@property (nonatomic, strong) NSImageView *keywordIcon;
@property (nonatomic, strong) NSTextField *keywordTitle;
@property (nonatomic, strong) NSTextField *keywordDetail;
@property (nonatomic, strong) OVCSettingsCardView *exampleCard;
@property (nonatomic, strong) NSTextField *exampleTitle;
@property (nonatomic, strong) OVCBadgeView *demoBadge;
@property (nonatomic, strong) OVCSettingsCardView *bubble;
@property (nonatomic, strong) NSTextField *bubbleText;
@property (nonatomic, strong) NSImageView *arrow;
@property (nonatomic, strong) OVCSettingsCardView *resultCard;
@property (nonatomic, strong) NSTextField *resultCaption;
@property (nonatomic, strong) NSTextField *resultCode;
@end

@implementation OVCRulesPage
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        OVCSettingsCardView *length = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        OVCIconCircleView *lengthIconBg = [[OVCIconCircleView alloc] initWithFrame:NSZeroRect];
        NSImageView *lengthIcon = OVCMakeSymbol(@"textformat.123", 16, OVCColor(OVCColorTokenAccent));
        NSTextField *lengthTitle = OVCMakeLabel(OVCStr(@"验证码长度"), OVCFontSubhead(), OVCColor(OVCColorTokenTextPrimary));
        NSTextField *lengthDetail = OVCMakeLabel(OVCStr(@"只提取这个范围内的数字或字母数字组合"), OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
        self.minPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        self.maxPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        for (NSPopUpButton *popup in @[self.minPopup, self.maxPopup]) {
            popup.controlSize = NSControlSizeSmall;
            popup.target = self;
            popup.action = @selector(changeLength:);
            popup.font = OVCFontCaption();
        }
        for (NSInteger value = 4; value <= 6; value++) {
            [self.minPopup addItemWithTitle:[NSString stringWithFormat:OVCStr(@"%ld 位"), (long)value]];
            self.minPopup.lastItem.tag = value;
        }
        for (NSInteger value = 6; value <= 8; value++) {
            [self.maxPopup addItemWithTitle:[NSString stringWithFormat:OVCStr(@"%ld 位"), (long)value]];
            self.maxPopup.lastItem.tag = value;
        }
        NSTextField *dash = OVCMakeLabel(OVCStr(@"至"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        for (NSView *view in @[lengthIconBg, lengthIcon, lengthTitle, lengthDetail, self.minPopup, self.maxPopup, dash]) {
            [length addSubview:view];
        }
        self.lengthCard = length;
        self.lengthIconBg = lengthIconBg;
        self.lengthIcon = lengthIcon;
        self.lengthTitle = lengthTitle;
        self.lengthDetail = lengthDetail;
        self.lengthDash = dash;

        OVCSettingsCardView *keyword = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        OVCIconCircleView *keywordIconBg = [[OVCIconCircleView alloc] initWithFrame:NSZeroRect];
        keywordIconBg.fillColor = [OVCColor(OVCColorTokenAccent) colorWithAlphaComponent:0.08];
        NSImageView *keywordIcon = OVCMakeSymbol(@"key", 16, OVCColor(OVCColorTokenAccent));
        NSTextField *keywordTitle = OVCMakeLabel(OVCStr(@"必须包含关键词"), OVCFontSubhead(), OVCColor(OVCColorTokenTextPrimary));
        NSTextField *keywordDetail = OVCMakeLabel(OVCStr(@"验证码、校验码、code、OTP 等"), OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
        self.keywordSwitch = OVCMakeSwitch(self, @selector(toggleKeyword:));
        for (NSView *view in @[keywordIconBg, keywordIcon, keywordTitle, keywordDetail, self.keywordSwitch]) {
            [keyword addSubview:view];
        }
        self.keywordCard = keyword;
        self.keywordIconBg = keywordIconBg;
        self.keywordIcon = keywordIcon;
        self.keywordTitle = keywordTitle;
        self.keywordDetail = keywordDetail;

        OVCSettingsCardView *example = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        NSTextField *exampleTitle = OVCMakeLabel(OVCStr(@"识别示例"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        OVCBadgeView *demoBadge = [[OVCBadgeView alloc] initWithFrame:NSZeroRect];
        demoBadge.text = OVCStr(@"本地演示");
        demoBadge.tone = 0;
        OVCSettingsCardView *bubble = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        bubble.radius = 12;
        NSTextField *bubbleText = OVCMakeMultilineLabel(OVCStr(@"【一码】您的验证码是 482913，5 分钟内有效。"), OVCFontBody(), OVCColor(OVCColorTokenTextSecondary), 2);
        NSImageView *arrow = OVCMakeSymbol(@"arrow.right", 14, OVCColor(OVCColorTokenTextTertiary));
        OVCSettingsCardView *result = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        result.radius = 12;
        NSTextField *resultCaption = OVCMakeLabel(OVCStr(@"将识别"), OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));
        NSTextField *resultCode = OVCMakeLabel(@"482913", OVCFontCode(), OVCColor(OVCColorTokenAccent));
        resultCode.font = [NSFont monospacedSystemFontOfSize:18 weight:NSFontWeightSemibold];
        for (NSView *view in @[exampleTitle, demoBadge, bubble, bubbleText, arrow, result, resultCaption, resultCode]) {
            [example addSubview:view];
        }
        for (NSView *view in @[length, keyword, example]) {
            [self addSubview:view];
        }
        self.exampleCard = example;
        self.exampleTitle = exampleTitle;
        self.demoBadge = demoBadge;
        self.bubble = bubble;
        self.bubbleText = bubbleText;
        self.arrow = arrow;
        self.resultCard = result;
        self.resultCaption = resultCaption;
        self.resultCode = resultCode;
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    self.lengthCard.frame = NSMakeRect(0, height - 100, width, 100);
    self.lengthIconBg.frame = NSMakeRect(18, 33, 34, 34);
    self.lengthIcon.frame = NSMakeRect(27, 42, 16, 16);
    self.lengthTitle.frame = NSMakeRect(64, 57, 260, 18);
    self.lengthDetail.frame = NSMakeRect(64, 35, 270, 16);
    self.minPopup.frame = NSMakeRect(362, 36, 76, 28);
    self.lengthDash.frame = NSMakeRect(444, 42, 18, 16);
    self.maxPopup.frame = NSMakeRect(462, 36, 76, 28);

    self.keywordCard.frame = NSMakeRect(0, 276, width, 80);
    self.keywordIconBg.frame = NSMakeRect(18, 23, 34, 34);
    self.keywordIcon.frame = NSMakeRect(27, 32, 16, 16);
    self.keywordTitle.frame = NSMakeRect(64, 43, 260, 18);
    self.keywordDetail.frame = NSMakeRect(64, 22, 320, 16);
    self.keywordSwitch.frame = NSMakeRect(width - 56, 28, 40, 24);

    self.exampleCard.frame = NSMakeRect(0, 82, width, 174);
    self.exampleTitle.frame = NSMakeRect(18, 140, 120, 16);
    self.demoBadge.frame = NSMakeRect(width - 88, 137, 70, 22);
    self.bubble.frame = NSMakeRect(18, 50, 330, 74);
    self.bubbleText.frame = NSMakeRect(34, 66, 298, 42);
    self.arrow.frame = NSMakeRect(358, 78, 16, 16);
    self.resultCard.frame = NSMakeRect(382, 50, 152, 74);
    self.resultCaption.frame = NSMakeRect(398, 96, 120, 16);
    self.resultCode.frame = NSMakeRect(398, 62, 120, 30);
}
- (void)refresh {
    OVCPrefs *prefs = [OVCPrefs shared];
    [self.minPopup selectItemWithTag:prefs.minDigits];
    [self.maxPopup selectItemWithTag:prefs.maxDigits];
    self.keywordSwitch.state = prefs.requiresKeyword ? NSControlStateValueOn : NSControlStateValueOff;
    self.minPopup.enabled = self.monitoringEnabled;
    self.maxPopup.enabled = self.monitoringEnabled;
    self.keywordSwitch.enabled = self.monitoringEnabled;
    self.lengthCard.alphaValue = self.monitoringEnabled ? 1.0 : 0.48;
    self.keywordCard.alphaValue = self.monitoringEnabled ? 1.0 : 0.48;
    self.exampleCard.alphaValue = self.monitoringEnabled ? 1.0 : 0.48;
}
- (void)setMonitoringEnabled:(BOOL)enabled {
    [super setMonitoringEnabled:enabled];
    [self refresh];
}
- (void)changeLength:(NSPopUpButton *)sender {
    [self.host pageChangeMinDigits:self.minPopup.selectedTag maxDigits:self.maxPopup.selectedTag];
}
- (void)toggleKeyword:(NSSwitch *)sender {
    [self.host pageToggleKeyword:sender.state == NSControlStateValueOn];
}
@end

#pragma mark - 记录页

@interface OVCRecordPage : OVCPageView <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, copy) NSArray<OVCHistoryItem *> *items;
@property (nonatomic, strong) NSTableView *table;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSView *emptyView;
@property (nonatomic, strong) NSButton *scanButton;
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) OVCSettingsCardView *card;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *countLabel;
@property (nonatomic, strong) NSImageView *lockIcon;
@property (nonatomic, strong) NSImageView *emptyIcon;
@property (nonatomic, strong) NSTextField *emptyTitle;
@property (nonatomic, strong) NSTextField *emptyDetail;
@property (nonatomic, strong) NSButton *emptyButton;
@property (nonatomic, copy) NSArray<NSView *> *headers;
@end

@implementation OVCRecordPage
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _items = @[];
        NSTextField *title = OVCMakeLabel(OVCStr(@"最近 50 条"), OVCFontBodyMedium(), OVCColor(OVCColorTokenTextPrimary));
        _scanButton = OVCMakeButton(OVCStr(@"扫描最近 24 小时"), self, @selector(scanNow:));
        [_scanButton setImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil]];
        [_scanButton setImagePosition:NSImageLeft];
        _clearButton = OVCMakeButton(OVCStr(@"清空"), self, @selector(clearHistory:));
        _clearButton.contentTintColor = OVCColor(OVCColorTokenDanger);

        OVCSettingsCardView *card = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        for (NSString *header in @[OVCStr(@"验证码"), OVCStr(@"内容摘要"), OVCStr(@"来源"), OVCStr(@"时间")]) {
            NSTextField *label = OVCMakeLabel(header, OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextTertiary));
            [card addSubview:label];
        }
        _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
        _table.rowHeight = 34;
        _table.intercellSpacing = NSMakeSize(0, 0);
        _table.backgroundColor = [NSColor clearColor];
        _table.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
        _table.gridColor = [OVCColor(OVCColorTokenStroke) colorWithAlphaComponent:0.55];
        _table.headerView = nil;
        _table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
        _table.allowsMultipleSelection = NO;
        _table.dataSource = self;
        _table.delegate = self;
        _table.target = self;
        _table.doubleAction = @selector(copySelected:);
        NSTableColumn *code = [[NSTableColumn alloc] initWithIdentifier:@"code"];
        code.width = 82; code.minWidth = 78;
        NSTableColumn *summary = [[NSTableColumn alloc] initWithIdentifier:@"summary"];
        summary.width = 190; summary.minWidth = 160;
        NSTableColumn *sender = [[NSTableColumn alloc] initWithIdentifier:@"sender"];
        sender.width = 150; sender.minWidth = 120;
        NSTableColumn *time = [[NSTableColumn alloc] initWithIdentifier:@"time"];
        time.width = 110; time.minWidth = 100;
        [_table addTableColumn:code];
        [_table addTableColumn:summary];
        [_table addTableColumn:sender];
        [_table addTableColumn:time];
        _table.columnAutoresizingStyle = NSTableViewNoColumnAutoresizing;

        _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        _scrollView.hasVerticalScroller = YES;
        _scrollView.autohidesScrollers = YES;
        _scrollView.borderType = NSNoBorder;
        _scrollView.drawsBackground = NO;
        _scrollView.documentView = _table;
        _scrollView.contentView.drawsBackground = NO;
        [card addSubview:_scrollView];

        _emptyView = [[NSView alloc] initWithFrame:NSZeroRect];
        NSImageView *emptyIcon = OVCMakeSymbol(@"tray", 24, OVCColor(OVCColorTokenTextTertiary));
        NSTextField *emptyTitle = OVCMakeLabel(OVCStr(@"还没有记录"), OVCFontSubhead(), OVCColor(OVCColorTokenTextSecondary));
        NSTextField *emptyDetail = OVCMakeLabel(OVCStr(@"收到验证码短信后会自动出现在这里"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        NSButton *emptyButton = OVCMakeButton(OVCStr(@"扫描最近 24 小时"), self, @selector(scanNow:));
        for (NSView *view in @[emptyIcon, emptyTitle, emptyDetail, emptyButton]) {
            [_emptyView addSubview:view];
        }
        _emptyIcon = emptyIcon; _emptyTitle = emptyTitle; _emptyDetail = emptyDetail; _emptyButton = emptyButton;
        [card addSubview:_emptyView];

        _countLabel = OVCMakeLabel(@"", OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        NSImageView *lock = OVCMakeSymbol(@"lock.fill", 10, OVCColor(OVCColorTokenTextTertiary));
        for (NSView *view in @[title, _scanButton, _clearButton, card, _countLabel, lock]) {
            [self addSubview:view];
        }
        self.card = card;
        self.titleLabel = title;
        self.lockIcon = lock;
        self.headers = card.subviews;
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.titleLabel.frame = NSMakeRect(2, height - 32, 160, 18);
    self.scanButton.frame = NSMakeRect(width - 236, height - 36, 160, 30);
    self.clearButton.frame = NSMakeRect(width - 64, height - 36, 64, 30);
    self.card.frame = NSMakeRect(0, 84, width, 352);
    CGFloat cardH = self.card.bounds.size.height;
    NSArray<NSView *> *headers = self.headers;
    headers[0].frame = NSMakeRect(18, cardH - 30, 70, 16);
    headers[1].frame = NSMakeRect(100, cardH - 30, 170, 16);
    headers[2].frame = NSMakeRect(302, cardH - 30, 110, 16);
    headers[3].frame = NSMakeRect(width - 100, cardH - 30, 80, 16);
    self.scrollView.frame = NSMakeRect(1, 1, width - 2, cardH - 40);
    self.emptyView.frame = NSMakeRect(1, 1, width - 2, cardH - 40);
    self.emptyIcon.frame = NSMakeRect((width - 24) / 2, cardH / 2 + 2, 24, 24);
    self.emptyTitle.frame = NSMakeRect(0, cardH / 2 - 30, width, 20);
    self.emptyTitle.alignment = NSTextAlignmentCenter;
    self.emptyDetail.frame = NSMakeRect(0, cardH / 2 - 50, width, 16);
    self.emptyDetail.alignment = NSTextAlignmentCenter;
    self.emptyButton.frame = NSMakeRect((width - 160) / 2, cardH / 2 - 86, 160, 30);
    self.countLabel.frame = NSMakeRect(20, 56, 260, 16);
    self.lockIcon.frame = NSMakeRect(2, 58, 10, 10);
}
- (void)refresh {
    [self.table reloadData];
    self.emptyView.hidden = self.items.count > 0;
    self.scrollView.hidden = self.items.count == 0;
    self.countLabel.stringValue = [NSString stringWithFormat:OVCStr(@"仅保存在本机 · 共 %lu 条"), (unsigned long)self.items.count];
    self.scanButton.enabled = self.monitoringEnabled;
    self.clearButton.enabled = self.monitoringEnabled && self.items.count > 0;
    self.emptyButton.enabled = self.monitoringEnabled;
    self.table.enabled = self.monitoringEnabled;
    self.card.alphaValue = self.monitoringEnabled ? 1.0 : 0.58;
    self.scanButton.alphaValue = self.monitoringEnabled ? 1.0 : 0.48;
    self.clearButton.alphaValue = self.monitoringEnabled ? 1.0 : 0.48;
}
- (void)setMonitoringEnabled:(BOOL)enabled {
    [super setMonitoringEnabled:enabled];
    [self refresh];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return (NSInteger)self.items.count; }
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.items.count) { return nil; }
    OVCHistoryItem *item = self.items[(NSUInteger)row];
    NSString *text = @"";
    NSFont *font = OVCFontCaption();
    NSColor *color = OVCColor(OVCColorTokenTextSecondary);
    if ([tableColumn.identifier isEqualToString:@"code"]) {
        text = item.code ?: @"";
        font = OVCFontMono();
        color = OVCColor(OVCColorTokenTextPrimary);
    } else if ([tableColumn.identifier isEqualToString:@"summary"]) {
        NSString *summary = item.summary.length > 0 ? item.summary : OVCStr(@"暂无摘要");
        if (summary.length > 16) {
            NSRange range = [summary rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 15)];
            summary = [[summary substringWithRange:range] stringByAppendingString:@"…"];
        }
        text = summary;
        color = OVCColor(OVCColorTokenTextSecondary);
    } else if ([tableColumn.identifier isEqualToString:@"sender"]) {
        text = item.sender ?: OVCStr(@"未知来源");
    } else {
        static NSDateFormatter *formatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"MM-dd HH:mm";
        });
        text = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:item.date]] ?: @"";
        color = OVCColor(OVCColorTokenTextTertiary);
    }
    NSView *cell = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 34)];
    NSTextField *label = OVCMakeLabel(text, font, color);
    label.frame = NSMakeRect(0, 9, tableColumn.width - 8, 16);
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.cell.truncatesLastVisibleLine = YES;
    label.toolTip = text;
    [cell addSubview:label];
    return cell;
}
- (void)copySelected:(id)sender {
    NSInteger row = self.table.clickedRow >= 0 ? self.table.clickedRow : self.table.selectedRow;
    if (row < 0 || row >= (NSInteger)self.items.count) { return; }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:self.items[(NSUInteger)row].code ?: @"" forType:NSPasteboardTypeString];
    [self.host pageShowToast:OVCStr(@"验证码已复制")];
}
- (void)scanNow:(id)sender { [self.host pageScan]; }
- (void)clearHistory:(id)sender { [self.host pageClearHistory]; }
@end


#pragma mark - 外观页

@interface OVCPanelPreviewView : NSView
@property (nonatomic, assign) OVCPanelTheme theme;
@property (nonatomic, assign) OVCPanelSizePreset sizePreset;
@property (nonatomic, assign) double transparency;
- (void)applyConfiguration;
@end

@implementation OVCPanelPreviewView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = OVCPanelThemeAurora;
        _sizePreset = OVCPanelSizeStandard;
        _transparency = 0.12;
        [self applyConfiguration];
    }
    return self;
}
- (void)setTheme:(OVCPanelTheme)theme { _theme = theme; [self setNeedsDisplay:YES]; }
- (void)setSizePreset:(OVCPanelSizePreset)sizePreset {
    _sizePreset = sizePreset;
    NSSize size = OVCPanelSizeForPreset(sizePreset);
    self.frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, size.width, size.height);
    [self setNeedsDisplay:YES];
}
- (void)setTransparency:(double)transparency { _transparency = transparency; [self setNeedsDisplay:YES]; }
- (void)applyConfiguration { [self setNeedsDisplay:YES]; }

- (void)drawRect:(NSRect)dirtyRect {
    CGFloat radius = OVCPanelCornerRadiusForPreset(self.sizePreset);
    NSRect card = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:card xRadius:radius yRadius:radius];
    CGFloat opacity = 1.0 - self.transparency;
    if (OVCPanelThemeUsesOpaqueBackground(self.theme)) { opacity = 1.0; }
    NSColor *start = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientStart);
    NSColor *end = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientEnd);
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[start colorWithAlphaComponent:opacity]
                                                        endingColor:[end colorWithAlphaComponent:opacity]];
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor.blackColor colorWithAlphaComponent:0.18];
    shadow.shadowBlurRadius = 12;
    shadow.shadowOffset = NSMakeSize(0, -4);
    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    [[NSColor colorWithWhite:0.0 alpha:0.01] setFill];
    [path fill];
    [NSGraphicsContext restoreGraphicsState];
    [gradient drawInBezierPath:path angle:-48];

    NSColor *accent = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleAccent);
    BOOL pure = OVCPanelThemeUsesOpaqueBackground(self.theme);
    if (!pure) {
        NSGradient *glow = [[NSGradient alloc] initWithStartingColor:[accent colorWithAlphaComponent:0.16 * opacity]
                                                         endingColor:[accent colorWithAlphaComponent:0.0]];
        [glow drawInBezierPath:path relativeCenterPosition:NSMakePoint(-0.58, 0.62)];
    }
    [[OVCPanelThemeColor(self.theme, OVCPanelThemeRoleHighlight) colorWithAlphaComponent:0.34 * opacity] setStroke];
    path.lineWidth = 1.0;
    [path stroke];

    NSMutableParagraphStyle *center = [[NSMutableParagraphStyle alloc] init];
    center.alignment = NSTextAlignmentCenter;
    center.lineBreakMode = NSLineBreakByTruncatingTail;
    CGFloat codeSize = OVCPanelCodeFontSizeForPreset(self.sizePreset);
    CGFloat sourceSize = OVCPanelSourceFontSizeForPreset(self.sizePreset);
    NSString *source = OVCStr(@"一码 · 1069***213");
    NSString *code = @"482913";
    NSAttributedString *sourceText = [[NSAttributedString alloc] initWithString:source attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:sourceSize weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextSecondary),
        NSParagraphStyleAttributeName: center,
    }];
    NSAttributedString *codeText = [[NSAttributedString alloc] initWithString:code attributes:@{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:codeSize weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextPrimary),
        NSKernAttributeName: @(codeSize * 0.08),
        NSParagraphStyleAttributeName: center,
    }];
    NSSize sourceSizeValue = sourceText.size;
    NSSize codeSizeValue = codeText.size;
    CGFloat totalH = sourceSizeValue.height + 3 + codeSizeValue.height;
    CGFloat codeY = floor((self.bounds.size.height - totalH) / 2) + 1;
    CGFloat sourceY = codeY + codeSizeValue.height + 3;
    [sourceText drawInRect:NSMakeRect(10, sourceY, self.bounds.size.width - 20, sourceSizeValue.height)];
    [codeText drawInRect:NSMakeRect(8, codeY, self.bounds.size.width - 16, codeSizeValue.height)];

    CGFloat barHeight = 2.5;
    NSRect track = NSMakeRect(14, 6, self.bounds.size.width - 28, barHeight);
    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:track xRadius:barHeight / 2 yRadius:barHeight / 2];
    [[OVCPanelThemeColor(self.theme, OVCPanelThemeRoleTextPrimary) colorWithAlphaComponent:0.10] setFill];
    [trackPath fill];
    NSRect fill = track;
    fill.size.width *= 0.72;
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fill xRadius:barHeight / 2 yRadius:barHeight / 2];
    [accent setFill];
    [fillPath fill];
}
@end

@interface OVCThemeSwatchView : NSView
@property (nonatomic, assign) OVCPanelTheme theme;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, copy, nullable) void (^onSelect)(OVCPanelTheme theme);
@property (nonatomic, strong) NSTextField *nameLabel;
@end

@implementation OVCThemeSwatchView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _nameLabel = OVCMakeLabel(@"", OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        _nameLabel.alignment = NSTextAlignmentCenter;
        [self addSubview:_nameLabel];
    }
    return self;
}
- (void)setTheme:(OVCPanelTheme)theme {
    _theme = theme;
    self.nameLabel.stringValue = OVCPanelThemeName(theme);
    [self setNeedsDisplay:YES];
}
- (void)setSelected:(BOOL)selected {
    _selected = selected;
    self.nameLabel.textColor = selected ? OVCColor(OVCColorTokenTextPrimary) : OVCColor(OVCColorTokenTextSecondary);
    [self setNeedsDisplay:YES];
}
- (void)layout {
    [super layout];
    self.nameLabel.frame = NSMakeRect(0, 5, self.bounds.size.width, 14);
}
- (void)drawRect:(NSRect)dirtyRect {
    NSRect card = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:card xRadius:9 yRadius:9];
    [OVCColor(OVCColorTokenSurfaceAlt) setFill];
    [cardPath fill];
    NSColor *stroke = self.selected ? OVCColor(OVCColorTokenAccent) : OVCColor(OVCColorTokenStroke);
    [stroke setStroke];
    cardPath.lineWidth = self.selected ? 1.6 : 1.0;
    [cardPath stroke];

    NSRect swatch = NSMakeRect(7, 24, self.bounds.size.width - 14, self.bounds.size.height - 30);
    NSBezierPath *swatchPath = [NSBezierPath bezierPathWithRoundedRect:swatch xRadius:6 yRadius:6];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientStart)
                                                        endingColor:OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientEnd)];
    [gradient drawInBezierPath:swatchPath angle:-48];
    [[OVCColor(OVCColorTokenStroke) colorWithAlphaComponent:0.8] setStroke];
    swatchPath.lineWidth = 0.7;
    [swatchPath stroke];
    NSColor *accent = OVCPanelThemeColor(self.theme, OVCPanelThemeRoleAccent);
    [accent setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMidX(swatch) - 4, NSMidY(swatch) - 4, 8, 8)] fill];

    if (self.selected) {
        NSBezierPath *check = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMaxX(card) - 19, NSMaxY(card) - 19, 14, 14)];
        [accent setFill];
        [check fill];
        NSBezierPath *tick = [NSBezierPath bezierPath];
        [tick moveToPoint:NSMakePoint(NSMaxX(card) - 15.5, NSMaxY(card) - 12)];
        [tick lineToPoint:NSMakePoint(NSMaxX(card) - 13, NSMaxY(card) - 15)];
        [tick lineToPoint:NSMakePoint(NSMaxX(card) - 8.5, NSMaxY(card) - 9)];
        // 勾选底色跟随主题强调色，勾本身用渐变起始色，保证纯黑等浅强调色上仍可见。
        [OVCPanelThemeColor(self.theme, OVCPanelThemeRoleGradientStart) setStroke];
        tick.lineWidth = 1.7;
        tick.lineCapStyle = NSLineCapStyleRound;
        tick.lineJoinStyle = NSLineJoinStyleRound;
        [tick stroke];
    }
}
- (void)mouseDown:(NSEvent *)event {
    if (self.onSelect) { self.onSelect(self.theme); }
}
- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityLabel { return OVCPanelThemeName(self.theme); }
- (NSAccessibilityRole)accessibilityRole { return NSAccessibilityButtonRole; }
@end

@interface OVCAppearancePage : OVCPageView
@property (nonatomic, strong) OVCSettingsCardView *stage;
@property (nonatomic, strong) NSTextField *stageBadge;
@property (nonatomic, strong) NSTextField *stageHint;
@property (nonatomic, strong) OVCPanelPreviewView *mock;
@property (nonatomic, copy) NSArray<OVCThemeSwatchView *> *swatches;
@property (nonatomic, strong) NSTextField *themeLabel;
@property (nonatomic, strong) NSTextField *sizeLabel;
@property (nonatomic, strong) NSTextField *transparencyLabel;
@property (nonatomic, strong) NSTextField *transparencyValue;
@property (nonatomic, strong) NSSegmentedControl *sizeControl;
@property (nonatomic, strong) NSSlider *transparencySlider;
@property (nonatomic, strong) NSTextField *footnote;
@end

@implementation OVCAppearancePage
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _stage = [[OVCSettingsCardView alloc] initWithFrame:NSZeroRect];
        _stageBadge = OVCMakeLabel(OVCStr(@"实时预览"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextTertiary));
        _mock = [[OVCPanelPreviewView alloc] initWithFrame:NSZeroRect];
        _stageHint = OVCMakeLabel(OVCStr(@"点击数字即可填入当前输入框"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        _stageHint.alignment = NSTextAlignmentCenter;
        for (NSView *view in @[_stageBadge, _mock, _stageHint]) { [_stage addSubview:view]; }

        _themeLabel = OVCMakeLabel(OVCStr(@"配色"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        NSMutableArray *swatches = [NSMutableArray array];
        for (NSInteger i = 0; i < OVCPanelThemeCount; i++) {
            OVCThemeSwatchView *swatch = [[OVCThemeSwatchView alloc] initWithFrame:NSZeroRect];
            swatch.theme = (OVCPanelTheme)i;
            __weak typeof(self) weakSelf = self;
            swatch.onSelect = ^(OVCPanelTheme theme) {
                [weakSelf applyTheme:theme];
            };
            [self addSubview:swatch];
            [swatches addObject:swatch];
        }
        _swatches = swatches;

        _sizeLabel = OVCMakeLabel(OVCStr(@"面板尺寸"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        _sizeControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
        _sizeControl.segmentCount = 3;
        [_sizeControl setLabel:OVCStr(@"紧凑") forSegment:0];
        [_sizeControl setLabel:OVCStr(@"标准") forSegment:1];
        [_sizeControl setLabel:OVCStr(@"宽适") forSegment:2];
        _sizeControl.segmentStyle = NSSegmentStyleRounded;
        _sizeControl.controlSize = NSControlSizeSmall;
        _sizeControl.target = self;
        _sizeControl.action = @selector(changeSize:);

        _transparencyLabel = OVCMakeLabel(OVCStr(@"背景透明度"), OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextSecondary));
        _transparencyValue = OVCMakeLabel(@"12%", OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextTertiary));
        _transparencyValue.alignment = NSTextAlignmentRight;
        _transparencySlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
        _transparencySlider.minValue = 0;
        _transparencySlider.maxValue = 100;
        _transparencySlider.doubleValue = 12;
        _transparencySlider.continuous = YES;
        _transparencySlider.controlSize = NSControlSizeSmall;
        _transparencySlider.target = self;
        _transparencySlider.action = @selector(changeTransparency:);

        _footnote = OVCMakeLabel(OVCStr(@"配色、尺寸与透明度即时生效，下一次弹窗使用新样式"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
        for (NSView *view in @[_stage, _themeLabel, _sizeLabel, _sizeControl,
                               _transparencyLabel, _transparencyValue, _transparencySlider, _footnote]) {
            [self addSubview:view];
        }
        [self refresh];
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.stage.frame = NSMakeRect(0, height - 200, width, 200);
    self.stageBadge.frame = NSMakeRect(14, 174, 100, 16);
    CGFloat mockW = self.mock.bounds.size.width;
    CGFloat mockH = self.mock.bounds.size.height;
    self.mock.frame = NSMakeRect((width - mockW) / 2, 52, mockW, mockH);
    self.stageHint.frame = NSMakeRect(0, 24, width, 16);

    self.themeLabel.frame = NSMakeRect(2, height - 226, 80, 16);
    CGFloat inset = 2;
    CGFloat gap = 7;
    CGFloat swatchW = floor((width - inset * 2 - gap * (OVCPanelThemeCount - 1)) / OVCPanelThemeCount);
    for (NSInteger i = 0; i < (NSInteger)self.swatches.count; i++) {
        self.swatches[(NSUInteger)i].frame = NSMakeRect(inset + i * (swatchW + gap), height - 300, swatchW, 64);
    }
    self.sizeLabel.frame = NSMakeRect(2, height - 328, 100, 16);
    self.sizeControl.frame = NSMakeRect(0, height - 362, 220, 24);
    self.transparencyLabel.frame = NSMakeRect(260, height - 328, 200, 16);
    self.transparencyValue.frame = NSMakeRect(width - 52, height - 328, 52, 16);
    self.transparencySlider.frame = NSMakeRect(260, height - 360, width - 260, 22);
    self.footnote.frame = NSMakeRect(2, 82, width - 4, 16);
}
- (void)refresh {
    OVCPrefs *prefs = [OVCPrefs shared];
    NSInteger theme = prefs.panelTheme;
    for (OVCThemeSwatchView *swatch in self.swatches) {
        swatch.selected = (swatch.theme == theme);
    }
    self.mock.theme = (OVCPanelTheme)theme;
    self.mock.sizePreset = (OVCPanelSizePreset)prefs.panelSize;
    self.mock.transparency = prefs.panelTransparency;
    self.sizeControl.selectedSegment = prefs.panelSize;
    self.transparencySlider.doubleValue = prefs.panelTransparency * 100.0;
    [self updateTransparencyAvailabilityForTheme:(OVCPanelTheme)theme];
    [self setNeedsLayout:YES];
}
- (void)applyTheme:(OVCPanelTheme)theme {
    self.mock.theme = theme;
    for (OVCThemeSwatchView *swatch in self.swatches) {
        swatch.selected = (swatch.theme == theme);
    }
    [self updateTransparencyAvailabilityForTheme:theme];
    [self.host pageSetPanelTheme:theme];
}

- (void)updateTransparencyAvailabilityForTheme:(OVCPanelTheme)theme {
    BOOL opaque = OVCPanelThemeUsesOpaqueBackground(theme);
    self.transparencySlider.enabled = !opaque;
    if (opaque) {
        self.transparencyValue.stringValue = OVCStr(@"不透明");
        self.footnote.stringValue = OVCStr(@"纯白/纯黑为不透明高对比预设，其余配色支持背景透明度");
    } else {
        self.transparencyValue.stringValue = [NSString stringWithFormat:@"%.0f%%", self.transparencySlider.doubleValue];
        self.footnote.stringValue = OVCStr(@"配色、尺寸与透明度即时生效，下一次弹窗使用新样式");
    }
}
- (void)changeSize:(NSSegmentedControl *)sender {
    self.mock.sizePreset = (OVCPanelSizePreset)sender.selectedSegment;
    [self.host pageSetPanelSize:sender.selectedSegment];
    [self setNeedsLayout:YES];
}
- (void)changeTransparency:(NSSlider *)sender {
    double value = round(sender.doubleValue);
    self.transparencyValue.stringValue = [NSString stringWithFormat:@"%.0f%%", value];
    self.mock.transparency = value / 100.0;
    [self.host pageSetPanelTransparency:value / 100.0];
}
@end

#pragma mark - 关于页

@interface OVCGitHubLinkView : NSView
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, assign) BOOL hovered;
@end

@implementation OVCGitHubLinkView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        NSImage *mark = [NSImage imageNamed:@"GitHubMark"];
        mark.template = YES;
        mark.size = NSMakeSize(14, 14);
        _iconView.image = mark;
        _iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
        _iconView.contentTintColor = OVCColor(OVCColorTokenAccent);

        _label = OVCMakeLabel([NSString stringWithFormat:@"GitHub · %@", OVCGitHubRepositoryDisplay],
                              OVCFontCaption(), OVCColor(OVCColorTokenAccent));
        _label.alignment = NSTextAlignmentLeft;
        _label.lineBreakMode = NSLineBreakByClipping;
        _label.cell.truncatesLastVisibleLine = NO;
        [self addSubview:_iconView];
        [self addSubview:_label];
        self.toolTip = OVCGitHubRepositoryURL;
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat iconSize = 14.0;
    CGFloat gap = 6.0;
    NSDictionary *attributes = @{NSFontAttributeName: self.label.font};
    CGFloat textWidth = ceil([self.label.stringValue sizeWithAttributes:attributes].width) + 8.0;
    CGFloat totalWidth = iconSize + gap + textWidth;
    CGFloat startX = MAX(0, (NSWidth(self.bounds) - totalWidth) / 2.0);
    self.iconView.frame = NSMakeRect(startX, (NSHeight(self.bounds) - iconSize) / 2.0, iconSize, iconSize);
    self.label.frame = NSMakeRect(startX + iconSize + gap, (NSHeight(self.bounds) - 16.0) / 2.0, textWidth, 16.0);
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) { [self removeTrackingArea:area]; }
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                          owner:self
                                                       userInfo:nil]];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseEntered:(NSEvent *)event {
    self.hovered = YES;
    self.label.textColor = OVCColor(OVCColorTokenAccentPressed);
    self.iconView.contentTintColor = OVCColor(OVCColorTokenAccentPressed);
    [[NSCursor pointingHandCursor] set];
}
- (void)mouseExited:(NSEvent *)event {
    self.hovered = NO;
    self.label.textColor = OVCColor(OVCColorTokenAccent);
    self.iconView.contentTintColor = OVCColor(OVCColorTokenAccent);
    [[NSCursor arrowCursor] set];
}
- (void)mouseDown:(NSEvent *)event {
    NSURL *url = [NSURL URLWithString:self.urlString];
    if (url) { [[NSWorkspace sharedWorkspace] openURL:url]; }
}
- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityLabel { return self.label.stringValue; }
- (NSAccessibilityRole)accessibilityRole { return NSAccessibilityLinkRole; }
- (BOOL)accessibilityPerformPress {
    NSURL *url = [NSURL URLWithString:self.urlString];
    if (!url) { return NO; }
    [[NSWorkspace sharedWorkspace] openURL:url];
    return YES;
}
@end

@interface OVCAboutPage : OVCPageView
@property (nonatomic, strong) NSImageView *logo;
@property (nonatomic, strong) NSTextField *name;
@property (nonatomic, strong) NSTextField *version;
@property (nonatomic, strong) NSTextField *tagline;
@property (nonatomic, strong) NSTextField *intro;
@property (nonatomic, strong) OVCAccentRuleView *rule;
@property (nonatomic, strong) OVCGitHubLinkView *githubLink;
@end

@implementation OVCAboutPage
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _logo = [[NSImageView alloc] initWithFrame:NSZeroRect];
        _logo.image = [OVCIconFactory appIconImageWithSize:72];
        _logo.imageScaling = NSImageScaleProportionallyUpOrDown;
        _name = OVCMakeLabel(OVCStr(@"一码"), OVCFontDisplay(), OVCColor(OVCColorTokenTextPrimary));
        _name.alignment = NSTextAlignmentCenter;
        NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"0.5.3";
        _version = OVCMakeLabel([NSString stringWithFormat:@"OneVerifyCode · %@ beta", version], OVCFontCaptionMedium(), OVCColor(OVCColorTokenTextTertiary));
        _version.alignment = NSTextAlignmentCenter;
        _tagline = OVCMakeLabel(OVCStr(@"把验证码这件事，做到刚刚好。"), OVCFontTitle(), OVCColor(OVCColorTokenTextPrimary));
        _tagline.alignment = NSTextAlignmentCenter;
        NSString *introText = OVCStr(@"读取 iPhone 转发到 Mac 的短信/信息，在本地提取验证码；可快速填入、复制到剪切板，数据不联网安全可靠。");
        introText = [introText stringByReplacingOccurrencesOfString:@"；" withString:@"；\n"];
        _intro = OVCMakeMultilineLabel(introText, OVCFontBody(), OVCColor(OVCColorTokenTextSecondary), 3);
        _intro.alignment = NSTextAlignmentCenter;
        _rule = [[OVCAccentRuleView alloc] initWithFrame:NSZeroRect];

        _githubLink = [[OVCGitHubLinkView alloc] initWithFrame:NSZeroRect];
        _githubLink.urlString = OVCGitHubRepositoryURL;
        for (NSView *view in @[_logo, _name, _version, _tagline, _intro, _rule, _githubLink]) { [self addSubview:view]; }
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = self.bounds.size.width;
    self.logo.frame = NSMakeRect((width - 72) / 2, 330, 72, 72);
    self.name.frame = NSMakeRect(0, 286, width, 32);
    self.version.frame = NSMakeRect(0, 264, width, 16);
    self.rule.frame = NSMakeRect((width - 36) / 2, 236, 36, 2);
    self.tagline.frame = NSMakeRect(0, 196, width, 24);
    self.intro.frame = NSMakeRect(48, 140, width - 96, 54);
    self.githubLink.frame = NSMakeRect(0, 42, width, 22);
}
@end

#pragma mark - 导航

@protocol OVCNavHost <NSObject>
- (void)selectSection:(NSInteger)index animated:(BOOL)animated;
@end

@interface OVCNavItemView : NSView
@property (nonatomic, weak, nullable) id<OVCNavHost> host;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) OVCBadgeView *badgeView;
@property (nonatomic, strong) NSView *hoverView;
@property (nonatomic, assign) BOOL selected;
- (void)setBadgeText:(NSString *)text;
@end

@implementation OVCNavItemView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _hoverView = [[NSView alloc] initWithFrame:NSZeroRect];
        _hoverView.wantsLayer = YES;
        _hoverView.alphaValue = 0;
        _iconView = OVCMakeSymbol(@"circle", 16, OVCColor(OVCColorTokenTextSecondary));
        _titleLabel = OVCMakeLabel(@"", OVCFontBodyMedium(), OVCColor(OVCColorTokenTextPrimary));
        _badgeView = [[OVCBadgeView alloc] initWithFrame:NSZeroRect];
        _badgeView.hidden = YES;
        for (NSView *view in @[_hoverView, _iconView, _titleLabel, _badgeView]) {
            [self addSubview:view];
        }
    }
    return self;
}
- (void)layout {
    [super layout];
    self.hoverView.frame = NSInsetRect(self.bounds, 4, 2);
    self.iconView.frame = NSMakeRect(12, (self.bounds.size.height - 16) / 2, 16, 16);
    self.titleLabel.frame = NSMakeRect(38, (self.bounds.size.height - 18) / 2, self.bounds.size.width - 72, 18);
    self.badgeView.frame = NSMakeRect(self.bounds.size.width - 34, (self.bounds.size.height - 20) / 2, 24, 20);
}
- (void)drawRect:(NSRect)dirtyRect {
    if (self.hoverView.alphaValue > 0.01) {
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 4, 2)
                                                             xRadius:8 yRadius:8];
        [[OVCColor(OVCColorTokenTextPrimary) colorWithAlphaComponent:0.055] setFill];
        [path fill];
    }
}
- (void)setSelected:(BOOL)selected {
    _selected = selected;
    self.titleLabel.textColor = selected ? OVCColor(OVCColorTokenAccent) : OVCColor(OVCColorTokenTextPrimary);
    self.iconView.contentTintColor = selected ? OVCColor(OVCColorTokenAccent) : OVCColor(OVCColorTokenTextSecondary);
}
- (void)setBadgeText:(NSString *)text {
    self.badgeView.hidden = text.length == 0;
    self.badgeView.text = text;
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) { [self removeTrackingArea:area]; }
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:area];
}
- (void)mouseEntered:(NSEvent *)event {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.12;
        self.hoverView.animator.alphaValue = 1.0;
    } completionHandler:nil];
}
- (void)mouseExited:(NSEvent *)event {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.12;
        self.hoverView.animator.alphaValue = 0.0;
    } completionHandler:nil];
}
- (void)mouseDown:(NSEvent *)event {
    [self.host selectSection:self.index animated:YES];
}
- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityLabel { return self.titleLabel.stringValue; }
- (NSAccessibilityRole)accessibilityRole { return NSAccessibilityButtonRole; }
@end

#pragma mark - 侧栏拖拽

/// 左侧空白区域的拖拽层。设置窗口本身不再响应背景拖拽，避免在右侧内容区误移动窗口。
@interface OVCSidebarDragView : NSView
@end

@implementation OVCSidebarDragView
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (void)mouseDown:(NSEvent *)event {
    [self.window performWindowDragWithEvent:event];
}
@end

#pragma mark - 设置视图

@interface OVCSettingsView : NSView
- (void)selectSection:(NSInteger)index animated:(BOOL)animated;
@end

@interface OVCSettingsView () <OVCSettingsPageHost, OVCNavHost>
@property (nonatomic, weak, nullable) OVCSettingsWindow *owner;
@property (nonatomic, copy) NSArray<OVCHistoryItem *> *items;
@property (nonatomic, assign) BOOL fdaGranted;
@property (nonatomic, assign) BOOL axGranted;
@property (nonatomic, assign) BOOL monitoringEnabled;
@property (nonatomic, assign) BOOL statusError;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, strong) NSImageView *appIcon;
@property (nonatomic, strong) NSTextField *appName;
@property (nonatomic, strong) NSTextField *appVersion;
@property (nonatomic, strong) NSView *selectionView;
@property (nonatomic, strong) NSView *selectionBar;
@property (nonatomic, copy) NSArray<OVCNavItemView *> *navItems;
@property (nonatomic, strong) OVCSidebarDragView *sidebarDragView;
@property (nonatomic, strong) OVCSidebarDragView *headerDragView;
@property (nonatomic, strong) NSTextField *pageTitle;
@property (nonatomic, strong) NSTextField *pageSubtitle;
@property (nonatomic, strong) NSImageView *privacyIcon;
@property (nonatomic, strong) NSTextField *privacyLabel;
@property (nonatomic, strong) NSTextField *versionLabel;
@property (nonatomic, strong) NSTextField *languageLabel;
@property (nonatomic, strong) NSPopUpButton *languageControl;
@property (nonatomic, strong) OVCStatusPillView *statusPill;
@property (nonatomic, strong) NSView *pageContainer;
@property (nonatomic, strong) NSArray<OVCPageView *> *pages;
@property (nonatomic, strong) OVCPermissionPage *permissionPage;
@property (nonatomic, strong) OVCBehaviorPage *behaviorPage;
@property (nonatomic, strong) OVCAppearancePage *appearancePage;
@property (nonatomic, strong) OVCRulesPage *rulesPage;
@property (nonatomic, strong) OVCRecordPage *recordPage;
@property (nonatomic, strong) OVCAboutPage *aboutPage;
@property (nonatomic, strong) OVCToastView *toast;
@property (nonatomic, strong) NSTimer *toastTimer;
@property (nonatomic, assign) NSInteger selectedSection;
@end

@implementation OVCSettingsView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _items = @[];
        _statusText = OVCStr(@"正在启动…");
        _monitoringEnabled = YES;
        _selectedSection = 0;
        [self buildSubviews];
        [self reloadUI];
    }
    return self;
}

- (BOOL)isFlipped { return NO; }

- (void)drawRect:(NSRect)dirtyRect {
    [OVCColor(OVCColorTokenSurface) setFill];
    NSRectFill(self.bounds);
    [OVCColor(OVCColorTokenSurfaceAlt) setFill];
    NSRectFill(NSMakeRect(0, 0, OVCSidebarWidth, self.bounds.size.height));
    [OVCColor(OVCColorTokenStroke) setFill];
    NSRectFill(NSMakeRect(OVCSidebarWidth, 0, 1, self.bounds.size.height));
}

- (void)buildSubviews {
    _sidebarDragView = [[OVCSidebarDragView alloc] initWithFrame:NSZeroRect];
    [self addSubview:_sidebarDragView];

    _appIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _appIcon.image = [OVCIconFactory appIconImageWithSize:44];
    _appIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    _appName = OVCMakeLabel(OVCStr(@"一码"), OVCFontTitle(), OVCColor(OVCColorTokenTextPrimary));
    NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"0.5.3";
    _appVersion = OVCMakeLabel([NSString stringWithFormat:@"OneVerifyCode · %@", version], OVCFontCaption(), OVCColor(OVCColorTokenTextSecondary));

    _selectionView = [[NSView alloc] initWithFrame:NSZeroRect];
    _selectionView.wantsLayer = YES;
    _selectionView.layer.cornerRadius = 8;
    _selectionView.layer.backgroundColor = [OVCColor(OVCColorTokenAccentSoft) CGColor];
    _selectionView.layer.borderColor = [OVCColor(OVCColorTokenAccent) colorWithAlphaComponent:0.18].CGColor;
    _selectionView.layer.borderWidth = 0.8;
    // 左侧强调条
    NSView *bar = [[NSView alloc] initWithFrame:NSZeroRect];
    bar.wantsLayer = YES;
    bar.layer.cornerRadius = 1.5;
    bar.layer.backgroundColor = [OVCColor(OVCColorTokenAccent) CGColor];
    self.selectionBar = bar;
    [_selectionView addSubview:bar];
    [self updateSelectionAppearance];

    NSArray<NSString *> *titles = @[OVCStr(@"权限"), OVCStr(@"行为"), OVCStr(@"外观"), OVCStr(@"识别"), OVCStr(@"记录"), OVCStr(@"关于")];
    NSArray<NSString *> *symbols = @[@"lock.shield", @"slider.horizontal.3", @"paintpalette", @"text.magnifyingglass", @"clock.arrow.circlepath", @"info.circle"];
    [self addSubview:_selectionView];
    NSMutableArray<OVCNavItemView *> *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < titles.count; i++) {
        OVCNavItemView *item = [[OVCNavItemView alloc] initWithFrame:NSZeroRect];
        item.host = self;
        item.index = (NSInteger)i;
        item.titleLabel.stringValue = titles[i];
        item.iconView.image = [NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:nil];
        [self addSubview:item];
        [items addObject:item];
    }
    _navItems = items;

    NSImageView *privacyIcon = OVCMakeSymbol(@"lock.shield", 13, OVCColor(OVCColorTokenTextTertiary));
    NSTextField *privacy = OVCMakeLabel(OVCStr(@"本地运行 · 短信只读"), OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
    NSTextField *versionLabel = OVCMakeLabel([NSString stringWithFormat:@"v%@ beta", version], OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
    NSTextField *languageLabel = OVCMakeLabel(@"界面语言", OVCFontCaption(), OVCColor(OVCColorTokenTextTertiary));
    NSPopUpButton *languageControl = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [languageControl addItemsWithTitles:@[OVCStr(@"跟随系统"), @"中文", @"English"]];
    languageControl.controlSize = NSControlSizeSmall;
    languageControl.font = OVCFontCaption();
    languageControl.target = self;
    languageControl.action = @selector(changeLanguage:);
    [languageControl selectItemAtIndex:[OVCPrefs shared].appLanguage];

    _pageTitle = OVCMakeLabel(OVCStr(@"权限与隐私"), OVCFontDisplay(), OVCColor(OVCColorTokenTextPrimary));
    _pageSubtitle = OVCMakeLabel(OVCStr(@"读取短信与定位输入框所需权限"), OVCFontBody(), OVCColor(OVCColorTokenTextSecondary));
    _statusPill = [[OVCStatusPillView alloc] initWithFrame:NSZeroRect];

    _pageContainer = [[NSView alloc] initWithFrame:NSZeroRect];
    _pageContainer.wantsLayer = YES;
    _permissionPage = [[OVCPermissionPage alloc] initWithFrame:NSZeroRect];
    _behaviorPage = [[OVCBehaviorPage alloc] initWithFrame:NSZeroRect];
    _appearancePage = [[OVCAppearancePage alloc] initWithFrame:NSZeroRect];
    _rulesPage = [[OVCRulesPage alloc] initWithFrame:NSZeroRect];
    _recordPage = [[OVCRecordPage alloc] initWithFrame:NSZeroRect];
    _aboutPage = [[OVCAboutPage alloc] initWithFrame:NSZeroRect];
    _pages = @[_permissionPage, _behaviorPage, _appearancePage, _rulesPage, _recordPage, _aboutPage];
    for (OVCPageView *page in _pages) {
        page.host = self;
        page.hidden = YES;
        page.alphaValue = 1.0;
        page.wantsLayer = YES;
        page.frame = _pageContainer.bounds;
        [_pageContainer addSubview:page];
    }

    _toast = [[OVCToastView alloc] initWithFrame:NSZeroRect];
    _toast.alphaValue = 0;
    _toast.hidden = YES;

    for (NSView *view in @[_appIcon, _appName, _appVersion, _selectionView,
                           privacyIcon, privacy, versionLabel, languageLabel, languageControl,
                           _pageTitle, _pageSubtitle, _statusPill, _pageContainer, _toast]) {
        if (view != _selectionView) { [self addSubview:view]; }
    }
    // _selectionView 需要位于导航项下方，已在导航项之前添加。
    self.privacyIcon = privacyIcon;
    self.privacyLabel = privacy;
    self.versionLabel = versionLabel;
    self.languageLabel = languageLabel;
    self.languageControl = languageControl;

    // 顶部左侧也属于拖拽区；此层只覆盖静态品牌区，不遮挡下方导航和控件。
    _headerDragView = [[OVCSidebarDragView alloc] initWithFrame:NSZeroRect];
    [self addSubview:_headerDragView];

    [self selectSection:0 animated:NO];
}

- (void)layout {
    [super layout];
    CGFloat height = self.bounds.size.height;

    self.sidebarDragView.frame = NSMakeRect(0, 0, OVCSidebarWidth, height);
    self.headerDragView.frame = NSMakeRect(0, height - 96, OVCSidebarWidth, 96);
    self.appIcon.frame = NSMakeRect(20, height - 76, 44, 44);
    self.appName.frame = NSMakeRect(76, height - 54, 138, 22);
    self.appVersion.frame = NSMakeRect(76, height - 72, 140, 14);

    CGFloat navY = height - 148;
    for (OVCNavItemView *item in self.navItems) {
        item.frame = NSMakeRect(14, navY, OVCSidebarWidth - 28, 36);
        navY -= 42;
    }
    OVCNavItemView *selected = self.navItems[(NSUInteger)self.selectedSection];
    self.selectionView.frame = NSInsetRect(selected.frame, 4, 2);
    self.selectionBar.frame = NSMakeRect(4, 8, 3, self.selectionView.bounds.size.height - 16);

    self.languageLabel.frame = NSMakeRect(20, 112, 180, 16);
    self.languageControl.frame = NSMakeRect(18, 82, 184, 24);
    self.privacyIcon.frame = NSMakeRect(20, 58, 13, 13);
    self.privacyLabel.frame = NSMakeRect(40, 56, 160, 16);
    self.versionLabel.frame = NSMakeRect(20, 32, 180, 16);

    CGFloat detailX = OVCSidebarWidth + OVCPageInset;
    self.pageTitle.frame = NSMakeRect(detailX, height - 62, 420, 30);
    self.pageSubtitle.frame = NSMakeRect(detailX, height - 84, 400, 18);
    self.statusPill.frame = NSMakeRect(self.bounds.size.width - OVCPageInset - 220, height - 66, 220, 28);
    self.pageContainer.frame = NSMakeRect(detailX, 18, OVCPageWidth, OVCPageHeight);
    for (OVCPageView *page in self.pages) {
        if (!page.hidden) { page.frame = self.pageContainer.bounds; }
    }
    self.toast.frame = NSMakeRect(detailX + (OVCPageWidth - 160) / 2, 40, 160, 28);
}

- (void)selectSection:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)self.pages.count) { return; }
    NSInteger oldIndex = self.selectedSection;
    self.selectedSection = index;
    for (NSInteger i = 0; i < (NSInteger)self.navItems.count; i++) {
        self.navItems[(NSUInteger)i].selected = (i == index);
    }
    NSArray<NSString *> *titles = @[OVCStr(@"权限与隐私"), OVCStr(@"行为"), OVCStr(@"弹窗外观"), OVCStr(@"规则与识别"), OVCStr(@"最近记录"), OVCStr(@"关于一码")];
    NSArray<NSString *> *subtitles = @[
        OVCStr(@"读取短信与定位输入框所需权限"),
        OVCStr(@"监听、提醒与系统集成"),
        OVCStr(@"7 套配色、尺寸与背景透明度"),
        OVCStr(@"验证码长度、关键词与识别示例"),
        OVCStr(@"只保留最近 50 条，仅保存在本机"),
        OVCStr(@"只做验证码这一件小事"),
    ];
    self.pageTitle.stringValue = titles[(NSUInteger)index];
    self.pageSubtitle.stringValue = subtitles[(NSUInteger)index];

    NSView *newPage = self.pages[(NSUInteger)index];
    NSView *oldPage = self.pages[(NSUInteger)oldIndex];
    if (!animated || oldPage == newPage) {
        for (OVCPageView *page in self.pages) { page.hidden = (page != newPage); page.alphaValue = 1.0; page.frame = self.pageContainer.bounds; }
        [self positionSelectionAnimated:NO];
        return;
    }
    if (!newPage.superview) { [self.pageContainer addSubview:newPage]; }
    [self.pageContainer addSubview:newPage positioned:NSWindowAbove relativeTo:oldPage];
    newPage.hidden = NO;
    newPage.alphaValue = 0;
    newPage.frame = NSOffsetRect(self.pageContainer.bounds, 0, -7);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.20;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        oldPage.animator.alphaValue = 0;
        newPage.animator.alphaValue = 1;
        newPage.animator.frame = self.pageContainer.bounds;
    } completionHandler:^{
        oldPage.hidden = YES;
        oldPage.alphaValue = 1.0;
        oldPage.frame = self.pageContainer.bounds;
        newPage.frame = self.pageContainer.bounds;
    }];
    [self positionSelectionAnimated:YES];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateSelectionAppearance];
}

- (void)updateSelectionAppearance {
    if (!self.selectionView.layer || !self.selectionBar.layer) { return; }
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.selectionView.layer.backgroundColor = [OVCColor(OVCColorTokenAccentSoft) CGColor];
        self.selectionView.layer.borderColor = [OVCColor(OVCColorTokenAccent) colorWithAlphaComponent:0.18].CGColor;
        self.selectionBar.layer.backgroundColor = [OVCColor(OVCColorTokenAccent) CGColor];
    }];
}

- (void)positionSelectionAnimated:(BOOL)animated {
    OVCNavItemView *selected = self.navItems[(NSUInteger)self.selectedSection];
    NSRect target = NSInsetRect(selected.frame, 4, 2);
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.18;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            self.selectionView.animator.frame = target;
        } completionHandler:nil];
    } else {
        self.selectionView.frame = target;
    }
    self.selectionBar.frame = NSMakeRect(4, 8, 3, target.size.height - 16);
}

#pragma mark 数据

- (void)reloadUI {
    NSString *text = self.statusText.length > 0 ? self.statusText : OVCStr(@"正在启动…");
    self.statusPill.text = text;
    if (!self.monitoringEnabled) { self.statusPill.tone = 0; }
    else if (self.statusError) { self.statusPill.tone = 2; }
    else { self.statusPill.tone = 1; }

    [self.permissionPage setFullDiskAccess:self.fdaGranted accessibility:self.axGranted];
    self.behaviorPage.monitoringEnabled = self.monitoringEnabled;
    [self.behaviorPage refresh];
    [self.appearancePage refresh];
    self.rulesPage.monitoringEnabled = self.monitoringEnabled;
    [self.rulesPage refresh];
    self.recordPage.items = self.items ?: @[];
    self.recordPage.monitoringEnabled = self.monitoringEnabled;
    [self.recordPage refresh];

    self.navItems[0].badgeView.hidden = self.fdaGranted && self.axGranted;
    if (!(self.fdaGranted && self.axGranted)) {
        self.navItems[0].badgeView.text = @"!";
        self.navItems[0].badgeView.tone = 2;
    }
    if (self.items.count > 0) {
        self.navItems[4].badgeView.hidden = NO;
        self.navItems[4].badgeView.text = self.items.count > 99 ? @"99+" : [NSString stringWithFormat:@"%lu", (unsigned long)self.items.count];
        self.navItems[4].badgeView.tone = 0;
    } else {
        self.navItems[4].badgeView.hidden = YES;
    }
    [self setNeedsDisplay:YES];
}

- (void)changeLanguage:(NSPopUpButton *)sender {
    [OVCPrefs shared].appLanguage = sender.indexOfSelectedItem;
}

- (void)pageOpenFullDiskAccess { if (self.owner.onRequestFullDiskAccess) { self.owner.onRequestFullDiskAccess(); } }
- (void)pageOpenAccessibility { if (self.owner.onRequestAccessibility) { self.owner.onRequestAccessibility(); } }
- (void)pageToggleMonitoring:(BOOL)enabled {
    self.monitoringEnabled = enabled;
    [OVCPrefs shared].monitoringEnabled = enabled;
    if (self.owner.onToggleMonitoring) { self.owner.onToggleMonitoring(enabled); }
    [self reloadUI];
}
- (void)pageToggleAutoCopy:(BOOL)enabled { [OVCPrefs shared].autoCopy = enabled; }
- (void)pageTogglePanel:(BOOL)enabled { [OVCPrefs shared].showPanel = enabled; }
- (void)pageToggleLaunchAtLogin:(BOOL)enabled {
    [OVCPrefs shared].launchAtLogin = enabled;
    if (self.owner.onToggleLaunchAtLogin) { self.owner.onToggleLaunchAtLogin(enabled); }
}
- (void)pageToggleDockIcon:(BOOL)enabled {
    [OVCPrefs shared].dockIcon = enabled;
    if (self.owner.onToggleDockIcon) { self.owner.onToggleDockIcon(enabled); }
    [self reloadUI];
}
- (void)pageChangeDuration:(double)duration { [OVCPrefs shared].panelDuration = duration; }
- (void)pageSetPanelTheme:(NSInteger)theme { [OVCPrefs shared].panelTheme = theme; }
- (void)pageSetPanelSize:(NSInteger)size { [OVCPrefs shared].panelSize = size; }
- (void)pageSetPanelTransparency:(double)value { [OVCPrefs shared].panelTransparency = value; }
- (void)pageChangeMinDigits:(NSInteger)minDigits maxDigits:(NSInteger)maxDigits {
    if (minDigits > maxDigits) {
        if (minDigits > maxDigits) { maxDigits = minDigits; }
    }
    OVCPrefs *prefs = [OVCPrefs shared];
    prefs.minDigits = minDigits;
    prefs.maxDigits = maxDigits;
    [self.rulesPage refresh];
}
- (void)pageToggleKeyword:(BOOL)enabled { [OVCPrefs shared].requiresKeyword = enabled; }
- (void)pageScan { if (self.owner.onScan) { self.owner.onScan(24); } }
- (void)pageClearHistory {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = OVCStr(@"清空最近记录？");
    alert.informativeText = OVCStr(@"只会删除一码保存的本地记录，不会影响短信本身。");
    [alert addButtonWithTitle:OVCStr(@"清空")];
    [alert addButtonWithTitle:OVCStr(@"取消")];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        if (self.owner.onClearHistory) { self.owner.onClearHistory(); }
    }
}
- (void)pageShowToast:(NSString *)text {
    self.toast.text = text;
    [self.toast setNeedsDisplay:YES];
    self.toast.hidden = NO;
    self.toast.alphaValue = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        self.toast.animator.alphaValue = 1;
    } completionHandler:nil];
    [self.toastTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.toastTimer = [NSTimer scheduledTimerWithTimeInterval:1.4 repeats:NO block:^(NSTimer *timer) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.18;
            weakSelf.toast.animator.alphaValue = 0;
        } completionHandler:^{ weakSelf.toast.hidden = YES; }];
    }];
}

@end

#pragma mark - 窗口

@interface OVCSettingsWindow () <NSWindowDelegate>
@property (nonatomic, strong, nullable) NSWindow *window;
- (void)presentSection:(NSInteger)section;
@property (nonatomic, strong, nullable) OVCSettingsView *content;
@end

@implementation OVCSettingsWindow
- (instancetype)init {
    self = [super init];
    if (self) {
        _historyItems = @[];
        _statusText = OVCStr(@"正在启动…");
        _monitoringEnabled = YES;
    }
    return self;
}
- (void)show {
    [self presentSection:NSNotFound];
}

- (void)showSection:(NSInteger)section {
    [self presentSection:section];
}

- (void)presentSection:(NSInteger)section {
    if (!self.window) {
        NSRect rect = NSMakeRect(0, 0, OVCWindowWidth, OVCWindowHeight);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
                                                       styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                                  NSWindowStyleMaskFullSizeContentView)
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        window.title = OVCStr(@"一码");
        window.titleVisibility = NSWindowTitleHidden;
        window.titlebarAppearsTransparent = YES;
        window.movableByWindowBackground = NO;
        window.releasedWhenClosed = NO;
        window.delegate = self;
        window.backgroundColor = OVCColor(OVCColorTokenSurface);
        [window setContentMinSize:rect.size];
        [window setContentMaxSize:rect.size];
        OVCSettingsView *view = [[OVCSettingsView alloc] initWithFrame:rect];
        view.owner = self;
        view.autoresizingMask = NSViewNotSizable;
        window.contentView = view;
        [window center];
        self.window = window;
        self.content = view;
    }
    [self syncContent];
    if (section != NSNotFound && section >= 0 && section < (NSInteger)self.content.pages.count) {
        [self.content selectSection:section animated:NO];
    }
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self.window orderFrontRegardless];
}
- (void)close { [self.window orderOut:nil]; }
- (void)reload { [self syncContent]; }

- (void)reloadLocalization {
    if (!self.window || !self.content) { return; }
    NSInteger section = self.content.selectedSection;
    NSRect rect = self.window.contentView.bounds;
    OVCSettingsView *view = [[OVCSettingsView alloc] initWithFrame:rect];
    view.owner = self;
    view.autoresizingMask = NSViewNotSizable;
    view.items = self.historyItems ?: @[];
    view.fdaGranted = self.fullDiskAccessGranted;
    view.axGranted = self.accessibilityGranted;
    view.monitoringEnabled = self.monitoringEnabled;
    view.statusText = self.statusText;
    view.statusError = !self.fullDiskAccessGranted;
    self.window.contentView = view;
    self.content = view;
    [self syncContent];
    [view selectSection:section animated:NO];
    [view layoutSubtreeIfNeeded];
    self.window.title = OVCStr(@"一码");
}
- (void)syncContent {
    OVCSettingsView *view = self.content;
    if (!view) { return; }
    view.items = self.historyItems ?: @[];
    view.fdaGranted = self.fullDiskAccessGranted;
    view.axGranted = self.accessibilityGranted;
    view.monitoringEnabled = self.monitoringEnabled;
    view.statusText = self.statusText;
    view.statusError = !self.fullDiskAccessGranted;
    [view reloadUI];
    [view setNeedsDisplay:YES];
}
- (NSView *)previewContentViewWithAppearance:(NSString *)appearanceName {
    return [self previewContentViewWithAppearance:appearanceName section:0];
}
- (NSView *)previewContentViewWithAppearance:(NSString *)appearanceName section:(NSInteger)section {
    OVCSettingsView *view = [[OVCSettingsView alloc] initWithFrame:NSMakeRect(0, 0, OVCWindowWidth, OVCWindowHeight)];
    view.items = self.historyItems ?: @[];
    view.fdaGranted = self.fullDiskAccessGranted;
    view.axGranted = self.accessibilityGranted;
    view.monitoringEnabled = self.monitoringEnabled;
    view.statusText = self.statusText;
    view.statusError = !self.fullDiskAccessGranted;
    view.appearance = [NSAppearance appearanceNamed:appearanceName];
    [view selectSection:section animated:NO];
    [view reloadUI];
    [view layoutSubtreeIfNeeded];
    return view;
}
@end

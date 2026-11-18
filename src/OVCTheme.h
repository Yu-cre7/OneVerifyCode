#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// 设计 Token 唯一来源。界面代码禁止出现颜色/字号字面量。
typedef NS_ENUM(NSInteger, OVCColorToken) {
    OVCColorTokenAccent,
    OVCColorTokenAccentPressed,
    OVCColorTokenAccentSoft,
    OVCColorTokenSurface,
    OVCColorTokenSurfaceAlt,
    OVCColorTokenStroke,
    OVCColorTokenTextPrimary,
    OVCColorTokenTextSecondary,
    OVCColorTokenTextTertiary,
    OVCColorTokenSuccess,
    OVCColorTokenWarning,
    OVCColorTokenDanger,
    OVCColorTokenOnAccent,
    OVCColorTokenShadow,
};

NSColor *OVCColor(OVCColorToken token);

/// 浮动面板的 7 套配色。所有颜色都由主题函数提供，界面代码不写死。
typedef NS_ENUM(NSInteger, OVCPanelTheme) {
    OVCPanelThemeAurora = 0,
    OVCPanelThemeTwilight,
    OVCPanelThemeMint,
    OVCPanelThemeAmber,
    OVCPanelThemeGraphite,
    OVCPanelThemePureWhite,
    OVCPanelThemePureBlack,
    OVCPanelThemeCount
};

/// 纯白 / 纯黑为固定的高对比底色，不参与背景透明度调节。
BOOL OVCPanelThemeUsesOpaqueBackground(OVCPanelTheme theme);

typedef NS_ENUM(NSInteger, OVCPanelSizePreset) {
    OVCPanelSizeCompact = 0,
    OVCPanelSizeStandard,
    OVCPanelSizeLarge,
    OVCPanelSizeCount
};

typedef NS_ENUM(NSInteger, OVCPanelThemeRole) {
    OVCPanelThemeRoleGradientStart,
    OVCPanelThemeRoleGradientEnd,
    OVCPanelThemeRoleAccent,
    OVCPanelThemeRoleTextPrimary,
    OVCPanelThemeRoleTextSecondary,
    OVCPanelThemeRoleHighlight
};

NSString *OVCPanelThemeName(OVCPanelTheme theme);
NSString *OVCPanelSizeName(OVCPanelSizePreset preset);
NSColor *OVCPanelThemeColor(OVCPanelTheme theme, OVCPanelThemeRole role);
NSSize OVCPanelSizeForPreset(OVCPanelSizePreset preset);
CGFloat OVCPanelCornerRadiusForPreset(OVCPanelSizePreset preset);
CGFloat OVCPanelCodeFontSizeForPreset(OVCPanelSizePreset preset);
CGFloat OVCPanelSourceFontSizeForPreset(OVCPanelSizePreset preset);

NSFont *OVCFontDisplay(void);    // 24 semibold
NSFont *OVCFontHeader(void);     // 20 semibold
NSFont *OVCFontSubhead(void);    // 14 semibold
NSFont *OVCFontCode(void);       // 30 semibold monospaced
NSFont *OVCFontTitle(void);      // 17 semibold
NSFont *OVCFontBody(void);       // 13 regular
NSFont *OVCFontBodyMedium(void); // 13 medium
NSFont *OVCFontCaption(void);    // 11 regular
NSFont *OVCFontCaptionMedium(void); // 11 medium
NSFont *OVCFontMono(void);       // 12 medium monospaced

FOUNDATION_EXPORT const CGFloat OVCSpaceXS;
FOUNDATION_EXPORT const CGFloat OVCSpaceS;
FOUNDATION_EXPORT const CGFloat OVCSpaceM;
FOUNDATION_EXPORT const CGFloat OVCSpaceL;
FOUNDATION_EXPORT const CGFloat OVCSpaceXL;

FOUNDATION_EXPORT const CGFloat OVCRadiusCard;
FOUNDATION_EXPORT const CGFloat OVCRadiusPanel;
FOUNDATION_EXPORT const CGFloat OVCRadiusButton;

FOUNDATION_EXPORT const NSTimeInterval OVCPanelInDuration;
FOUNDATION_EXPORT const NSTimeInterval OVCPanelOutDuration;

/// 面板/卡片通用绘制：连续圆角、1px 描边、可选阴影。
void OVCDrawCard(NSRect rect, CGFloat radius, BOOL elevated);

NS_ASSUME_NONNULL_END

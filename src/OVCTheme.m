#import "OVCTheme.h"
#import "OVCLocalization.h"

const CGFloat OVCSpaceXS = 4.0;
const CGFloat OVCSpaceS = 8.0;
const CGFloat OVCSpaceM = 12.0;
const CGFloat OVCSpaceL = 16.0;
const CGFloat OVCSpaceXL = 24.0;

const CGFloat OVCRadiusCard = 12.0;
const CGFloat OVCRadiusPanel = 16.0;
const CGFloat OVCRadiusButton = 8.0;

const NSTimeInterval OVCPanelInDuration = 0.12;
const NSTimeInterval OVCPanelOutDuration = 0.16;

static NSColor *OVCAdaptive(NSString *name, NSString *lightHex, NSString *darkHex) {
    NSColor *light = [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:1];
    NSColor *dark = light;
    unsigned int lv = 0, dv = 0;
    if (lightHex.length == 6) { sscanf(lightHex.UTF8String, "%06x", &lv); }
    if (darkHex.length == 6) { sscanf(darkHex.UTF8String, "%06x", &dv); }
    light = [NSColor colorWithSRGBRed:((lv >> 16) & 0xFF) / 255.0
                                 green:((lv >> 8) & 0xFF) / 255.0
                                  blue:(lv & 0xFF) / 255.0
                                 alpha:1.0];
    dark = [NSColor colorWithSRGBRed:((dv >> 16) & 0xFF) / 255.0
                                green:((dv >> 8) & 0xFF) / 255.0
                                 blue:(dv & 0xFF) / 255.0
                                alpha:1.0];
    return [NSColor colorWithName:name dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSAppearanceName best = [appearance bestMatchFromAppearancesWithNames:@[
            NSAppearanceNameAqua, NSAppearanceNameDarkAqua
        ]];
        return [best isEqualToString:NSAppearanceNameDarkAqua] ? dark : light;
    }];
}

NSColor *OVCColor(OVCColorToken token) {
    static NSMutableDictionary<NSNumber *, NSColor *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });

    NSColor *cached = cache[@(token)];
    if (cached) { return cached; }

    NSColor *color = nil;
    switch (token) {
        case OVCColorTokenAccent:
            color = OVCAdaptive(@"OVC.accent", @"3B5BDB", @"7C8FFF"); break;
        case OVCColorTokenAccentPressed:
            color = OVCAdaptive(@"OVC.accentPressed", @"2F49AF", @"6476E6"); break;
        case OVCColorTokenAccentSoft:
            color = OVCAdaptive(@"OVC.accentSoft", @"EAEEFF", @"232B4D"); break;
        case OVCColorTokenSurface:
            color = OVCAdaptive(@"OVC.surface", @"FFFFFF", @"1C1C1E"); break;
        case OVCColorTokenSurfaceAlt:
            color = OVCAdaptive(@"OVC.surfaceAlt", @"F5F6F8", @"2C2C2E"); break;
        case OVCColorTokenStroke:
            color = OVCAdaptive(@"OVC.stroke", @"E3E5EA", @"3A3A3C"); break;
        case OVCColorTokenTextPrimary:
            color = OVCAdaptive(@"OVC.textPrimary", @"16181D", @"F2F2F7"); break;
        case OVCColorTokenTextSecondary:
            color = OVCAdaptive(@"OVC.textSecondary", @"6B7280", @"9A9AA0"); break;
        case OVCColorTokenTextTertiary:
            color = OVCAdaptive(@"OVC.textTertiary", @"9CA3AF", @"6E6E73"); break;
        case OVCColorTokenSuccess:
            color = OVCAdaptive(@"OVC.success", @"1F9D55", @"4ADE80"); break;
        case OVCColorTokenWarning:
            color = OVCAdaptive(@"OVC.warning", @"B45309", @"FBBF24"); break;
        case OVCColorTokenDanger:
            color = OVCAdaptive(@"OVC.danger", @"C0392B", @"FF6B6B"); break;
        case OVCColorTokenOnAccent:
            color = OVCAdaptive(@"OVC.onAccent", @"FFFFFF", @"101018"); break;
        case OVCColorTokenShadow:
            color = [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:0.14]; break;
    }
    if (color == nil) { color = NSColor.labelColor; }
    cache[@(token)] = color;
    return color;
}


NSString *OVCPanelThemeName(OVCPanelTheme theme) {
    switch (theme) {
        case OVCPanelThemeAurora: return OVCStr(@"极光蓝");
        case OVCPanelThemeTwilight: return OVCStr(@"暮光紫");
        case OVCPanelThemeMint: return OVCStr(@"薄荷青");
        case OVCPanelThemeAmber: return OVCStr(@"暖琥珀");
        case OVCPanelThemeGraphite: return OVCStr(@"石墨灰");
        case OVCPanelThemePureWhite: return OVCStr(@"纯白");
        case OVCPanelThemePureBlack: return OVCStr(@"纯黑");
        default: return OVCStr(@"极光蓝");
    }
}

NSString *OVCPanelSizeName(OVCPanelSizePreset preset) {
    switch (preset) {
        case OVCPanelSizeCompact: return OVCStr(@"紧凑");
        case OVCPanelSizeLarge: return OVCStr(@"宽适");
        default: return OVCStr(@"标准");
    }
}

NSSize OVCPanelSizeForPreset(OVCPanelSizePreset preset) {
    switch (preset) {
        case OVCPanelSizeCompact: return NSMakeSize(224, 74);
        case OVCPanelSizeLarge: return NSMakeSize(276, 90);
        default: return NSMakeSize(244, 80);
    }
}

CGFloat OVCPanelCornerRadiusForPreset(OVCPanelSizePreset preset) {
    switch (preset) {
        case OVCPanelSizeCompact: return 14;
        case OVCPanelSizeLarge: return 18;
        default: return 16;
    }
}

CGFloat OVCPanelCodeFontSizeForPreset(OVCPanelSizePreset preset) {
    switch (preset) {
        case OVCPanelSizeCompact: return 27;
        case OVCPanelSizeLarge: return 34;
        default: return 30;
    }
}

CGFloat OVCPanelSourceFontSizeForPreset(OVCPanelSizePreset preset) {
    switch (preset) {
        case OVCPanelSizeCompact: return 10;
        case OVCPanelSizeLarge: return 12;
        default: return 11;
    }
}

BOOL OVCPanelThemeUsesOpaqueBackground(OVCPanelTheme theme) {
    return theme == OVCPanelThemePureWhite || theme == OVCPanelThemePureBlack;
}

NSColor *OVCPanelThemeColor(OVCPanelTheme theme, OVCPanelThemeRole role) {
    static NSMutableDictionary<NSNumber *, NSColor *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    NSNumber *key = @(theme * 10 + role);
    NSColor *cached = cache[key];
    if (cached) { return cached; }

    NSString *light = @"EEF3FF", *dark = @"202844";
    switch (theme) {
        case OVCPanelThemeTwilight:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"F5EDFF"; dark = @"2A203D"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"FFF2FA"; dark = @"38222F"; break;
                case OVCPanelThemeRoleAccent:        light = @"7C3AED"; dark = @"C4A2FF"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"1E142C"; dark = @"F8F2FF"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"6F5B85"; dark = @"BBA9D6"; break;
                default:                             light = @"FFFFFF"; dark = @"FFFFFF"; break;
            }
            break;
        case OVCPanelThemeMint:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"E8FAF5"; dark = @"132E2C"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"F0FBFF"; dark = @"142A33"; break;
                case OVCPanelThemeRoleAccent:        light = @"0E9384"; dark = @"63E6CD"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"102A29"; dark = @"EFFFFB"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"4F706C"; dark = @"A5D6CF"; break;
                default:                             light = @"FFFFFF"; dark = @"FFFFFF"; break;
            }
            break;
        case OVCPanelThemeAmber:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"FFF3E2"; dark = @"33261A"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"FFF9EF"; dark = @"2C231C"; break;
                case OVCPanelThemeRoleAccent:        light = @"B45309"; dark = @"F5C26B"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"2E1D0B"; dark = @"FFF8EC"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"7A5B3A"; dark = @"D8BE99"; break;
                default:                             light = @"FFFFFF"; dark = @"FFFFFF"; break;
            }
            break;
        case OVCPanelThemeGraphite:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"F4F5F7"; dark = @"25272D"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"E8EAEE"; dark = @"17191E"; break;
                case OVCPanelThemeRoleAccent:        light = @"4B5563"; dark = @"C3CAD6"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"181A1F"; dark = @"F5F6FA"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"606774"; dark = @"AAB0BB"; break;
                default:                             light = @"FFFFFF"; dark = @"FFFFFF"; break;
            }
            break;
        case OVCPanelThemePureWhite:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"FFFFFF"; dark = @"FFFFFF"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"FFFFFF"; dark = @"FFFFFF"; break;
                case OVCPanelThemeRoleAccent:        light = @"111318"; dark = @"111318"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"111318"; dark = @"111318"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"5F6368"; dark = @"5F6368"; break;
                default:                             light = @"E5E7EB"; dark = @"E5E7EB"; break;
            }
            break;
        case OVCPanelThemePureBlack:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"000000"; dark = @"000000"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"000000"; dark = @"000000"; break;
                case OVCPanelThemeRoleAccent:        light = @"FFFFFF"; dark = @"FFFFFF"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"FFFFFF"; dark = @"FFFFFF"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"A1A1A6"; dark = @"A1A1A6"; break;
                default:                             light = @"3A3A3C"; dark = @"3A3A3C"; break;
            }
            break;
        default:
            switch (role) {
                case OVCPanelThemeRoleGradientStart: light = @"EEF3FF"; dark = @"202844"; break;
                case OVCPanelThemeRoleGradientEnd:   light = @"F8F5FF"; dark = @"2A2038"; break;
                case OVCPanelThemeRoleAccent:        light = @"3B5BDB"; dark = @"8FA4FF"; break;
                case OVCPanelThemeRoleTextPrimary:   light = @"11142B"; dark = @"F4F6FF"; break;
                case OVCPanelThemeRoleTextSecondary: light = @"5E647A"; dark = @"A9B1CC"; break;
                default:                             light = @"FFFFFF"; dark = @"FFFFFF"; break;
            }
            break;
    }
    NSString *name = [NSString stringWithFormat:@"OVC.panel.%ld.%ld", (long)theme, (long)role];
    NSColor *color = OVCAdaptive(name, light, dark);
    cache[key] = color;
    return color;
}

NSFont *OVCFontDisplay(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
    });
    return font;
}

NSFont *OVCFontSubhead(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    });
    return font;
}

NSFont *OVCFontHeader(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    });
    return font;
}

NSFont *OVCFontCode(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont fontWithName:@"SFMono-Semibold" size:30];
        if (!font) { font = [NSFont monospacedSystemFontOfSize:30 weight:NSFontWeightSemibold]; }
    });
    return font;
}

NSFont *OVCFontTitle(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    });
    return font;
}

NSFont *OVCFontBody(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    });
    return font;
}

NSFont *OVCFontBodyMedium(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    });
    return font;
}

NSFont *OVCFontCaption(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    });
    return font;
}

NSFont *OVCFontCaptionMedium(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    });
    return font;
}

NSFont *OVCFontMono(void) {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        font = [NSFont fontWithName:@"SFMono-Medium" size:12];
        if (!font) { font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium]; }
    });
    return font;
}

void OVCDrawCard(NSRect rect, CGFloat radius, BOOL elevated) {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
    if (elevated) {
        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowColor = OVCColor(OVCColorTokenShadow);
        shadow.shadowBlurRadius = 24.0;
        shadow.shadowOffset = NSMakeSize(0, -6);
        [shadow set];
    }
    [OVCColor(OVCColorTokenSurface) setFill];
    [path fill];

    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    [[NSColor colorWithWhite:1.0 alpha:0.02] setFill];
    NSRectFillUsingOperation(NSMakeRect(rect.origin.x, NSMaxY(rect) - 1, rect.size.width, 1), NSCompositingOperationSourceOver);
    [NSGraphicsContext restoreGraphicsState];

    [OVCColor(OVCColorTokenStroke) setStroke];
    path.lineWidth = 1.0;
    [path stroke];
}

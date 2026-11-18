#import "OVCIconFactory.h"
#import "OVCTheme.h"

@implementation OVCIconFactory

static void OVCDrawCheckGlyph(NSRect rect, CGFloat lineWidth, NSColor *color) {
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    NSPoint p1 = NSMakePoint(rect.origin.x + w * 0.18, rect.origin.y + h * 0.52);
    NSPoint p2 = NSMakePoint(rect.origin.x + w * 0.41, rect.origin.y + h * 0.28);
    NSPoint p3 = NSMakePoint(rect.origin.x + w * 0.84, rect.origin.y + h * 0.74);

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:p1];
    [path lineToPoint:p2];
    [path lineToPoint:p3];
    path.lineWidth = lineWidth;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [color setStroke];
    [path stroke];
}

/// 品牌字形：数字 1。竖笔 + 左上旗 + 底横，18px 下仍能读成“1”。
static void OVCDrawNumeral(NSRect rect, CGFloat lineWidth, NSColor *color) {
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(x + w * 0.50, y + h * 0.15)];
    [path lineToPoint:NSMakePoint(x + w * 0.50, y + h * 0.84)];
    [path lineToPoint:NSMakePoint(x + w * 0.31, y + h * 0.69)];
    [path moveToPoint:NSMakePoint(x + w * 0.36, y + h * 0.15)];
    [path lineToPoint:NSMakePoint(x + w * 0.68, y + h * 0.15)];
    path.lineWidth = lineWidth;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [color setStroke];
    [path stroke];
}

+ (void)drawStatusGlyphInRect:(NSRect)rect color:(NSColor *)color lineWidth:(CGFloat)lineWidth {
    // 圆角方框 + 数字 1：比裸数字更有识别度，18px 下仍保持清晰。
    CGFloat inset = lineWidth * 0.5 + 0.2;
    NSRect frame = NSInsetRect(rect, inset, inset);
    NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:frame
                                                       xRadius:frame.size.width * 0.24
                                                       yRadius:frame.size.width * 0.24];
    box.lineWidth = lineWidth;
    [color setStroke];
    [box stroke];

    NSRect glyph = NSInsetRect(frame, frame.size.width * 0.22, frame.size.height * 0.16);
    OVCDrawNumeral(glyph, lineWidth * 0.90, color);
}

+ (NSImage *)statusBarImage {
    const CGFloat points = 18.0;
    const CGFloat scale = 2.0;
    NSInteger pixels = (NSInteger)(points * scale);

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:pixels
                                                                   pixelsHigh:pixels
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:0
                                                                 bitsPerPixel:0];
    rep.size = NSMakeSize(points, points);

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext setCurrentContext:context];
    context.shouldAntialias = YES;

    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0, 0, points, points));
    [self drawStatusGlyphInRect:NSMakeRect(0.5, 0.5, points - 1.0, points - 1.0)
                          color:[NSColor blackColor]
                      lineWidth:1.45];

    [NSGraphicsContext restoreGraphicsState];

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(points, points)];
    [image addRepresentation:rep];
    image.template = YES;
    return image;
}

+ (NSImage *)appIconImageWithSize:(CGFloat)size {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [image lockFocus];
    [self drawAppIconInRect:NSMakeRect(0, 0, size, size)];
    [image unlockFocus];
    return image;
}

+ (void)drawAppIconInRect:(NSRect)rect {
    CGFloat size = rect.size.width;
    CGFloat radius = size * 0.2237;
    NSRect body = NSInsetRect(rect, size * 0.03, size * 0.03);
    NSBezierPath *squircle = [NSBezierPath bezierPathWithRoundedRect:body xRadius:radius yRadius:radius];

    // 石墨底色，比原来的蓝紫渐变更克制。
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.055 green:0.071 blue:0.094 alpha:1.0]
                                                        endingColor:[NSColor colorWithSRGBRed:0.135 green:0.173 blue:0.212 alpha:1.0]];
    [gradient drawInBezierPath:squircle angle:-90.0];

    [NSGraphicsContext saveGraphicsState];
    [squircle addClip];

    // 左上柔光
    NSGradient *glow = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.16]
                                                      endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
    [glow drawInRect:NSMakeRect(body.origin.x, NSMidY(body), body.size.width, body.size.height * 0.6) angle:-90.0];

    // 主字形：暖白“1”
    NSColor *ivory = [NSColor colorWithSRGBRed:0.960 green:0.941 blue:0.890 alpha:1.0];
    OVCDrawNumeral(NSInsetRect(body, size * 0.20, size * 0.17), size * 0.105, ivory);

    // 右下角薄荷色认证徽章
    CGFloat badgeSize = size * 0.225;
    NSRect badge = NSMakeRect(NSMaxX(body) - badgeSize - size * 0.115,
                              body.origin.y + size * 0.115,
                              badgeSize, badgeSize);
    NSBezierPath *badgePath = [NSBezierPath bezierPathWithOvalInRect:badge];
    [[NSColor colorWithSRGBRed:0.290 green:0.878 blue:0.741 alpha:1.0] setFill];
    [badgePath fill];

    OVCDrawCheckGlyph(NSInsetRect(badge, badgeSize * 0.27, badgeSize * 0.27),
                      size * 0.026,
                      [NSColor colorWithSRGBRed:0.055 green:0.071 blue:0.094 alpha:1.0]);

    // 内描边
    NSBezierPath *inner = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(body, size * 0.012, size * 0.012)
                                                         xRadius:radius * 0.95
                                                         yRadius:radius * 0.95];
    inner.lineWidth = MAX(1.0, size * 0.004);
    [[NSColor colorWithWhite:1.0 alpha:0.14] setStroke];
    [inner stroke];
    [NSGraphicsContext restoreGraphicsState];
}

+ (BOOL)writeAppIconPNGToURL:(NSURL *)url pixelSize:(NSInteger)pixelSize error:(NSError **)error {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:pixelSize
                                                                   pixelsHigh:pixelSize
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:0
                                                                 bitsPerPixel:0];
    rep.size = NSMakeSize(pixelSize, pixelSize);

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext setCurrentContext:context];
    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0, 0, pixelSize, pixelSize));
    [self drawAppIconInRect:NSMakeRect(0, 0, pixelSize, pixelSize)];
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (!png) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.oneverifycode.icon" code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法编码 PNG"}];
        }
        return NO;
    }
    return [png writeToURL:url options:NSDataWritingAtomic error:error];
}

+ (BOOL)writeStatusBarPNGToURL:(NSURL *)url scale:(CGFloat)scale error:(NSError **)error {
    NSInteger pixels = (NSInteger)(18.0 * scale);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:pixels
                                                                   pixelsHigh:pixels
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:0
                                                                 bitsPerPixel:0];
    rep.size = NSMakeSize(pixels, pixels);

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext setCurrentContext:context];
    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0, 0, pixels, pixels));
    [self drawStatusGlyphInRect:NSMakeRect(1.0, 1.0, pixels - 2.0, pixels - 2.0)
                          color:[NSColor blackColor]
                      lineWidth:1.55 * scale];
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return png ? [png writeToURL:url options:NSDataWritingAtomic error:error] : NO;
}

@end

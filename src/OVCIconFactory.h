#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface OVCIconFactory : NSObject

/// 18×18 菜单栏模板图标（随系统明暗自动反色）。
+ (NSImage *)statusBarImage;

/// 设置窗口标题处使用的小图标。
+ (NSImage *)appIconImageWithSize:(CGFloat)size;

/// 生成指定像素尺寸的 App 图标并写入 PNG，用于制造 .icns。
+ (BOOL)writeAppIconPNGToURL:(NSURL *)url pixelSize:(NSInteger)pixelSize error:(NSError **)error;

/// 生成菜单栏图标预览（黑色透明底 PNG）。
+ (BOOL)writeStatusBarPNGToURL:(NSURL *)url scale:(CGFloat)scale error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

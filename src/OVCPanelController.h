#import <Cocoa/Cocoa.h>
#import "OVCTheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface OVCPanelController : NSObject

/// 在焦点输入框附近展示验证码卡片。duration 为自动消失秒数。
- (void)presentCode:(NSString *)code
             sender:(nullable NSString *)sender
           duration:(NSTimeInterval)duration;

- (void)dismiss;

/// 供离屏渲染/截图使用，不影响真实窗口。
- (NSView *)previewViewWithCode:(NSString *)code
                         sender:(nullable NSString *)sender
                        seconds:(NSInteger)seconds;

- (NSView *)previewViewWithCode:(NSString *)code
                         sender:(nullable NSString *)sender
                        seconds:(NSInteger)seconds
                          theme:(OVCPanelTheme)theme
                           size:(OVCPanelSizePreset)size
                   transparency:(double)transparency;

@end

NS_ASSUME_NONNULL_END

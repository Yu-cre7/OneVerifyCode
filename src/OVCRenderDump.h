#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 离屏渲染设置页、悬浮卡片与图标，供无录屏权限时做视觉走查。
/// 返回 0 表示成功。
int OVCRenderPreviews(NSString *directory);

NS_ASSUME_NONNULL_END

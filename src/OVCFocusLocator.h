#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface OVCFocusLocator : NSObject

+ (BOOL)accessibilityTrusted;
+ (void)promptAccessibilityIfNeeded;

/// 焦点输入框在 Cocoa 屏幕坐标中的矩形；无法定位时返回 NSZeroRect。
+ (CGRect)focusedElementRect;

/// 仅当焦点是可编辑文本输入时返回其矩形，否则 NSZeroRect。
+ (CGRect)focusedTextInputRect;

/// 当前焦点是否是可编辑的普通文本输入（排除密码框）。
+ (BOOL)focusedElementIsTextInput;

/// 模拟 ⌘V。返回 NO 表示缺少辅助功能权限或事件创建失败。
+ (BOOL)sendPasteShortcut;

+ (void)openAccessibilitySettings;
+ (void)openFullDiskAccessSettings;

@end

NS_ASSUME_NONNULL_END

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class OVCHistoryItem;

@interface OVCSettingsWindow : NSObject

@property (nonatomic, copy) NSArray<OVCHistoryItem *> *historyItems;
@property (nonatomic, assign) BOOL fullDiskAccessGranted;
@property (nonatomic, assign) BOOL accessibilityGranted;
@property (nonatomic, assign) BOOL monitoringEnabled;
@property (nonatomic, copy) NSString *statusText;

@property (nonatomic, copy, nullable) void (^onRequestFullDiskAccess)(void);
@property (nonatomic, copy, nullable) void (^onRequestAccessibility)(void);
@property (nonatomic, copy, nullable) void (^onScan)(NSInteger hours);
@property (nonatomic, copy, nullable) void (^onClearHistory)(void);
@property (nonatomic, copy, nullable) void (^onQuit)(void);
@property (nonatomic, copy, nullable) void (^onToggleLaunchAtLogin)(BOOL enabled);
@property (nonatomic, copy, nullable) void (^onToggleMonitoring)(BOOL enabled);
@property (nonatomic, copy, nullable) void (^onToggleDockIcon)(BOOL enabled);

- (void)show;
- (void)showSection:(NSInteger)section;
- (void)close;
- (void)reload;
- (void)reloadLocalization;

/// 离屏渲染整页，用于视觉走查。
- (NSView *)previewContentViewWithAppearance:(NSString *)appearanceName;
- (NSView *)previewContentViewWithAppearance:(NSString *)appearanceName section:(NSInteger)section;

@end

NS_ASSUME_NONNULL_END

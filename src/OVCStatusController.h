#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class OVCStatusController;
@class OVCHistoryItem;

@protocol OVCStatusControllerDelegate <NSObject>
- (void)statusControllerDidRequestSettings:(OVCStatusController *)controller;
- (void)statusController:(OVCStatusController *)controller didRequestSettingsSection:(NSInteger)section;
- (void)statusControllerDidRequestAbout:(OVCStatusController *)controller;
- (void)statusControllerDidRequestQuit:(OVCStatusController *)controller;
- (void)statusControllerDidRequestScan:(OVCStatusController *)controller;
- (void)statusController:(OVCStatusController *)controller didSelectRecentCode:(NSString *)code;
- (void)statusControllerDidRequestFullDiskAccess:(OVCStatusController *)controller;
- (void)statusControllerDidRequestAccessibility:(OVCStatusController *)controller;
- (void)statusController:(OVCStatusController *)controller didToggleLaunchAtLogin:(BOOL)enabled;
- (void)statusController:(OVCStatusController *)controller didToggleDockIcon:(BOOL)enabled;
- (void)statusController:(OVCStatusController *)controller didToggleMonitoring:(BOOL)enabled;
@end

@interface OVCStatusController : NSObject

@property (nonatomic, weak, nullable) id<OVCStatusControllerDelegate> delegate;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, assign) BOOL monitoringEnabled;
@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, copy) NSArray<OVCHistoryItem *> *recentItems;
@property (nonatomic, assign) BOOL fullDiskAccessGranted;
@property (nonatomic, assign) BOOL accessibilityGranted;

- (void)install;
- (void)remove;
- (void)refresh;

/// 状态项是否真正落在屏幕内（菜单栏过满时会被系统排到屏幕外）。
- (BOOL)isStatusItemVisible;
- (NSRect)statusItemFrame;

/// 仅用于截图预览：在屏幕坐标弹出真实菜单。
- (void)showPreviewMenuAtPoint:(NSPoint)point;

@end

NS_ASSUME_NONNULL_END

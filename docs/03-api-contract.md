# 一码 OneVerifyCode · 接口与权限契约

本软件为单机菜单栏应用，无服务端。此文档定义**进程内模块契约**、**系统接口契约**与**错误码**，保证模块之间、以及未来版本升级时行为一致。

## 1. 模块调用契约

### 1.1 OVCCodeExtractor（纯函数，无副作用）

```objc
// 返回 nil 表示没有可用验证码
+ (nullable OVCCode *)extractFromText:(NSString *)text
                              options:(OVCExtractOptions)options;
```

`OVCExtractOptions`：

| 字段 | 默认 | 含义 |
| --- | --- | --- |
| `minDigits` | 4 | 最短位数 |
| `maxDigits` | 8 | 最长位数 |
| `requiresKeyword` | YES | 是否必须命中验证码关键词 |
| `allowSpacedDigits` | YES | 是否合并“123 456”这类空格分隔 |

`OVCCode`：

```objc
@interface OVCCode : NSObject
@property (copy) NSString *code;       // 纯数字或字母数字组合
@property (copy) NSString *keyword;    // 命中的关键词（用于解释为何识别）
@property (assign) NSRange range;      // 在原文中的位置
@end
```

**约定**：纯函数、线程安全、不读偏好；所有阈值由 options 传入，便于单测。

### 1.2 OVCMessageStore

```objc
- (BOOL)openWithError:(NSError **)error;      // 只读打开 chat.db
- (int64_t)currentMaxRowID;
- (NSArray<OVCMessage *> *)fetchAfterRowID:(int64_t)rowid limit:(NSInteger)limit;
```

`OVCMessage`：`rowid / guid / text / sender / service / date / isFromMe`。

约定：

- 连接以 `SQLITE_OPEN_READONLY` 打开，绝不执行写操作。
- 查询失败不抛异常，返回空数组并记录 `lastError`。
- 数据库可能被系统以 WAL 模式占用，只读打开需允许 `-shm/-wal` 读取。

### 1.3 OVCMonitor

```objc
@property (copy) void (^onCode)(OVCCode *code, OVCMessage *message);
- (void)start; - (void)stop;
- (void)scanLastHours:(NSInteger)hours;   // 手动补扫，不触发弹窗，仅入历史
```

约定：同一 guid 仅回调一次；同一 code 90 秒内不重复回调；所有回调在主线程。

### 1.4 OVCPanelController

```objc
- (void)presentCode:(NSString *)code
             sender:(NSString *)sender
           duration:(NSTimeInterval)duration;
- (void)dismiss;
```

约定：展示前记录当前前台 App；点击“粘贴”时先激活该 App 再发 ⌘V；面板不得成为 key window。

## 2. 系统接口契约

| 接口 | 用途 | 前置条件 | 失败降级 |
| --- | --- | --- | --- |
| `sqlite3_open_v2(..., READONLY)` on `~/Library/Messages/chat.db` | 读短信 | 完全磁盘访问 | 菜单显示“需要授权”，设置页红点 |
| `AXIsProcessTrusted()` | 检测辅助功能 | 无 | 弹窗定位退化为鼠标位置 |
| `AXUIElementCopyAttributeValue(kAXFocusedUIElement)` | 取焦点控件 | 辅助功能 | 同上 |
| `AXValueGetValue(kAXPosition/kAXSize)` | 换算控件矩形 | 同上 | 同上 |
| `CGEventCreateKeyboardEvent` + `CGEventPost` | 模拟 ⌘V | 辅助功能 | 仅复制到剪贴板，并提示“已复制，请手动粘贴” |
| `NSPasteboardGeneral` | 写剪贴板 | 无 | 记录错误 |
| `SMAppService.mainAppService` | 注册开机登录项 | 应用已签名；必要时用户在“登录项”批准 | 开关回弹并提示原因 |
| `OVCStr` / `OVCResolvedLanguageCode` | 运行时界面文案 | 读取 `appLanguage` 或系统首选语言 | 英文资源缺失时回退中文源文案 |

## 3. 错误码

与 AGENTS.md 约定一致，客户端按段分支：

| 码 | 段 | 含义 | 用户可见文案 |
| --- | --- | --- | --- |
| 1001 | 1xxx 参数 | 关键词/位数配置非法 | 设置已恢复默认值 |
| 1002 | 1xxx 参数 | 扫描小时数越界 | 仅支持 1–72 小时 |
| 2001 | 2xxx 鉴权 | 无完全磁盘访问 | 需要“完全磁盘访问”才能读取短信 |
| 2002 | 2xxx 鉴权 | 无辅助功能 | 需要“辅助功能”才能自动粘贴 |
| 3001 | 3xxx 业务 | 未识别到验证码 | （静默，不打扰） |
| 3002 | 3xxx 业务 | 验证码已过期（>10 分钟） | 该验证码可能已过期 |
| 4001 | 4xxx 资源 | chat.db 不存在 | 未找到短信数据库，请确认已在 iPhone 开启短信转发 |
| 4002 | 4xxx 资源 | chat.db 被占用/损坏 | 短信数据库暂时不可读，稍后重试 |
| 5001 | 5xxx 系统 | 剪贴板写入失败 | 复制失败，请重试 |
| 5002 | 5xxx 系统 | 登录项注册失败 | 开机启动设置失败，请检查权限或系统“登录项”设置 |
| 5003 | 5xxx 系统 | 未知异常 | 出现异常，已记录日志 |

## 4. 持久化契约

`NSUserDefaults`（bundle id `com.oneverifycode.app`）：

| Key | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `monitoringEnabled` | BOOL | YES | 监听总开关；关闭后停止轮询并置灰设置 |
| `autoCopy` | BOOL | YES | 识别后自动复制 |
| `showPanel` | BOOL | YES | 显示悬浮卡片 |
| `panelDuration` | double | 8.0 | 停留秒数，1–20 |
| `panelTheme` | int | 0 | 悬浮卡片主题，0–6 |
| `panelSize` | int | 1 | 0 紧凑 / 1 标准 / 2 宽适 |
| `panelTransparency` | double | 0.12 | 背景透明度，0–1.0（界面显示 0–100%） |
| `minDigits` | int | 4 | 最短位数 |
| `maxDigits` | int | 8 | 最长位数 |
| `requiresKeyword` | BOOL | YES | 是否必须含关键词 |
| `launchAtLogin` | BOOL | NO | 开机自启 |
| `dockIcon` | BOOL | NO | 显示 Dock 图标；状态项不可见时自动置 YES |
| `hasCompletedOnboarding` | BOOL | NO | 是否看过首次引导 |
| `appLanguage` | int | 0 | 0 跟随系统 / 1 中文 / 2 English |

语言切换只改变界面文案，不影响历史数据；`appLanguage` 变更后由 AppDelegate 重建设置页并刷新菜单。

历史文件：`~/Library/Application Support/OneVerifyCode/history.json`

```json
{
  "version": 1,
  "items": [
    {"code": "123456", "sender": "1069****01", "date": 1763370000.0, "guid": "..."}
  ]
}
```

约束：最多 50 条；不保存短信正文；读取失败时重建空文件并记录日志。

## 5. 版本兼容

- 历史文件 `version` 升级时只做向后兼容读取；未知字段忽略。
- 偏好键只增不改语义；删除键需提供迁移。
- 最低系统版本 macOS 13.0（使用 `NSSwitch`、`canJoinAllSpaces` 等 API）。

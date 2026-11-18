# 一码 OneVerifyCode · 技术方案

版本：0.5.3（测试版）  
目标平台：macOS 13 Ventura 及以上，Intel x86_64 与 Apple Silicon arm64 通用二进制

## 1. 需求边界

### 1.1 要做（v0.5.3）

| 编号 | 需求 | 验收方式 |
| --- | --- | --- |
| R1 | 常驻菜单栏；菜单栏放不下时自动显示 Dock 图标 | 状态项可见时仅菜单栏；被系统排到屏幕外时自动切到 Dock + 菜单栏 |
| R2 | 自动监听 iPhone 转发到 Mac 的短信/iMessage | 新短信 3 秒内被识别 |
| R3 | 从短信正文中提取验证码（4–8 位数字，含“123 456”断行、全角数字） | 单元测试覆盖 30+ 条真实文案 |
| R4 | 识别后自动写入剪贴板 | 剪贴板内容等于验证码 |
| R5 | 紧凑悬浮卡片，点击数字即填入 | AX 定位焦点输入框，卡片出现在其下方/上方；无焦点时跟随鼠标 |
| R6 | 菜单栏保留高频开关 | 状态、监听、自动复制、输入框旁提示、开机启动、Dock 图标、最近验证码、设置、退出 |
| R7 | 主设置窗口（六页） | 权限、行为、外观、识别规则、记录、关于；设置项统一收口 |
| R8 | 开机自启 | 通过 SMAppService 注册主 App 登录项，系统设置“登录项”可见；可注册/注销 |
| R9 | 权限引导 | 完全磁盘访问、辅助功能缺失时有明确说明与跳转按钮 |
| R10 | 打包 pkg + dmg | `dist/OneVerifyCode-0.5.3.pkg` 安装到 /Applications；dmg 提供拖拽安装 |
| R11 | 监听总开关 | 关闭后停止轮询、状态点变灰、设置页相关项置灰不可点 |
| R12 | 点击数字自动填入 | 仅点击验证码数字触发复制 + ⌘V；无粘贴/复制按钮 |
| R13 | 进度条自动关闭 | 底部进度条随停留时间缩短，结束后卡片淡出；无关闭按钮与倒计时文字 |
| R14 | 移除自动填充/阅后即焚 | 无对应偏好、开关与代码路径 |
| R15 | 全局中英文切换 | 设置侧栏切换 System/中文/English，菜单、设置、弹窗、提示同步更新；`make l10n-check` 通过 |
| R16 | 权限页操作按钮收敛 | CTA 改为 28pt 高、按文案取宽的小型圆角按钮；已授权时改用状态行，不再显示拉满卡片的禁用按钮 |
| R17 | 设置窗口只在左侧拖动 | `movableByWindowBackground=NO`；左侧空白与品牌头部使用拖拽层，右侧内容区不再误拖动窗口 |
| R18 | 关于页 GitHub 入口与 DMG 说明 | 关于页显示 GitHub mark 与仓库地址，一键打开；DMG 内附双语拖拽安装说明 |

### 1.2 不做（v0.5.3 明确排除）

- 不拦截、不修改、不发送短信；只读本机 `chat.db`。
- 不云同步、不联网、无账号体系、无统计上报。
- 不接管系统自带“验证码自动填充”（两者可共存）。
- 不做 App Store 沙盒版本（沙盒无法读 `~/Library/Messages`）。
- 不做 iOS 端。
- 不做“识别后自动粘贴”和“阅后即焚”；验证码只在用户点击数字时填入。

### 1.3 关键约束

1. **短信来源**：Mac 本身不收短信，必须由 iPhone 开启“短信转发”（设置 → 信息 → 短信转发）到本机，消息才会写入 `~/Library/Messages/chat.db`。产品内必须说明这一点，否则用户会误判为软件失效。
2. **完全磁盘访问**：读取 `chat.db` 需要用户在“系统设置 → 隐私与安全性 → 完全磁盘访问”中授权，无法用代码申请。
3. **辅助功能**：定位输入框（AX API）与模拟 ⌘V 都需要“辅助功能”授权。
4. **签名**：无 Apple 开发者证书，测试版使用 ad-hoc 签名；每次重新签名后 TCC 授权会失效，需要重新勾选。这是测试版已知限制，正式分发需 Developer ID。

## 2. 技术选型

| 维度 | 选择 | 理由 |
| --- | --- | --- |
| 语言 | Objective-C（ARC） | 本机只有 Command Line Tools，缺少 Xcode；Swift 6.1.2 在该 CLT 下存在 `SwiftBridging` 模块重复定义缺陷（`/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap` 与 `bridging.modulemap` 冲突，修复需 root），Swift/AppKit 无法编译。ObjC + clang 2 秒可完成编译，AppKit 能力完全一致。 |
| UI | AppKit（纯代码，无 xib/storyboard） | 无 Xcode 环境无法编辑 Interface Builder；代码构建可复现、可 review。 |
| 常驻形态 | `NSStatusItem` + `LSUIElement=1` | 系统标准做法，菜单栏点击即用，无 Dock 干扰。 |
| 悬浮提示 | 无边框 `NSPanel`（`nonactivatingPanel`） | 不抢焦点，可浮于全屏 App 之上（`canJoinAllSpaces`）。 |
| 短信读取 | SQLite3 只读打开 `chat.db` | 官方无公开 API；只读 + 轮询是当前唯一可行且不越权的方式。 |
| 正文解析 | `text` 列优先，`attributedBody` 兜底 | macOS 13+ 大量消息正文只存在于 `attributedBody`（本机 2915 条），必须兜底。 |
| 设置存储 | `NSUserDefaults` + Application Support 下 JSON 历史 | 轻量、可读、易排障。 |
| 构建 | Makefile + clang + lipo + codesign + pkgbuild | 全程命令行，无 Xcode 依赖。 |

### 2.1 为什么不用 Swift / SwiftUI

实测（2026-11-17）：

```
$ swiftc -Onone a.swift -o a        # import AppKit
error: redefinition of module 'SwiftBridging'
note: previously defined here  .../swift/bridging.modulemap
```

`/usr/include/swift` 下同时存在 2023 年的 `module.modulemap` 与 2024 年的 `bridging.modulemap`，二者都声明 `SwiftBridging`。删除其一需要 root，且会破坏系统工具链完整性。ObjC 不经过 Swift 模块导入，完全规避该问题。

## 3. 模块划分

```
src/
├── main.m                 进程入口，LSUIElement 启动
├── OVCAppDelegate         生命周期、权限编排、组装各控制器
├── OVCTheme               设计 Token 唯一来源（颜色/字号/间距/圆角/时长）
├── OVCIconFactory         菜单栏模板图标 + App 图标（代码绘制）
├── OVCPrefs               偏好读写（NSUserDefaults）
├── OVCHistoryStore        历史记录 JSON 持久化
├── OVCCodeExtractor       纯函数：短信正文 → 验证码（可单测）
├── OVCMessageStore        chat.db 只读查询 + attributedBody 解码
├── OVCMonitor             轮询、去重、触发剪贴板/弹窗
├── OVCFocusLocator        AX 焦点控件定位与屏幕坐标换算
├── OVCPanelController     悬浮卡片、倒计时、粘贴动作
├── OVCSettingsWindow      主设置窗口（含侧栏语言切换）
├── OVCStatusController    菜单栏图标与菜单
├── OVCLaunchAgent         开机自启（SMAppService 登录项）
├── OVCLocalization        运行时语言解析与英文文案查询
tools/icongen.m            生成 .icns 与菜单栏图标预览
tools/check_l10n.py        校验英文 key 覆盖与格式占位符
tests/test_extractor.m     提取规则单元测试
```

## 4. 数据流

```
chat.db ──(1.2s 轮询 ROWID 增量)──> OVCMessageStore
                                        │ text / attributedBody
                                        ▼
                              OVCCodeExtractor（关键词 + 数字密度打分）
                                        │ OVCCode {code, sender, date}
                    ┌───────────────────┼────────────────────┐
                    ▼                   ▼                    ▼
              OVCHistoryStore       NSPasteboard        OVCPanelController
              （去重、最多 50 条）   （自动复制开关）      （AX 定位 + 倒计时 + 粘贴）
```

去重规则：同一 `message.guid` 只处理一次；同一验证码 90 秒内不重复弹窗；启动时以当前最大 ROWID 为基线，不回溯历史（另提供“扫描最近 24 小时”手动补扫）。

## 5. 权限模型

| 权限 | 用途 | 检测方式 | 缺失表现 |
| --- | --- | --- | --- |
| 完全磁盘访问 | 读 `chat.db` | 只读打开失败且 `errno=EPERM` | 菜单栏状态“需要授权”，设置页红色提示 |
| 辅助功能 | AX 定位 + 模拟 ⌘V | `AXIsProcessTrusted()` | 弹窗退化为鼠标附近；粘贴退化为仅复制 |
| 通知（可选） | 后台提示 | `UNUserNotificationCenter` 授权状态 | 不影响主流程，0.5.3 未启用 |

降级策略：任一项缺失都不阻断启动，功能按可用性降级，并在设置页给出可点击的授权入口。

## 6. 打包与分发

1. `make app`：编译双架构 → `lipo` 合并 → 组装 `一码.app`（Info.plist、Resources/AppIcon.icns）→ `codesign --force --deep --sign -`。
2. `make pkg`：`pkgbuild --root payload --component-plist assets/component.plist --identifier com.oneverifycode.pkg --version 0.5.3` → `productbuild` 生成分发版 pkg，安装位置 `/Applications/一码.app`。组件配置设置 `BundleIsRelocatable=false`，避免安装器按 bundle id 把 App 重定位到旧构建目录。
3. `make dmg`：把 App 与 `/Applications` 软链放入临时目录，`hdiutil create -format UDZO` 生成拖拽安装镜像。
3. 测试版未签名/未公证，首次打开需右键 →“打开”，或执行 `xattr -dr com.apple.quarantine`（README 中说明）。

## 7. 风险与取舍

| 风险 | 影响 | 处置 |
| --- | --- | --- |
| 系统升级改变 `chat.db` 结构 | 读取失败 | 只依赖 `message.text/attributedBody/date/handle_id` 等长期稳定字段；失败时写日志并在菜单提示 |
| `attributedBody` 为 typedstream 二进制 | 漏识别 | 采用“可打印串提取 + 元数据词过滤”启发式，实测覆盖本机 2915 条无 text 消息 |
| ad-hoc 签名导致 TCC 重授权 | 每次升级需重勾权限 | 测试版文档标注；正式版用 Developer ID 解决 |
| AX 定位失败（部分自绘输入框） | 弹窗位置退化 | 退化为鼠标位置 / 屏幕右上角，功能不丢失 |
| 轮询带来磁盘唤醒 | 轻微耗电 | 1.2 s 间隔、单条 SQL、空闲时 CPU < 0.3% |

## 8. 里程碑

- M1 文档 + 骨架（本次）
- M2 提取规则 + 单测通过（本次）
- M3 监听/剪贴板/弹窗/菜单/设置可用（本次）
- M4 图标与视觉定稿、真机走查（本次）
- M5 pkg 打包与安装验证（本次）
- M6 正式版：Developer ID 签名 + 公证 + Sparkle 更新（后续）

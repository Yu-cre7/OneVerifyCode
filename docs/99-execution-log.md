# 一码 OneVerifyCode · 执行日志

项目根：`/Users/sheng/.sclaw/workspace/projects/OneVerifyCode`  
日期：2026-11-18  
版本：0.5.3（测试版）

## 快速索引

| 编号 | 主题 | 结果 |
| --- | --- | --- |
| S01 | 环境与数据源可行性核实 | 通过（macOS 15.8.3 / CLT / chat.db 可读） |
| S02 | 工具链路线决策（Swift → ObjC） | 通过（Swift 模块冲突，改用 ObjC） |
| S03 | 项目骨架与四份文档 | 完成 |
| S04 | 提取器与单元测试 | 39/39 通过（修复 3 项） |
| S05 | 全量编译与错误修复 | 通过（4 类编译错误） |
| S06 | 图标、离屏视觉走查与调整 | 完成（含历史区底色修正） |
| S07 | 真机短信库自检 | 46 条消息，识别 17 条验证码 |
| S08 | 运行态与悬浮卡片验证 | 通过（菜单、卡片、真实短信） |
| S09 | pkg 打包与负载校验 | 通过（515 KB，双架构） |
| S10 | 最终状态与已知限制 | 记录 |
| S11 | 安装重定位缺陷与菜单栏兜底 | 修复（组件包禁止重定位；状态项不可见时显示 Dock） |
| S12 | v0.2.0 改名、监听/自动填充/阅后即焚、设置页重构、双格式打包 | 完成 |
| S13 | v0.3.0 状态图标、面板重绘、点击填入、菜单开关回归、删除两功能 | 完成 |
| S14 | v0.3.0 面板再收紧、圆角方角边框修复 | 完成（260×86 / 30pt / radius 16） |
| S15 | v0.4.0 弹窗主题化、菜单重排、历史摘要、设置外观/关于分页 | 完成（5 配色 / 3 尺寸 / 透明度 / 46 项单测） |
| S16 | v0.4.0 修复开机自启重复图标、配色勾选反向 | 完成（进程数保持 1；勾选方向修正） |
| S17 | v0.4.1 新增纯白/纯黑主题 | 完成（7 套配色；纯黑勾选可见；46 项回归） |
| S18 | v0.4.2 修复开机自启未加入系统登录项 | 完成（改用 SMAppService；注册/注销验证通过） |
| S19 | v0.5.0 全局中英文切换与双语 README | 完成（163 keys / 167 translations；0 missing / 0 format mismatch） |
| S20 | v0.5.0 安装包构建与校验 | 完成（pkg/dmg 0.5.0；Universal；签名通过） |
| S21 | 采用 MIT 许可证 | 完成（新增 LICENSE；中英文 README 已更新） |
| S22 | v0.5.1 权限页操作按钮重做 | 完成（28pt 自适应 CTA；中英文明暗预览通过；0.5.1 包已校验） |
| S23 | v0.5.2 窗口拖拽、关于页与 DMG 说明 | 完成（仅左侧拖动；GitHub 入口；DMG 含安装说明；0.5.2 包已校验） |
| S24 | v0.5.3 GitHub 发布整改、0–100% 透明度与 README 截图 | 完成（真实仓库地址；记录页/菜单截图；仓库规范文件；0.5.3 包已校验） |

---

## S01 环境与数据源可行性核实

**目的**：确认能否在没有 Xcode 的机器上构建 macOS App，以及短信数据库是否可读。

**命令**

```bash
sw_vers
xcode-select -p
swift --version
which swift swiftc xcrun codesign pkgbuild productbuild lipo plutil iconutil sips
ls -l ~/Library/Messages/chat.db
sqlite3 ~/Library/Messages/chat.db "select count(*) from message;"
sqlite3 ~/Library/Messages/chat.db "select count(*) from message where text like '%验证码%' or text like '%code%';"
sqlite3 ~/Library/Messages/chat.db "select count(*) from message where attributedBody is not null and text is null;"
```

**结果**

- macOS 15.8.3（24H241），Intel i7-1068NG7，磁盘剩余 120 GB。
- 仅安装 Command Line Tools（`/Library/Developer/CommandLineTools`），无 Xcode；`pkgbuild`、`productbuild`、`iconutil`、`lipo` 均可用。
- Swift 6.1.2，SDK MacOSX15.5。
- `chat.db` 存在且可读：6799 条消息，其中 581 条含“验证码/code”，2915 条正文只在 `attributedBody`（`text` 为 NULL）。

**结论**：可构建、可打包；`attributedBody` 必须做兜底解码，否则会漏掉近一半正文。

---

## S02 工具链路线决策（Swift → ObjC）

**目的**：验证 Swift + AppKit 可行性。

**命令**

```bash
mkdir -p /tmp/swifttest3 && cd /tmp/swifttest3
cat > a.swift <<'EOF'
import AppKit
let app = NSApplication.shared
print("ok", NSStatusBar.system.thickness)
EOF
time swiftc -Onone a.swift -o a
```

**实际报错（保留原文）**

```
/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap:13:8: error: redefinition of module 'SwiftBridging'
13 | module SwiftBridging {
   |        `- error: redefinition of module 'SwiftBridging'
/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap:13:8: note: previously defined here
error: failed to build module 'AppKit' for importation due to the errors above
```

**定位**

```bash
ls -la /Library/Developer/CommandLineTools/usr/include/swift/
# module.modulemap  2023-08-18（旧）
# bridging.modulemap 2025-04-16（新）
sudo -n true   # → sudo: a password is required
```

两个 modulemap 都声明 `SwiftBridging`，修复需 root 删除旧文件，当前会话无 sudo 密码，不能改系统工具链。

**处置**：改用 Objective-C + AppKit（不经过 Swift 模块导入）。可行性验证：

```bash
cd /tmp/objctest
cat > m.m <<'EOF'
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <sqlite3.h>
int main(void) {
  @autoreleasepool {
    NSLog(@"ok thickness=%.0f ax=%d sqlite=%s",
          NSStatusBar.systemStatusBar.thickness, AXIsProcessTrusted(), sqlite3_libversion());
  }
  return 0;
}
EOF
time clang -fobjc-arc -O2 m.m -o m -framework Cocoa -framework ApplicationServices -lsqlite3
./m
```

**结果**：编译 2.26 秒，输出 `ok thickness=22 ax=0 sqlite=3.43.2`。AppKit 能力与 Swift 完全一致，后续全部使用 ObjC。

---

## S03 项目骨架与四份文档

**命令**

```bash
mkdir -p projects/OneVerifyCode/{docs,src,assets,tools,tests,build,dist}
```

**产物**

- `docs/01-tech-plan.md`：需求边界（R1–R10）、技术选型、模块划分、数据流、权限模型、打包方案、风险。
- `docs/02-design-direction.md`：气质、色板 Token、字阶、间距、圆角、图标、动效、四态、无障碍、文案。
- `docs/03-api-contract.md`：单机应用，改为“模块契约 + 系统接口 + 错误码（1xxx–5xxx）+ 持久化契约”。
- `docs/04-data-model.md`：chat.db 只读表结构、偏好键、history.json、内存模型、状态机、迁移。

**说明**：未使用 `scripts/new-project.sh`（模板为 Flutter + Spring Boot），因为本项目是原生 macOS 菜单栏应用，Flutter macOS 构建仍依赖 Xcode；此处按 AGENTS.md 的“先文档后代码”要求手工建立同构文档。

---

## S04 提取器与单元测试

**目的**：把“短信正文 → 验证码”做成纯函数并覆盖真实文案。

**命令**

```bash
make test
```

**首轮结果：36/39，通过 3 项失败**

```
FAIL  code: 12AB34
      expected 12AB34, got (nil)
FAIL  验证码 AB12CD，请勿泄露
      expected AB12CD, got (nil)
FAIL  解码后再提取失败
结果：36/39 通过，3 失败
```

**根因与修复**

1. 字母数字码：正则使用 `[A-Z0-9]`，但匹配对象是 `lowercaseString`，小写字母永远不命中。
   - 修复：改为 `(?<![A-Za-z0-9])([A-Za-z0-9]{6,8})(?![A-Za-z0-9])`，命中后再 `uppercaseString`。
2. `attributedBody` 解码：扫描时只允许中文首字节（0xE4–0xE9），UTF-8 续字节（0x80–0xBF）被判为二进制，导致“验证码”与数字被切断。
   - 修复：改为按 UTF-8 序列扫描（首字节判断长度 + 校验续字节），有效序列整段保留，非法字节断开。
3. 顺带修正：四位年份不再无条件排除，改为“距关键词 >12 字符才排除”，避免把 `验证码 2024` 误杀；金额/时长判断先去除尾部空白，`5000 元` 才能被正确排除；新增 `*` 前置判断，排除 `138****8000`。

**复测**

```bash
make test
# 结果：39/39 通过，0 失败
```

覆盖：支付宝/京东/美团/银行/Apple/Google 文案、全角数字、`123 456`、`123-456`、OTP/PIN、订单号、日期、金额、脱敏手机号、9 位超长码、字母数字码、宽松模式年份排除。

---

## S05 全量编译与错误修复

**命令**

```bash
for f in src/*.m; do
  clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -c "$f" -o /tmp/$(basename "$f").o
done
```

**遇到的编译错误（保留原文）**

1. `property follows Cocoa naming convention for returning 'owned' objects`
   - 属性名 `copyButton` 被 ARC 当作 `copy` 家族方法。
   - 修复：先改 `copyCodeButton`（仍命中），最终改为 `duplicateButton`。
2. `receiver 'CAMediaTimingFunction' for class message is a forward declaration`
   - `NSAnimationContext` 只前向声明。
   - 修复：`#import <QuartzCore/QuartzCore.h>`，链接 `-framework QuartzCore`。
3. `unknown type name 'nullable'`（block 参数内）
   - 修复：改为 `NSError * _Nullable error`。
4. KVC 风险：`[self setValue:titles forKey:@"sectionTitles"]` 无对应属性会在运行时抛 `NSUnknownKeyException`。
   - 修复：新增 `@property NSArray<NSTextField *> *sectionTitles`，改为点语法。
5. 设置窗口初始 720pt，小屏可能超出可视区。
   - 修复：降为 660pt（内容 800pt 可滚动）。

**结果**：`make app` 通过，`lipo -info` 显示 `x86_64 arm64`，`codesign -dv` 显示 `Signature=adhoc`。

---

## S06 图标、离屏视觉走查与调整

**命令**

```bash
make icons
"build/一码.app/Contents/MacOS/OneVerifyCode" --render-previews "$PWD/build/preview"
```

**产物**（`build/preview/`）

- `settings-light.png` / `settings-dark.png` / `settings-permission-light.png`
- `panel-light.png` / `panel-dark.png`
- `icon-1024.png`、`statusbar@4x.png`

**走查发现与处置**

1. 历史表格区域为纯白，与卡片 `#F5F6F8` 割裂。
   - 处理：`table.backgroundColor = surfaceAlt`、隐藏表头 `headerView = nil`、`scroll.contentView.drawsBackground = NO`；二次渲染确认融合。
2. 权限缺失态：状态文字红色、两项“未允许”橙色、“去授权”按钮可用，符合四态要求。
3. 悬浮卡片：圆角 16、状态点、30pt 等宽验证码、倒计时、进度条、三个按钮均正常；深色模式对比度通过目测与色值计算（`#9A9AA0` on `#1C1C1E` ≈ 6.4:1）。

**注意**：离屏窗口非 key window，`NSSwitch` 的开启态在截图中呈灰色（系统行为）；真实激活窗口为强调色。

---

## S07 真机短信库自检

**命令**

```bash
"build/一码.app/Contents/MacOS/OneVerifyCode" --self-test
```

**实际输出**

```
== 一码自检 ==
短信库: 可读取
最大 ROWID: 7224
最近 7 天消息: 46
  样例: 7***3  来源 1069****69
  样例: 9***8  来源 1069****69
  样例: 3***0  来源 1069****69
有正文: 46，识别验证码: 17
辅助功能: 未授权
开机启动: 关闭
完全磁盘访问: 已授权
```

**说明**：样例已脱敏，仅打印首尾字符。17/46 的识别量与“含验证码的短信占比”相符；未命中的多为营销/通知类短信。

---

## S08 运行态与悬浮卡片验证

**命令**

```bash
open "build/一码.app"
sleep 5
pgrep -fl "一码.app/Contents/MacOS/OneVerifyCode"
tail -12 ~/Library/Logs/OneVerifyCode.log
screencapture -x /tmp/evc-screen.png
```

**结果**

- 进程存在，日志：
  ```
  2026-11-17 15:03:44 一码启动，version 0.2.0
  2026-11-17 15:03:44 监听已启动
  ```
- 菜单栏截图确认：`● 监听中 · 今日 0 条`、`✓ 自动复制到剪贴板`、`✓ 输入框旁提示`、`开机启动`、`最近验证码`、`扫描最近 24 小时`、`设置…`、`权限`、`退出一码`。
- 状态图标为 18pt 圆角方框 + 对勾，模板图随明暗自适应。

**悬浮卡片实机验证**

```bash
("build/一码.app/Contents/MacOS/OneVerifyCode" --demo-panel &)
sleep 4
screencapture -x /tmp/evc-panel.png
```

- 截图确认：卡片浮于最前（`NSStatusWindowLevel`）、倒计时 7s、按钮“粘贴/复制/关闭”正常、进度条与圆角无溢出。
- 无辅助功能权限时按鼠标位置定位，符合降级设计。

**真实短信**

运行期间日志出现：

```
2026-11-17 15:08:57 识别验证码 8****6（关键词 验证码，来源 1068****45）
```

说明“新短信 → 提取 → 剪贴板/弹窗”链路在真实数据上已跑通（验证码已脱敏）。

**副作用记录**：macOS 弹出“后台项目已添加 OneVerifyCode”通知。检查 `~/Library/LaunchAgents` 无一码 plist，`defaults` 中 `launchAtLogin = 0`，判断为系统对 `LSUIElement` 应用的登录项登记提示，未实际启用开机启动。

---

## S09 pkg 打包与负载校验

**命令**

```bash
make pkg
pkgutil --check-signature dist/OneVerifyCode-0.2.0.pkg
OUT=/tmp/evc-pkg-$(date +%s)
pkgutil --expand-full dist/OneVerifyCode-0.2.0.pkg "$OUT"
APP=$(find "$OUT" -name "一码.app" -maxdepth 4 | head -1)
lipo -info "$APP/Contents/MacOS/OneVerifyCode"
codesign -dv "$APP"
plutil -p "$APP/Contents/Info.plist"
```

**结果**

- 产物：`dist/OneVerifyCode-0.2.0.pkg`，515 KB。
- 负载：`Payload/Applications/一码.app`，安装位置 `/Applications`。
- 架构：`x86_64 arm64`。
- 签名：App 为 ad-hoc；**pkg 本身未签名**（`Status: no signature`），无 Developer ID，测试版符合预期。
- Info.plist：`CFBundleIdentifier=com.oneverifycode.app`、`CFBundleShortVersionString=0.2.0`、`LSUIElement=true`、`LSMinimumSystemVersion=13.0`。

**未执行**：未安装到 `/Applications`，避免改动系统；改用 `--expand-full` 校验负载，等价确认文件结构与权限。

---

## S10 最终状态与已知限制

**已实现（v0.2.0）**

- 菜单栏常驻（无 Dock）、极简模板图标、菜单常用配置与最近验证码。
- 只读监听 `chat.db`，1.2s 轮询，启动只建基线不回放历史。
- 文本/`attributedBody` 双通道解码，关键词 + 数字密度 + 上下文排除。
- 自动复制、悬浮卡片、AX 定位输入框、⌘V 自动粘贴、倒计时与悬停暂停。
- 设置页：权限状态与跳转、三项行为开关、停留时长、长度规则、关键词开关、历史表格、补扫、清空。
- LaunchAgent 开机自启、JSON 历史（50 条、0600）、滚动日志。
- 单元测试 39 项、离屏渲染预览、`--self-test`、`--demo-panel` 诊断入口。

**已知限制**

1. ad-hoc 签名：覆盖安装后系统可能要求重新勾选完全磁盘访问/辅助功能。
2. 依赖 iPhone 短信转发；Mac 独立号码短信不进入 `chat.db`。
3. 未签名 pkg：跨机分发时需右键打开或去除 quarantine。
4. 少数安全输入框拒绝模拟按键，退化为仅复制。
5. 未做 Developer ID 公证与自动更新（v0.2 计划）。

**交付清单**

- 应用：`build/一码.app`
- 安装包：`dist/OneVerifyCode-0.2.0.pkg`
- 源码：`src/`、`tools/`、`tests/`
- 文档：`docs/01–04`、`README.md`、本日志
- 视觉证据：`build/preview/*.png`

---

## S11 安装重定位缺陷与菜单栏兜底

**现象**：双击 0.1.0 pkg 后提示安装成功、`pkgutil --pkgs` 有收据，但 `/Applications` 没有 App，启动台与 Dock 都找不到。

**定位**

```bash
pkgutil --files com.easyverifycode.pkg | head
ls -ld /Applications/易码.app
grep -i easyverifycode /var/log/install.log | tail
ls -ld build/易码.app
```

安装日志显示 `Parent bundle com.easyverifycode.app will be atomically shoved.`，组件包 `PackageInfo` 带 `<relocate><bundle id="com.easyverifycode.app"/></relocate>`。安装器按 bundle id 找到之前从 `build/易码.app` 启动过的副本，把新版本“重定位”到构建目录并改为 root 所有，因此 `/Applications` 从未出现 App。

**修复**

1. 新增 `assets/component.plist`，对 `Applications/一码.app` 设置 `BundleIsRelocatable=false`，`pkgbuild --component-plist` 使用它；生成的 `PackageInfo` 变为空 `<relocate/>`。
2. `Makefile` 的 APP 输出改到 `build/stage/一码.app`；原 `build/易码.app` 已被 root 锁定，普通用户 `mv` 返回 `Permission denied`，不再尝试改写。
3. 安装包与 dmg 均从 `build/stage/一码.app` 组装。

**菜单栏兜底**

菜单栏图标过多时，`NSStatusItem` 会被系统排到屏幕外：

```bash
osascript -e 'tell application "System Events" to tell process "OneVerifyCode" to get {position, size} of menu bar item 1 of menu bar 1'
# -14958, 0, 36, 24
```

新增 `-[OVCStatusController isStatusItemVisible]`：检查状态项窗口是否落在 `NSScreen.frame` 内。启动 1.2 秒后若不可见，自动把 `dockIcon` 置 YES 并切换为 `NSApplicationActivationPolicyRegular`；点 Dock 图标触发 `applicationShouldHandleReopen:` 打开设置。设置页也提供“在 Dock 中显示图标”开关。

**验证**

```bash
/usr/bin/lsappinfo info -only ApplicationType -pid <pid>
# "ApplicationType"="Foreground"
osascript -e '... get name of every UI element of list 1' | grep 一码
# 一码
```

日志：

```
状态项检测：x=-14957.0 y=876.0 w=34.0 h=24.0 visible=0
状态项不在屏幕内，自动显示 Dock 图标
显示方式切换为Dock + 菜单栏（ok=1，当前=0）
```

（`NSApplicationActivationPolicyRegular = 0`。）

---

## S12 v0.2.0：改名、功能与双格式打包

### S12.1 全局改名

内容替换 `EVC→OVC`、`EasyVerifyCode→OneVerifyCode`、`easyverifycode→oneverifycode`、`易码→一码`、`0.1.0→0.2.0`；并把 `src/EVC*.{h,m}` 重命名为 `src/OVC*.{h,m}`。

```bash
ls src | head
grep -rn "EVC\|EasyVerifyCode\|easyverifycode\|易码" src tests tools Makefile assets README.md docs
# 仅剩已编译的 tools/icongen 二进制
```

同步修改：bundle id `com.oneverifycode.app`、可执行文件 `OneVerifyCode`、App 名 `一码.app`、日志 `~/Library/Logs/OneVerifyCode.log`、数据目录 `~/Library/Application Support/OneVerifyCode`、LaunchAgent `com.oneverifycode.app.plist`、pkg id `com.oneverifycode.pkg`。

### S12.2 偏好与功能

- 新增 `monitoringEnabled`（默认 YES）、`autoFill`（默认 NO）、`burnAfterUse`（默认 NO）。
- `panelDuration` 下限由 3 秒改为 1 秒，范围 1–20；滑块同步。
- 监听总开关：`stopMonitor` 停轮询并收起卡片；状态文字“监听已关闭”，状态点灰色；设置页行为/规则/记录整体置灰，权限区保持可用。
- 自动填充：`OVCFocusLocator focusedElementIsTextInput` 校验 AX role 为 TextField/TextArea/ComboBox、`AXEditable=true` 且非密码框；复制后 150ms 再校验前台 App 未变，再发 ⌘V。
- 阅后即焚：手动粘贴成功或自动填充成功后，`OVCHistoryStore removeCode:` 删除本地记录、清空仍等于验证码的剪贴板并收起卡片。**不改 `chat.db`**，避免破坏 Messages 与 iCloud 同步。
- 菜单精简为：状态 / 监听 / 最近验证码 / 设置… / 退出一码。

**验证（真实菜单点击）**

```bash
defaults read com.oneverifycode.app monitoringEnabled   # 关闭后 0
tail -1 ~/Library/Logs/OneVerifyCode.log                # 监听已关闭
defaults read com.oneverifycode.app monitoringEnabled   # 再打开后 1
tail -1 ~/Library/Logs/OneVerifyCode.log                # 监听已启动
```

菜单结构读取结果：

```
监听中 · 今日 17 条, missing value, 监听, missing value, 最近验证码, missing value, 设置…, 退出一码
```

说明：用 `AXPress` 连续触发菜单项时曾出现一次“关闭后 1 秒又启动”，改为单次点击后稳定；判断为自动化重复触发，非真实单击路径。

### S12.3 设置页与图标

- 行为卡扩到 8 行：监听短信、自动复制、输入框旁提示、自动填充、阅后即焚、开机启动、Dock 图标、提示停留。
- 页面高度 800 → 980，窗口仍 660 可滚动；新增 `settings-monitoring-off-light.png` 走查置灰态。
- 图标改为石墨底 + 暖白“1” + 薄荷认证徽章；菜单栏改为纯数字“1”模板图，去掉方框 + 对勾。

```bash
make app
"build/stage/一码.app/Contents/MacOS/OneVerifyCode" --render-previews "$PWD/build/preview"
# previews:ok
```

预览：`build/preview/icon-1024.png`、`statusbar@4x.png`、`settings-light.png`、`settings-dark.png`、`settings-monitoring-off-light.png`。

### S12.4 编译错误

```
src/OVCFocusLocator.m:83:48: error: use of undeclared identifier 'kAXEditableAttribute'
```

SDK 未导出该常量，改用 `CFSTR("AXEditable")` 读取属性，编译通过。

### S12.5 打包与校验

```bash
make test    # 39/39 通过，0 失败
make pkg     # dist/OneVerifyCode-0.2.0.pkg
make dmg     # dist/OneVerifyCode-0.2.0.dmg
pkgutil --expand-full dist/OneVerifyCode-0.2.0.pkg /tmp/ovc-pkg-...
lipo -info .../Applications/一码.app/Contents/MacOS/OneVerifyCode
plutil -p .../Info.plist
xar -xf build/OneVerifyCode-component.pkg PackageInfo -C ...
grep relocate PackageInfo
hdiutil attach dist/OneVerifyCode-0.2.0.dmg -nobrowse -readonly
hdiutil detach /Volumes/一码
```

结果：

- `lipo -info`：`x86_64 arm64`
- `Info.plist`：`CFBundleDisplayName=一码`、`Executable=OneVerifyCode`、`ShortVersion=0.2.0`、`LSUIElement=1`
- 组件包：`<relocate/>`，不再携带可重定位 bundle
- DMG：`/Volumes/一码` 内为 `一码.app` + `Applications -> /Applications`
- 体积：pkg 530 KB、dmg 780 KB；均为 ad-hoc 签名

### S12.6 本轮已知限制

- 自动填充只做“可编辑文本框”级判断，无法保证一定是验证码表单；默认关闭。
- “阅后即焚”是本地记录/剪贴板语义，不删除短信 App 数据。
- 旧 0.1.0 的 `/Applications/易码.app` 与新 App 共存，需手动移除；旧偏好与历史不会迁移。
- pkg 仍未签名/公证。

---

## S13 v0.3.0：状态图标、面板重绘、点击填入与开关回归

**目标**：按 7 项反馈收敛交互：菜单栏图标增加方框；验证码面板更紧凑原生；取消粘贴/复制与关闭按钮；点击数字直接填入；显示来源；用进度条自动关闭；菜单恢复四项开关；删除自动填充与阅后即焚。

### S13.1 菜单栏图标

`src/OVCIconFactory.m` 的 `drawStatusGlyphInRect:` 改为“圆角方框 + 数字 1”：

```objc
NSRect frame = NSInsetRect(rect, inset, inset);
NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:frame
                                                   xRadius:frame.size.width * 0.24
                                                   yRadius:frame.size.width * 0.24];
box.lineWidth = lineWidth;
[color setStroke];
[box stroke];
CGFloat numeralWidth = lineWidth * 0.90;
```

18pt 模板图，外框线宽 1.45；仍走 template image，浅色/深色菜单栏自动反色。预览：`build/preview/statusbar@4x.png`。

### S13.2 菜单恢复四项开关

`OVCStatusController.m` 在“监听”与“最近验证码”之间重建：

- 自动复制到剪贴板
- 在输入框旁弹出提示
- 开机自动启动
- 在 Dock 中显示图标

菜单每次打开由 `menuNeedsUpdate:` 重建，勾选状态直接读 `OVCPrefs`；设置页通过 `OVCPrefsDidChangeNotification` 同步。

新增保护：菜单栏状态项已在屏幕外时，Dock 图标是唯一入口，关闭操作会被拒绝并提示“暂时不能隐藏 Dock 图标”，避免应用彻底不可访问。

### S13.3 验证码面板重绘

`OVCPanelController.m` 整体重写：

| 项 | 旧 | 新 |
| --- | --- | --- |
| 尺寸 | 约 324×152 | 300×104 |
| 背景 | 自绘卡片 | `NSVisualEffectView`（popover 材质）+ 86% 表面色 |
| 内容 | 标题、来源、验证码、按钮、倒计时 | 来源小字 + 34pt 验证码 + 3px 进度条 |
| 操作 | 粘贴/复制/关闭按钮 | 仅验证码数字热区，点击即复制并 ⌘V |
| 关闭 | 关闭按钮/倒计时文字 | 底部进度条缩短，结束淡出 |
| 定位 | 输入框附近 | 焦点文本框正下方；无文本框时鼠标右下方，并按屏幕边缘收敛 |

关键实现：

- `OVCPanelContentView` 只画卡片、进度条；`codeRect` 外扩 10×8pt，`resetCursorRects` 显示手型。
- 点击在 `mouseUp` 触发，且 `dispatch_async` 到下一轮主队列再收起面板，避免 mouseUp 穿透到下层 App。
- 面板 `styleMask` 含 `NonactivatingPanel`，`canBecomeKeyWindow=NO`，不抢焦点。
- `presentCode:sender:duration:` 将来源格式化为 `一码 · 1069***213`；`OVCFocusLocator` 新增 `focusedTextInputRect`，仅返回可编辑文本输入框。
- 计时器 50ms 步进，`progress = remaining / total`；到 0 调 `dismiss`，160ms 淡出后 `orderOut`。

### S13.4 删除自动填充与阅后即焚

删除范围：

- `OVCPrefs` 的 `autoFill`、`burnAfterUse` 属性、默认值与 setter
- `OVCPanelController.onCodeUsed`
- `OVCAppDelegate` 的 `autoFillCode:`、`burnCode:` 与识别后的自动粘贴分支
- `OVCHistoryStore removeCode:`
- 设置页两个开关、两个 action、置灰数组条目
- README 与 docs/01、03 的对应说明

保留“点击数字 → 复制 + 当前输入框 ⌘V”，这是一次性用户动作，不是识别后自动填充。

### S13.5 设置页

行为区从 8 行收缩为 6 行：

1. 监听短信
2. 自动复制到剪贴板
3. 在输入框旁弹出提示
4. 开机自动启动
5. 在 Dock 中显示图标
6. 提示停留（1–20 秒）

页面高度 980 → 940，行为卡 292 → 260；标题、底部留白与其它卡片位置同步上移。版本号统一为 0.3.0：

- `Makefile` `VERSION := 0.3.0`
- `assets/Info.plist` `CFBundleShortVersionString=0.3.0`、`CFBundleVersion=3`
- `assets/distribution.xml` `version="0.3.0"`
- 设置页副标题 `OneVerifyCode · 0.3.0 beta`
- README 构建/安装路径

### S13.6 验证

```bash
make test
# 结果：39/39 通过，0 失败

make app
# built build/stage/一码.app

./build/OneVerifyCode --render-previews build/preview
# previews:ok
```

真实窗口与面板：

- Dock 图标打开设置：窗口 580×688，行为区 6 行、无自动填充/阅后即焚，副标题 0.3.0。
- 面板出现在焦点文本框下方：在微信搜索框/Edge 输入框聚焦时，面板原点为输入框左下附近。
- 点击数字：剪贴板从 `SENTINEL` 变为验证码；`sendPasteShortcut` 返回成功，验证码出现在 Edge 页面输入框。
- 自动关闭：面板出现后计时，约 8 秒进度条走完；10 秒时 `CGWindowList` 已无面板窗口。
- 无焦点时：点击页面空白后弹出，面板跟随鼠标并按屏幕/Dock 边缘收敛（鼠标 1250,800，面板 1132,733）。
- 菜单栏状态项仍被系统排到屏幕外（x≈-14957），Dock 兜底生效；菜单本体无法在本机真实点开，四项结构由 `menuNeedsUpdate:` 静态检查与编译验证。

### S13.7 产物

```bash
make pkg   # dist/OneVerifyCode-0.3.0.pkg
make dmg   # dist/OneVerifyCode-0.3.0.dmg
```

- pkg：组件包禁止重定位，安装到 `/Applications/一码.app`
- dmg：`/Volumes/一码` 内为 `一码.app` + `Applications -> /Applications`
- 仍为 ad-hoc 签名、未公证；覆盖安装后可能需重新勾选辅助功能/完全磁盘访问

### S13.8 已知限制

- 菜单栏空间不足时，四项菜单开关只能从设置页操作；Dock 图标被保护为不可关闭。
- 点击填入依赖辅助功能权限；无权限时复制成功并弹窗引导，不会静默失败。
- 安全输入框（密码框）仍可能拒绝模拟 ⌘V，这是系统保护。
- 面板位置按焦点输入框左下角对齐；极窄输入框或跨屏场景可能出现水平偏移，已做屏幕边缘收敛。

---

## S14 v0.3.0 视觉修正：面板再收紧、圆角双层边框

**反馈**：面板整体仍偏大；验证码数字略大；四角圆角外还有方角边框，像叠了两层；希望圆角再大一点。

### S14.1 尺寸与字阶

`src/OVCPanelController.m`：

```objc
static const CGFloat OVCPanelWidth = 260.0;   // 300 → 260
static const CGFloat OVCPanelHeight = 86.0;   // 104 → 86
static const CGFloat OVCPanelRadius = 16.0;   // 12 → 16
```

- 来源：11pt 居中，上边距更紧。
- 验证码：34pt → 30pt（复用 `OVCFontCode()`），字距保持 2.4。
- 进度条：左右内边距 18 → 16，距底 8 → 6。
- 移除不再使用的 `OVCFontCodeLarge` Token，避免字阶出现两套验证码字号。

### S14.2 圆角外方角边框

**原因**：`NSVisualEffectView` 的背板由系统私有图层绘制，`layer.cornerRadius` + `masksToBounds` 只裁切普通子图层，背板仍按矩形边界绘制，于是圆角外露出一圈方角；再叠加内容视图的 1px 圆角描边，看起来像两层边框。

**修复**：

```objc
effect.maskImage = OVCPanelMaskImage(NSMakeSize(OVCPanelWidth, OVCPanelHeight), OVCPanelRadius);
panel.hasShadow = NO;   // 去掉矩形窗口阴影，避免圆角外再出现方角灰边
```

`OVCPanelMaskImage` 用 `NSBezierPath` 圆角矩形离屏绘制成 alpha 蒙版，`NSVisualEffectView` 的背板严格按圆角裁切；内容视图只保留一层 1px 圆角描边。

### S14.3 验证

```bash
make test
# 结果：39/39 通过，0 失败

make app
# built build/stage/一码.app

./build/OneVerifyCode --demo-panel
# 面板 260×86；点击数字后剪贴板由 SENTINEL 变为 482913
```

实际截图：

- `build/preview/panel-compact.png`（260×86 原生截图，4x 放大走查）
- `build/preview/panel-light.png`（离屏预览，浅色）
- `build/preview/panel-dark.png`（离屏预览，深色）

走查结论：四角只剩单层圆角描边，圆角外无方角背板；数字 30pt 仍明显大于来源文字，但不再压满卡片；点击热区随卡片缩小后仍覆盖整个数字区域。

---

## S15 v0.4.0：弹窗主题化、菜单重排、历史摘要与设置外观/关于

**目标**：在不改 logo 的前提下，把验证码弹窗从固定单色卡片升级为多主题、可调透明度与尺寸的视觉组件；设置页新增“外观”和“关于”；菜单栏按常用程度重排并支持关于跳转；历史记录新增固定长度的脱敏内容摘要。

### S15.1 弹窗主题与尺寸

- `src/OVCTheme.h/.m` 新增 5 套面板主题（极光蓝、暮光紫、薄荷青、暖琥珀、石墨灰），每套提供渐变起止色、强调色、主/次文字色和高光色，浅色/深色外观各自解析。
- 新增面板尺寸：紧凑 `224×74`、标准 `244×80`、宽适 `276×90`；默认标准比旧版 `260×86` 左右各收 8pt、上下各收 3pt。
- `src/OVCPanelController.m` 重写内容视图：
  - 渐变填充 + 左上柔光 + 1px 主题高光描边；
  - 来源文字与验证码均水平居中；
  - 验证码字号随尺寸 27/30/34pt 调整；
  - 底部进度条 2.5px，颜色取主题强调色；
  - `NSVisualEffectView` 圆角用 `maskImage` 裁切，尺寸变化时同步重建蒙版。
- `src/OVCPrefs` 新增 `panelTheme`、`panelSize`、`panelTransparency`（0–40%，默认 12%）；背景透明度只作用于渐变层，文字保持可读。
- 渲染证据：`build/preview/panel-{aurora,twilight,mint,amber,graphite}-light.png`、`panel-aurora-dark.png`、`panel-graphite-dark.png`、`panel-size-{紧凑,标准,宽适}.png`。

### S15.2 设置页新增“外观”和“关于”

- 设置页导航由 4 项扩展为 6 项：权限、行为、外观、识别、记录、关于。
- **外观页**包含：
  - 顶部实时弹窗预览（渐变、圆角、来源/验证码居中）；
  - 5 个可选配色卡（渐变预览 + 名称 + 选中描边/勾选）；
  - 紧凑/标准/宽适三档尺寸；
  - 背景透明度滑杆（0–40%）与百分比。
- **关于页**为极简排版：原 logo、名称、版本、单句 tagline、两行简介与底部短句；未改 logo。
- 菜单“关于一码”通过 `OVCSettingsWindow showSection:5` 直接跳到关于页；“查看全部记录…”跳到记录页（section 4）。

### S15.3 菜单栏重排

`src/OVCStatusController.m` 的菜单顺序调整为：

1. 状态胶囊（禁用项）
2. 监听短信
3. 扫描最近 24 小时
4. 最近验证码（子菜单，显示验证码 + 摘要 + 时间 tooltip）
5. 自动复制到剪贴板
6. 在输入框旁弹出提示
7. 设置…
8. 关于一码
9. 退出一码

开机启动、Dock 图标等低频项只保留在设置页；常用动作放到菜单上半区，并用分隔线分成“监听 / 记录 / 提醒 / 应用”四组。

### S15.4 历史摘要列

- `OVCHistoryItem` 新增 `summary`，最多保存 28 个字符；旧 `history.json` 无该字段时兼容读取，表格显示“暂无摘要”。
- `OVCHistoryStore +summaryFromText:code:maxLength:`：
  - 折叠换行/多空格；
  - 验证码替换为圆点；
  - 兜底屏蔽 4–8 位连续数字与带空格的验证码；
  - 按组合字符截断，避免截断 emoji。
- 记录页新增“内容摘要”列，显示固定 16 个字符 + 省略号；列宽 190，来源列 150，时间列 110。
- 菜单“最近验证码”同样显示摘要（最多 18 个字符）与完整时间 tooltip。

### S15.5 验证

```bash
make test
# 39/39 提取规则通过
# 7/7 历史摘要通过
# 合计 46/46

make app
# built build/stage/一码.app

./build/OneVerifyCode --render-previews build/preview
# previews:ok (build/preview)
```

离屏逐页检查：权限、行为、外观、识别、记录、关于六页均无溢出；外观页 5 个配色卡、三档尺寸、透明度滑杆与预览正常；浅色/深色均通过。

实际窗口与真实弹窗：本轮桌面会话处于锁屏状态，未重新补拍真实窗口；安装包构建后仍需用户在解锁桌面后覆盖安装并重新检查辅助功能 TCC。此前 S14 已验证真实面板定位、点击填入与自动关闭；本轮改动集中在绘制/布局与设置，未改变点击与定位路径。

### S15.6 版本

- `Makefile`：`VERSION := 0.4.0`
- `assets/Info.plist`：`CFBundleShortVersionString=0.4.0`、`CFBundleVersion=4`
- `assets/distribution.xml`：`version="0.4.0"`
- 设置页/关于页版本回退值更新为 `0.4.0`

---

## S16 v0.4.0 缺陷修复：开机自启重复图标、配色勾选反向

### S16.1 开机自启后 Dock 出现第二个常驻图标

**现象**：在设置里打开“开机自动启动”后，Dock 立即多出一个一码图标，原图标仍在。

**根因**：`OVCLaunchAgent setEnabled:YES` 写入 plist 后立即执行了 `launchctl bootstrap`，而 plist 又设置了 `RunAtLoad=YES`，launchd 因此在当前会话马上又启动了一份一码进程。

**修复**：`src/OVCLaunchAgent.m`

- 开启时只写 plist 并执行 `launchctl enable gui/<uid>/com.oneverifycode.app`，不再 `bootstrap`；plist 会在下次登录时由 launchd 自动加载。
- 关闭时执行 `launchctl disable` 并删除 plist，不再 `bootout`；避免当前进程正好由 LaunchAgent 拉起时，关闭开关把自身杀掉。

**验证**：

```bash
BEFORE=$(ps -axo command | grep '[O]neVerifyCode' | wc -l | tr -d ' ')
# 调用只包含 OVCLaunchAgent setEnabled:YES 的测试二进制
sleep 1
AFTER=$(ps -axo command | grep '[O]neVerifyCode' | wc -l | tr -d ' ')
echo "before=$BEFORE after_enable=$AFTER"
# before=1 after_enable=1
```

开启后进程数保持 1；随后调用 `setEnabled:NO`，plist 已删除。

### S16.2 外观页配色勾选反向

**现象**：选中配色卡右上角的白勾呈“∧”形，像倒过来的勾。

**根因**：`OVCThemeSwatchView` 手绘勾选路径的三个控制点纵向顺序写反，第二点高于起点、第三点又落下，形成倒 V。

**修复**：`src/OVCSettingsWindow.m` 调整折线为“起点 → 下方 → 右上”，形成正确 `✓`。

**验证**：重新执行

```bash
./build/OneVerifyCode --render-previews build/preview
```

`build/preview/settings-appearance-light.png` 中选中“极光蓝”的勾已为正向。

### S16.3 回归

```bash
make test
# 39/39 提取规则 + 7/7 历史摘要 = 46/46

make app
# built build/stage/一码.app
```


---

## S17 v0.4.1 新增纯白 / 纯黑主题

### S17.1 主题模型

**目的**：在外观页原有 5 套配色之外增加纯白、纯黑两套高对比主题，并保证文字颜色与底色始终匹配。

**修改**：

- `src/OVCTheme.h`：`OVCPanelTheme` 增加 `OVCPanelThemePureWhite`、`OVCPanelThemePureBlack`，`OVCPanelThemeCount` 变为 7。
- `src/OVCTheme.m`：
  - 名称分别为「纯白」「纯黑」。
  - 纯白：渐变起止均为 `#FFFFFF`，主文字 `#111318`，次文字 `#5F6368`，强调色 `#111318`，高光 `#E5E7EB`。
  - 纯黑：渐变起止均为 `#000000`，主文字 `#FFFFFF`，次文字 `#A1A1A6`，强调色 `#FFFFFF`，高光 `#3A3A3C`。
  - 两套主题的 light/dark 解析值相同，避免纯白在深色系统下变成黑字白底反转、纯黑在浅色系统下丢失对比。
- `src/OVCPanelController.m`、`src/OVCSettingsWindow.m`：纯白/纯黑不叠加主题柔光，保持纯色底；两套主题强制 `opacity=1.0`，避免深色系统把纯白染灰、浅色系统把纯黑提亮；外观页在选中这两套主题时禁用透明度滑杆并显示“不透明”。

### S17.2 外观页与勾选

- 配色卡布局从 5 列改为 7 列（左右各留 2pt，间距 7，每卡约 72pt），避免边缘描边被裁切。
- 色卡渐变增加 0.7px 描边，纯白卡在浅色面板上仍有边界。
- 勾选圆点底色使用主题强调色，勾线改用主题渐变起始色；纯黑主题的白色圆点上显示深色勾，不再出现“白底白勾”。
- `src/OVCRenderDump.m` 主题名增加 `white`、`black`，浅色/深色均渲染全部 7 套。
- `src/OVCPrefs.m`：原先把 `panelTheme` 硬限制在 `0...4`，新增主题在重启后会回退为石墨灰；改为按 `OVCPanelThemeCount - 1` 限制。

**验证**：使用 `-panelTheme 6 -panelTransparency 0` 渲染外观页，纯黑卡正确选中、勾选为白圆黑勾、预览为纯黑底白字、透明度显示“不透明”；`-panelTheme 5` 时纯白卡为白底深字。

### S17.3 版本与回归

```bash
make app
make test
./build/OneVerifyCode --render-previews build/preview
```

**结果**：

- `make app` 成功，`build/stage/一码.app` 为 0.4.1。
- `make test`：39/39 提取 + 7/7 历史摘要 = 46/46 通过。
- 预览：`panel-white-light.png`、`panel-white-dark.png`、`panel-black-light.png`、`panel-black-dark.png` 及外观页浅色/深色均生成。
- 外观页 7 个色卡无溢出；纯白/纯黑文字与底色对比正常。

### S17.4 打包与负载校验

```bash
make pkg
make dmg
ROOT=$(mktemp -d /tmp/ovc-pkg-041-final.XXXXXX)
pkgutil --expand-full dist/OneVerifyCode-0.4.1.pkg "$ROOT/pkg"
# 检查 Payload/Applications/一码.app 的 Info.plist、架构与签名
hdiutil attach -nobrowse -readonly dist/OneVerifyCode-0.4.1.dmg
```

**结果**：

- `dist/OneVerifyCode-0.4.1.pkg` 约 623 KB，`dist/OneVerifyCode-0.4.1.dmg` 约 906 KB。
- pkg payload：`CFBundleShortVersionString=0.4.1`、`CFBundleVersion=5`、`LSUIElement=true`。
- 可执行文件为 Universal：x86_64 + arm64。
- `codesign --verify --deep --strict` 通过。
- dmg 内含 `一码.app` 与 `Applications -> /Applications`。
- 最终产物已发布为 `dist/OneVerifyCode-0.4.1.pkg`、`dist/OneVerifyCode-0.4.1.dmg`。

---

## S18 v0.4.2 修复开机自启未加入系统登录项

### S18.1 现象与根因

**现象**：在设置里打开“开机启动”后，`系统设置 → 通用 → 登录项` 中看不到“一码”。

**根因**：0.4.0/0.4.1 使用 `~/Library/LaunchAgents/com.oneverifycode.app.plist` + `launchctl enable` 实现自启。旧式 LaunchAgent 不是主 App 登录项，不会作为应用出现在现代 macOS 的“登录项”列表中，因此用户看不到可管理的条目。

### S18.2 改用 SMAppService

**修改**：

- `src/OVCLaunchAgent.m`：
  - 开启：`[SMAppService mainAppService]` 调用 `registerAndReturnError:`，主 App 注册为系统登录项。
  - 关闭：调用 `unregisterAndReturnError:`；主 App 注销后当前进程继续运行，不执行 `bootout`。
  - `SMAppServiceStatusRequiresApproval` 视为已登记，由调用方提示用户去系统设置批准。
  - 注册成功后删除旧 `~/Library/LaunchAgents/com.oneverifycode.app.plist`，避免升级后两套自启并存。
  - `isEnabled` 优先读取 `SMAppServiceStatusEnabled`，并保留旧 plist 判断用于升级迁移。
- `src/OVCAppDelegate.m`：
  - 已安装到 `/Applications` 且偏好为开启时，启动后自动迁移旧 LaunchAgent 到 SMAppService；开发构建不注册，避免污染系统登录项。
  - `requiresApproval` 时提示“已加入登录项，请在系统设置中允许一码”。
- `Makefile`：链接 `-framework ServiceManagement`。
- `README.md`、`docs/01-tech-plan.md`、`docs/03-api-contract.md` 同步更新开机自启实现与错误码说明。

### S18.3 注册/注销验证

使用临时诊断入口（验证后已从 `src/main.m` 删除，最终二进制无该参数）：

```bash
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --login-item-test
```

实际输出：

```text
before enabled=0 approval=0
register=1 error=none enabled=1 approval=0
unregister=1 error=none enabled=0 approval=0
```

结果：

- 注册返回 `1`，随后 `SMAppService` 状态为 `Enabled`。
- 注销返回 `1`，随后状态恢复为未启用。
- 测试前/后均无旧 LaunchAgent plist 残留。
- 注册测试使用 ad-hoc 签名的 `build/stage/一码.app`，macOS 15.8.3 未报 `kSMErrorInvalidSignature`。
- 验证边界：本轮以 `SMAppService` 状态和注册/注销返回值确认，未在系统设置界面补拍截图。

### S18.4 版本、测试与打包

```bash
make app
make test
make pkg
make dmg
```

**结果**：

- `make app` 成功，`build/stage/一码.app` 为 0.4.2。
- `make test`：39/39 提取 + 7/7 历史摘要 = 46/46 通过。
- `dist/OneVerifyCode-0.4.2.pkg` 约 623 KB；`dist/OneVerifyCode-0.4.2.dmg` 约 905 KB。
- pkg payload：`CFBundleShortVersionString=0.4.2`、`CFBundleVersion=6`、`LSUIElement=true`。
- 可执行文件 Universal：x86_64 + arm64；已链接 `ServiceManagement.framework`。
- `codesign --verify --deep --strict` 通过。
- dmg 内含 `一码.app` 与 `Applications -> /Applications`。
- 最终产物已发布为 `dist/OneVerifyCode-0.4.2.pkg`、`dist/OneVerifyCode-0.4.2.dmg`。


## S19 v0.5.0 全局中英文切换

### 目的

让界面语言不再依赖系统语言：新增“跟随系统 / 中文 / English”运行时切换，并覆盖菜单、六个设置页、悬浮卡片、提示框、错误和状态文案。同时为 GitHub 准备英文默认 README 与中文完整 README。

### 实现

- 新增 `src/OVCLocalization.h/.m`：
  - `OVCStr()` 以中文源文案为 key，英文模式查 `en.lproj/Localizable.strings`，中文模式直接返回源文案。
  - `OVCResolvedLanguageCode()` 按 `appLanguage`（0 跟随系统 / 1 中文 / 2 English）解析。
  - `OVCLanguageDidChangeNotification` 通知 UI 刷新。
- `OVCPrefs` 新增 `appLanguage`，默认 0，越界夹紧为 0–2。
- 设置侧栏底部新增“界面语言”`NSPopUpButton`，选项为“跟随系统 / 中文 / English”。
- `OVCSettingsWindow` 新增 `reloadLocalization`：切换后重建 `OVCSettingsView`，保留当前 section、状态、权限与历史数据。
- `OVCAppDelegate` 观察语言通知，关闭悬浮卡片，异步重建设置页并刷新菜单/状态。
- 菜单、设置页、悬浮卡片、状态文案、提示框、错误信息统一改为 `OVCStr(@"…")`。
- 英文资源：`assets/en.lproj/Localizable.strings`；`tools/check_l10n.py` 校验 key 覆盖与格式占位符。
- `Makefile`：将 `en.lproj` 复制进 App Resources；`make test` 依赖 `l10n-check`。
- 英文布局修正：
  - 侧栏 App 名改用较小字号并加宽，避免 “OneVerifyCode” 截断。
  - “Background transparency” 标签加宽。
  - 权限页改用 “Read-only database” / “No codes in logs”。
  - 行为页改用 “Auto-dismiss when the bar ends”。
  - 识别页改用 “Numeric or alphanumeric codes only”。
  - 状态胶囊补 “Monitoring · 3 today” / “0 today” 英文 key。
- 文档：
  - `README.md` 英文默认入口。
  - `README.zh-CN.md` 中文完整版，两边互相链接。
  - `docs/images/` 放入中英文外观/行为/弹窗截图。
  - 新增 `.gitignore`，忽略 `build/`、`dist/`、`tools/icongen` 等生成物。

### 验证

```bash
make test
make l10n-check
python3 tools/check_l10n.py
```

实际结果：

```text
结果：39/39 通过，0 失败
结果：7/7 通过，0 失败
l10n: 163 keys, 167 translations, 0 missing, 0 format mismatch
```

运行时预览使用 App bundle 内的 `en.lproj`，而不是顶层 `build/OneVerifyCode`：

```bash
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --render-previews /tmp/ovc-doc-en -appLanguage 2
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --render-previews /tmp/ovc-doc-zh -appLanguage 1
```

两套预览均成功，截图保存到：

- `docs/images/settings-appearance-en.png`
- `docs/images/settings-behavior-en.png`
- `docs/images/panel-aurora-en.png`
- `docs/images/settings-appearance-zh.png`
- `docs/images/settings-behavior-zh.png`
- `docs/images/panel-aurora-zh.png`

逐页检查了英文设置页，修复上述截断并复查通过。

### 验证边界

本机桌面会话此前锁屏，语言 PopUp 的真实点击切换与切换后菜单刷新未做人工窗口走查；已通过 `-appLanguage 1/2` 离屏渲染验证资源加载和英文布局。设置页 `reloadLocalization` 的重建路径已通过编译，但仍建议在桌面解锁后补一次真实点击回归。

## S20 v0.5.0 安装包构建与校验

### 命令

```bash
make pkg
make dmg
```

### 结果

- `dist/OneVerifyCode-0.5.0.pkg` 约 638 KB。
- `dist/OneVerifyCode-0.5.0.dmg` 约 927 KB。
- pkg payload 解包检查：
  - `CFBundleShortVersionString=0.5.0`
  - `CFBundleVersion=7`
  - `LSUIElement=true`
  - `Contents/Resources/en.lproj/Localizable.strings` 存在
  - 可执行文件为 Universal：`x86_64` + `arm64`
  - `codesign --verify --deep --strict` 通过
- dmg 挂载检查：
  - 包含 `一码.app`
  - 包含 `Applications -> /Applications`
  - App 版本为 0.5.0

### 产物

- `dist/OneVerifyCode-0.5.0.pkg`
- `dist/OneVerifyCode-0.5.0.dmg`
- 两个安装包与中英文 README 已通过 `artifact_publish` 发布。

### 验证边界

未覆盖安装到 `/Applications`，因此没有触发真实 TCC 重新授权；本机 `/Applications/一码.app` 仍可能是旧版本。安装包本身已完成 payload、架构、签名和挂载校验。


## S21 采用 MIT 许可证

### 目的

为 GitHub 公开发布补齐明确授权，避免“公开代码但未授予使用许可”的歧义。

### 命令

```bash
cd /Users/sheng/.sclaw/workspace/projects/OneVerifyCode
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 shyuu
...
EOF
```

### 实际结果

- 新增 `LICENSE`，正文为标准 MIT 许可证。
- 版权行：`Copyright (c) 2026 shyuu`。
- `README.md` 的 License 章节改为 MIT，并链接 `LICENSE`。
- `README.zh-CN.md` 的“许可证”章节改为 MIT，并链接 `LICENSE`。
- 仅修改文档与许可证，不涉及源码，不需要重新构建 App 或安装包。

### 产物

- `LICENSE`
- `README.md`
- `README.zh-CN.md`


## S22 v0.5.1 权限页操作按钮重做

### 目的

权限页的“打开系统设置”按钮此前直接复用原生 `NSButton`，在 172pt 高的卡片内被拉到整卡宽度，形成两条厚重的蓝色横条；授权完成后又显示为左对齐的禁用按钮，视觉上像坏掉的控件。英文徽标还因固定 70pt 宽度被截断。

### 实现

- 新增 `OVCPillButton`：28pt 高、`OVCRadiusButton` 圆角、宽度按文字自适应，带右上箭头；支持 hover、按下、禁用和键盘焦点遮罩。
- 权限卡 CTA 不再拉满卡片：宽度取文字宽度与 120pt 的较大值，最大不超过卡片内宽。
- 已授权时隐藏 CTA，改为 12pt 绿色勾选 + “无需操作”状态行，避免伪禁用按钮。
- 徽标 `OVCBadgeView` 增加 `preferredWidth`，按文案动态取宽，修复英文 “Needs permission” 截断。
- 英文状态胶囊 `Permission needed: Full Disk Access` 缩短为 `Full Disk Access needed`，避免顶部截断。
- 版本升级到 0.5.1，`CFBundleVersion=8`。

### 验证

```bash
make app
make test
make l10n-check
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --render-previews <en-dir> -appLanguage 2
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --render-previews <zh-dir> -appLanguage 1
make pkg
make dmg
```

实际结果：

- 提取测试 39/39，历史测试 7/7。
- 本地化：`l10n: 163 keys, 168 translations, 0 missing, 0 format mismatch`。
- 中英文、明暗权限页预览均成功；新增 `settings-permission-needed-dark.png` 预览用于暗色检查。
- pkg payload：`CFBundleShortVersionString=0.5.1`、`CFBundleVersion=8`、`LSUIElement=true`。
- Universal：`x86_64` + `arm64`；`en.lproj/Localizable.strings` 存在；`codesign --verify --deep --strict` 通过。
- dmg 内含 `一码.app` 与 `Applications -> /Applications`，App 版本 0.5.1。

### 产物

- `dist/OneVerifyCode-0.5.1.pkg`
- `dist/OneVerifyCode-0.5.1.dmg`
- `docs/images/settings-appearance-{en,zh}.png`
- `docs/images/settings-behavior-{en,zh}.png`
- `docs/images/panel-aurora-{en,zh}.png`

### 验证边界

本轮通过离屏渲染检查布局、颜色与中英文长度；尚未在真实窗口中点击 CTA、验证 hover/焦点环，也未覆盖安装到 `/Applications`。需在桌面会话可用时补一次真实点击回归。


## S23 v0.5.2 窗口拖拽、关于页与 DMG 说明

### 目的

- 设置窗口此前 `movableByWindowBackground=YES`，在右侧内容区拖动也会移动窗口。
- 关于页介绍需要替换为新的功能描述。
- 关于页底部需要从本地口号改为 GitHub 仓库入口，带 Logo 并可一键跳转。
- DMG 需要包含拖拽安装说明。

### 实现

- `OVCSettingsWindow` 的 `movableByWindowBackground` 改为 `NO`。
- 新增 `OVCSidebarDragView`：
  - 左侧整个空白区域一个透明拖拽层；
  - 顶部品牌/图标区域再覆盖一个仅 96pt 高的拖拽层，不遮挡导航和操作控件；
  - 右侧内容区不再响应窗口拖动。
- 关于页介绍改为：
  `读取 iPhone 转发到 Mac 的短信/信息，在本地提取验证码；可快速填入、复制到剪切板，数据不联网安全可靠。`
  - 中文在分号后换行，避免“复制”被拆开；
  - 英文翻译同步，最多 3 行。
- 新增 `OVCGitHubLinkView`：14pt GitHub mark + `GitHub · github.com/Yu-cre7/OneVerifyCode`，hover 变色、指针光标、点击打开仓库。
- `assets/GitHubMark.png` 打包进 `Contents/Resources`。
- DMG 增加 `安装说明.txt`，包含中英文拖拽安装、首次启动、TCC 权限与 quarantine 说明。
- 版本升级到 0.5.2，`CFBundleVersion=9`。

### 验证

```bash
make app
make test
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --render-previews <en-dir> -appLanguage 2
./build/stage/一码.app/Contents/MacOS/OneVerifyCode --render-previews <zh-dir> -appLanguage 1
make pkg
make dmg
```

实际结果：

- 提取测试 39/39，历史测试 7/7。
- 本地化：`l10n: 162 keys, 169 translations, 0 missing, 0 format mismatch`。
- 中英文关于页预览成功；
  - 中文介绍两行，未拆开“复制”；
  - 英文介绍两行；
  - GitHub 图标、仓库地址完整显示。
- pkg payload：`CFBundleShortVersionString=0.5.2`、`CFBundleVersion=9`、`LSUIElement=true`。
- Universal：`x86_64` + `arm64`；`GitHubMark.png` 存在；`codesign --verify --deep --strict` 通过。
- dmg 目录包含 `一码.app`、`Applications -> /Applications`、`安装说明.txt`。
- App 版本 0.5.2。

### 产物

- `dist/OneVerifyCode-0.5.2.pkg`
- `dist/OneVerifyCode-0.5.2.dmg`
- `assets/GitHubMark.png`
- `assets/dmg-install.txt`
- `docs/images/settings-appearance-{en,zh}.png`
- `docs/images/settings-behavior-{en,zh}.png`
- `docs/images/panel-aurora-{en,zh}.png`

### 验证边界

本轮通过离屏渲染检查关于页布局和中英文长度。窗口左侧拖拽、GitHub 点击未在真实窗口中操作验证；代码路径已编译，建议桌面会话可用时补一次拖拽和点击回归。仓库地址按 `https://github.com/Yu-cre7/OneVerifyCode` 配置；如实际仓库名不同，修改 `OVCGitHubRepositoryURL` 即可。


---

## S24 v0.5.3 GitHub 发布整改、0–100% 透明度与 README 截图

**目标**：在首次上传 GitHub 前完成仓库层面的可用性、展示和合规检查，同时落实真实仓库地址、透明度和项目目录改名。

### 改动

- 仓库根目录从 `projects/easy-verify-code` 统一为 `projects/OneVerifyCode`；执行日志中的旧路径同步更新。
- 应用内 GitHub 入口与两份 README 的 clone 地址统一为 `https://github.com/Yu-cre7/OneVerifyCode.git`。
- 悬浮卡片背景透明度从 0–40% 放宽为 0–100%：
  - `OVCPrefs` 的 clamp 改为 `0.0–1.0`；
  - 设置页 slider 的 `maxValue` 改为 100；
  - 设计文档更新为 0–100%；
  - 持久化契约补充 `panelTheme`、`panelSize`、`panelTransparency`。
- README 顶部增加 release、macOS 13+、MIT、CI 四个 badge，以及唯一的“Download latest release”快捷入口；没有添加无实际目标的按钮。
- README 新增“Screens”/“界面”章节：
  - `docs/images/settings-records-{en,zh}.png`
  - `docs/images/menu-{en,zh}.png`
- 重新生成 0.5.3 的中英文外观、行为、记录页和悬浮卡片截图；截图中的版本显示为 0.5.3。
- 新增仓库规范文件：
  - `SECURITY.md`、`PRIVACY.md`、`CONTRIBUTING.md`、`CODE_OF_CONDUCT.md`、`CHANGELOG.md`；
  - `.github/ISSUE_TEMPLATE/bug_report.yml`、`feature_request.yml`、`config.yml`；
  - `.github/pull_request_template.md`；
  - `.github/workflows/ci.yml`（`make test`，push/PR 均触发）；
  - `.editorconfig`、`.gitattributes`。
- 测试二进制改为当前机器原生架构编译，避免 Apple silicon 上必须依赖 Rosetta 才能执行 `make test`。
- 为菜单预览示例字符串补齐英文翻译；本地化校验从 162 keys 增至 163 keys。
- 同步清理技术文档：`docs/01-tech-plan.md` 版本改为 0.5.3，需求 R7 改为六页设置，R10 与打包命令改为 0.5.3。
- 删除根目录 `.DS_Store`；`.gitignore` 继续排除 `build/`、`dist/`、`tools/icongen`。
- 记录页和菜单截图使用现有离屏渲染/真实 `NSMenu` 预览能力生成，不引入网络图片或外部 CDN。

### 验证

- 提取测试：39/39 通过。
- 历史测试：7/7 通过。
- 本地化：163 keys / 170 translations，0 missing，0 format mismatch。
- `make app` 成功；`build/stage/一码.app` 为 `0.5.3`，`CFBundleVersion=10`，`LSUIElement=true`。
- `lipo -info`：`x86_64 arm64`。
- `codesign --verify --deep --strict`：通过；签名类型为 ad-hoc。
- pkg payload：`0.5.3`、build `10`、`LSUIElement=true`、双架构、`GitHubMark.png` 存在、签名通过。
- dmg：包含 `一码.app`、`Applications -> /Applications`、`安装说明.txt`；App 版本 `0.5.3`。
- YAML issue forms、PR 模板与 CI workflow 均通过 Ruby YAML 解析。
- 产物：
  - `dist/OneVerifyCode-0.5.3.pkg`（653 KB）
  - `dist/OneVerifyCode-0.5.3.dmg`（936 KB）
- SHA-256：
  - pkg `6c9c767173acbb5c10bdc78ce290366138c0d59da7092f803af3f78c652ea3ec`
  - dmg `0222deec6b50a13482187914c1511f6eb718fce36d32ce288f9e8d5b216e95e8`

### 验证边界

- 仓库尚未实际 push，GitHub Actions、release badge 和 issue forms 的线上渲染需在上传后确认。
- 菜单截图来自 `--preview-menu` 弹出的真实 `NSMenu`，不是状态栏图标上下文截图；因当前菜单栏空间不足，系统会把状态项移到屏幕外。
- 真实窗口拖拽、GitHub 链接点击、100% 透明度在真实桌面会话中的视觉表现仍未手动回归。
- `LICENSE` 版权署名仍为 `shyuu`；仓库所有者为 `Yu-cre7`，是否统一署名需作者确认。

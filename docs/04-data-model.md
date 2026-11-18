# 一码 OneVerifyCode · 数据模型

本应用无自有服务端数据库，数据分为三类：只读的外部短信库、本地偏好、本地历史文件。

## 1. 外部数据源：`~/Library/Messages/chat.db`（只读）

只依赖以下字段，均为 macOS 长期稳定列：

### 1.1 message（使用列）

| 列 | 类型 | 说明 |
| --- | --- | --- |
| `ROWID` | INTEGER | 自增游标，用于增量拉取 |
| `guid` | TEXT | 全局唯一消息 ID，用于去重 |
| `text` | TEXT | 明文正文，可能为 NULL |
| `attributedBody` | BLOB | 富文本 typedstream，正文兜底来源 |
| `handle_id` | INTEGER | 发送方外键 |
| `date` | INTEGER | 自 2001-01-01 起的纳秒（新版）或秒（旧版） |
| `is_from_me` | INTEGER | 1 表示自己发出，需过滤 |
| `service` | TEXT | `SMS` / `iMessage` |
| `is_system_message` | INTEGER | 系统提示，需过滤 |

### 1.2 handle

| 列 | 类型 | 说明 |
| --- | --- | --- |
| `ROWID` | INTEGER | 主键 |
| `id` | TEXT | 手机号或 Apple ID，展示前脱敏 |

### 1.3 查询

```sql
SELECT m.ROWID, m.guid, m.text, m.attributedBody, m.date,
       m.is_from_me, m.service, h.id
FROM message m
LEFT JOIN handle h ON h.ROWID = m.handle_id
WHERE m.ROWID > ? AND m.is_from_me = 0 AND m.is_system_message = 0
ORDER BY m.ROWID ASC
LIMIT ?;
```

索引：`message` 表自带 `ROWID` 主键，按 ROWID 范围扫描即可，无需自建索引（不能对系统库建索引）。

## 2. 本地偏好（NSUserDefaults）

见 `03-api-contract.md` 第 4 节。语义约束：

- `minDigits ∈ [4,6]`，`maxDigits ∈ [6,8]`，且 `minDigits ≤ maxDigits`；越界自动纠正为默认 4/8 并记录 1001。
- `panelDuration ∈ [1,20]`，越界夹紧。
- `appLanguage ∈ [0,2]`，默认 0（跟随系统）；1 为中文，2 为英文。
- 所有读取走 `OVCPrefs`，禁止业务代码直接读 `NSUserDefaults`。

## 3. 本地历史文件

路径：`~/Library/Application Support/OneVerifyCode/history.json`

```json
{
  "version": 1,
  "items": [
    {
      "code": "482913",
      "sender": "1069****01",
      "date": 1763370000.0,
      "guid": "A1B2C3D4-...."
    }
  ]
}
```

字段：

| 字段 | 类型 | 可空 | 说明 |
| --- | --- | --- | --- |
| `code` | string | 否 | 验证码原文 |
| `sender` | string | 是 | 脱敏后的发送方 |
| `date` | number | 否 | Unix 秒（double） |
| `guid` | string | 是 | 短信 guid，用于跨重启去重 |

规则：

- 上限 50 条，超出按时间淘汰最旧。
- 不写入短信正文，避免隐私扩散。
- 文件权限 `0600`。
- 解析失败：备份为 `history.corrupt-<ts>.json` 后重建，错误码 5003。

## 4. 内存模型

```objc
@interface OVCCode : NSObject
@property (copy)   NSString *code;
@property (copy)   NSString *keyword;
@property (assign) NSRange   range;
@end

@interface OVCMessage : NSObject
@property (assign) int64_t  rowid;
@property (copy)   NSString *guid;
@property (copy)   NSString *text;
@property (copy)   NSString *sender;
@property (copy)   NSString *service;
@property (assign) NSTimeInterval date;
@property (assign) BOOL isFromMe;
@end

@interface OVCHistoryItem : NSObject
@property (copy)   NSString *code;
@property (copy)   NSString *sender;
@property (assign) NSTimeInterval date;
@property (copy)   NSString *guid;
@end
```

## 5. 状态机

```
启动
 ├─ 无完全磁盘访问 ──> 状态: 需要授权（菜单红点，设置页横幅）
 └─ 有权限
     ├─ 打开失败 ────> 状态: 短信库不可读（可重试）
     └─ 打开成功 ───> 监听中
                       ├─ 收到消息 ─> 提取成功 ─> 复制 + 弹窗 ─> 监听中
                       ├─ 收到消息 ─> 未命中 ───> 监听中（静默）
                       └─ 用户暂停 ─> 已暂停 ─> 恢复
```

## 6. 迁移

- v0.3.0 为首个可用版本，无历史迁移。
- 预留：历史文件 `version: 2` 可增加 `sourceApp` 字段，读取时缺省即可。
- 偏好新增键一律给默认值，不做一次性迁移脚本。

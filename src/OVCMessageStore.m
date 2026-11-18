#import "OVCMessageStore.h"
#import "OVCLocalization.h"
#import "OVCTextDecoder.h"
#import <sqlite3.h>

NSString * const OVCErrorDomain = @"com.oneverifycode.error";
const NSInteger OVCErrorNoFullDiskAccess = 2001;
const NSInteger OVCErrorDatabaseMissing = 4001;
const NSInteger OVCErrorDatabaseUnreadable = 4002;

@implementation OVCMessage

- (NSString *)description {
    return [NSString stringWithFormat:@"<OVCMessage %lld %@>", (long long)_rowid, _sender ?: @"?"];
}

@end

@interface OVCMessageStore () {
    sqlite3 *_db;
}
@property (nonatomic, readwrite, nullable) NSError *lastError;
@end

@implementation OVCMessageStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _db = NULL;
    }
    return self;
}

- (void)dealloc {
    [self close];
}

- (NSString *)databasePath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Messages/chat.db"];
}

- (BOOL)isOpen { return _db != NULL; }

- (BOOL)openWithError:(NSError **)error {
    if (_db) { return YES; }

    NSString *path = [self databasePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        self.lastError = [NSError errorWithDomain:OVCErrorDomain
                                             code:OVCErrorDatabaseMissing
                                         userInfo:@{NSLocalizedDescriptionKey: OVCStr(@"未找到短信数据库，请确认已在 iPhone 开启短信转发")}];
        if (error) { *error = self.lastError; }
        return NO;
    }

    sqlite3 *db = NULL;
    int rc = sqlite3_open_v2(path.fileSystemRepresentation, &db,
                             SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, NULL);
    if (rc != SQLITE_OK) {
        NSString *detail = db ? @(sqlite3_errmsg(db)) : @"unknown";
        if (db) { sqlite3_close(db); }

        NSInteger code = (rc == SQLITE_CANTOPEN) ? OVCErrorNoFullDiskAccess : OVCErrorDatabaseUnreadable;
        NSString *message = (code == OVCErrorNoFullDiskAccess)
            ? OVCStr(@"无法读取短信数据库，请在“完全磁盘访问”中允许一码")
            : [NSString stringWithFormat:OVCStr(@"短信数据库暂时不可读：%@"), detail];
        self.lastError = [NSError errorWithDomain:OVCErrorDomain
                                             code:code
                                         userInfo:@{NSLocalizedDescriptionKey: message,
                                                    NSLocalizedFailureReasonErrorKey: detail}];
        if (error) { *error = self.lastError; }
        return NO;
    }

    sqlite3_busy_timeout(db, 1500);
    sqlite3_exec(db, "PRAGMA query_only=ON;", NULL, NULL, NULL);
    _db = db;
    self.lastError = nil;
    return YES;
}

- (void)close {
    if (_db) {
        sqlite3_close(_db);
        _db = NULL;
    }
}

- (int64_t)currentMaxRowID {
    if (![self openWithError:NULL]) { return 0; }
    sqlite3_stmt *stmt = NULL;
    int64_t result = 0;
    if (sqlite3_prepare_v2(_db, "SELECT IFNULL(MAX(ROWID), 0) FROM message;", -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            result = sqlite3_column_int64(stmt, 0);
        }
    }
    sqlite3_finalize(stmt);
    return result;
}

static NSTimeInterval OVCUnixDateFromApple(int64_t raw) {
    if (raw <= 0) { return 0; }
    if (raw > 100000000000LL) {          // 纳秒（macOS 10.13+）
        return (double)raw / 1000000000.0 + 978307200.0;
    }
    return (double)raw + 978307200.0;    // 秒
}

- (NSArray<OVCMessage *> *)fetchWithQuery:(const char *)sql rowid:(int64_t)rowid limit:(NSInteger)limit {
    if (![self openWithError:NULL]) { return @[]; }

    sqlite3_stmt *stmt = NULL;
    NSMutableArray<OVCMessage *> *messages = [NSMutableArray array];
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        self.lastError = [NSError errorWithDomain:OVCErrorDomain
                                             code:OVCErrorDatabaseUnreadable
                                         userInfo:@{NSLocalizedDescriptionKey: OVCStr(@"短信数据库查询失败")}];
        return @[];
    }
    sqlite3_bind_int64(stmt, 1, rowid);
    sqlite3_bind_int(stmt, 2, (int)limit);

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        OVCMessage *message = [OVCMessage new];
        message.rowid = sqlite3_column_int64(stmt, 0);
        const unsigned char *guidText = sqlite3_column_text(stmt, 1);
        message.guid = guidText ? @((const char *)guidText) : @"";

        NSString *text = nil;
        if (sqlite3_column_type(stmt, 2) != SQLITE_NULL) {
            const unsigned char *textBytes = sqlite3_column_text(stmt, 2);
            if (textBytes) { text = @((const char *)textBytes); }
        }
        if (text.length == 0 && sqlite3_column_type(stmt, 3) != SQLITE_NULL) {
            const void *blob = sqlite3_column_blob(stmt, 3);
            int blobBytes = sqlite3_column_bytes(stmt, 3);
            if (blob && blobBytes > 0) {
                NSData *data = [NSData dataWithBytes:blob length:(NSUInteger)blobBytes];
                text = [OVCTextDecoder plainTextFromAttributedBody:data];
            }
        }
        message.text = text ?: @"";
        message.date = OVCUnixDateFromApple(sqlite3_column_int64(stmt, 4));
        message.isFromMe = sqlite3_column_int(stmt, 5) != 0;
        const unsigned char *service = sqlite3_column_text(stmt, 6);
        message.service = service ? @((const char *)service) : nil;
        const unsigned char *sender = sqlite3_column_text(stmt, 7);
        message.sender = sender ? @((const char *)sender) : nil;
        [messages addObject:message];
    }
    sqlite3_finalize(stmt);
    return messages;
}

- (NSArray<OVCMessage *> *)fetchAfterRowID:(int64_t)rowid limit:(NSInteger)limit {
    static const char *sql =
        "SELECT m.ROWID, m.guid, m.text, m.attributedBody, m.date, m.is_from_me, m.service, h.id "
        "FROM message m LEFT JOIN handle h ON h.ROWID = m.handle_id "
        "WHERE m.ROWID > ? AND m.is_from_me = 0 AND m.is_system_message = 0 "
        "ORDER BY m.ROWID ASC LIMIT ?;";
    return [self fetchWithQuery:sql rowid:rowid limit:limit];
}

- (NSArray<OVCMessage *> *)fetchSinceDate:(NSDate *)date limit:(NSInteger)limit {
    static const char *sql =
        "SELECT m.ROWID, m.guid, m.text, m.attributedBody, m.date, m.is_from_me, m.service, h.id "
        "FROM message m LEFT JOIN handle h ON h.ROWID = m.handle_id "
        "WHERE m.date > ? AND m.is_from_me = 0 AND m.is_system_message = 0 "
        "ORDER BY m.ROWID DESC LIMIT ?;";
    int64_t appleNanos = (int64_t)((date.timeIntervalSince1970 - 978307200.0) * 1000000000.0);
    return [self fetchWithQuery:sql rowid:appleNanos limit:limit];
}

+ (NSString *)maskedSender:(NSString *)sender {
    if (sender.length == 0) { return OVCStr(@"未知来源"); }

    if ([sender containsString:@"@"]) {
        NSArray<NSString *> *parts = [sender componentsSeparatedByString:@"@"];
        NSString *name = parts.firstObject;
        NSString *domain = parts.count > 1 ? parts[1] : @"";
        NSString *head = name.length > 2 ? [name substringToIndex:2] : name;
        return [NSString stringWithFormat:@"%@@%@", head, domain];
    }

    NSString *digits = sender;
    if ([digits hasPrefix:@"+86"]) { digits = [digits substringFromIndex:3]; }
    NSMutableString *compact = [NSMutableString string];
    for (NSUInteger i = 0; i < digits.length; i++) {
        unichar c = [digits characterAtIndex:i];
        if (c >= '0' && c <= '9') { [compact appendFormat:@"%C", c]; }
    }
    if (compact.length >= 8) {
        return [NSString stringWithFormat:@"%@****%@",
                [compact substringToIndex:4],
                [compact substringFromIndex:compact.length - 2]];
    }
    if (sender.length >= 4) {
        return [NSString stringWithFormat:@"%@***", [sender substringToIndex:2]];
    }
    return OVCStr(@"未知来源");
}

@end

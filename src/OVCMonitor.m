#import "OVCMonitor.h"
#import "OVCMessageStore.h"
#import "OVCPrefs.h"

@interface OVCMonitor ()
@property (nonatomic, strong) OVCMessageStore *store;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong, nullable) NSTimer *timer;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL hasBaseline;
@property (nonatomic, assign) int64_t lastRowID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *recentCodes;
@property (nonatomic, strong) NSMutableSet<NSString *> *seenGUIDs;
@property (nonatomic, strong, nullable) NSError *lastReportedError;
@property (nonatomic, assign) NSTimeInterval lastErrorReport;
@end

@implementation OVCMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        _store = [[OVCMessageStore alloc] init];
        _queue = dispatch_queue_create("com.oneverifycode.monitor", DISPATCH_QUEUE_SERIAL);
        _recentCodes = [NSMutableDictionary dictionary];
        _seenGUIDs = [NSMutableSet set];
    }
    return self;
}

- (BOOL)isRunning { return self.running; }

- (void)start {
    if (self.running) { return; }
    self.running = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timer invalidate];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.2
                                                     target:self
                                                   selector:@selector(poll)
                                                   userInfo:nil
                                                    repeats:YES];
        self.timer.tolerance = 0.3;
    });

    self.hasBaseline = NO;
}

- (void)stop {
    self.running = NO;
    [self.timer invalidate];
    self.timer = nil;
}

- (void)poll {
    if (!self.running) { return; }

    dispatch_async(self.queue, ^{
        if (!self.store.isOpen) {
            NSError *error = nil;
            if (![self.store openWithError:&error]) {
                [self reportStatus:error];
                return;
            }
        }

        // 首次成功打开（可能是用户刚刚授予完全磁盘访问）只建立基线，不回放历史短信。
        if (!self.hasBaseline) {
            self.lastRowID = [self.store currentMaxRowID];
            self.hasBaseline = YES;
            [self reportStatus:nil];
            return;
        }

        NSArray<OVCMessage *> *messages = [self.store fetchAfterRowID:self.lastRowID limit:60];
        if (messages.count == 0) { return; }

        NSError *storeError = self.store.lastError;
        if (storeError) {
            [self reportStatus:storeError];
            return;
        }
        [self reportStatus:nil];

        self.lastRowID = messages.lastObject.rowid;
        OVCPrefs *prefs = [OVCPrefs shared];
        OVCExtractOptions options = OVCExtractOptionsDefault();
        options.minDigits = prefs.minDigits;
        options.maxDigits = prefs.maxDigits;
        options.requiresKeyword = prefs.requiresKeyword;

        for (OVCMessage *message in messages) {
            if (message.guid.length > 0) {
                @synchronized(self.seenGUIDs) {
                    if ([self.seenGUIDs containsObject:message.guid]) { continue; }
                    [self.seenGUIDs addObject:message.guid];
                    if (self.seenGUIDs.count > 500) {
                        NSString *first = self.seenGUIDs.anyObject;
                        if (first) { [self.seenGUIDs removeObject:first]; }
                    }
                }
            }
            if (message.text.length == 0) { continue; }

            OVCCode *code = [OVCCodeExtractor extractFromText:message.text options:options];
            if (!code) { continue; }

            @synchronized(self.recentCodes) {
                NSDate *last = self.recentCodes[code.code];
                if (last && -[last timeIntervalSinceNow] < 90.0) {
                    continue;
                }
                self.recentCodes[code.code] = [NSDate date];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.onCode) { self.onCode(code, message); }
            });
        }
    });
}

- (void)reportStatus:(NSError *)error {
    if (error == nil) {
        self.lastReportedError = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onStatusChange) { self.onStatusChange(nil); }
        });
        return;
    }

    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if (self.lastReportedError.code == error.code && (now - self.lastErrorReport) < 15.0) {
        return;
    }
    self.lastReportedError = error;
    self.lastErrorReport = now;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onStatusChange) { self.onStatusChange(error); }
    });
}

- (NSArray<OVCCode *> *)scanLastHours:(NSInteger)hours messages:(NSArray<OVCMessage *> *__autoreleasing *)messages {
    NSInteger clamped = MIN(72, MAX(1, hours));
    NSDate *since = [NSDate dateWithTimeIntervalSinceNow:-clamped * 3600.0];

    __block NSArray<OVCMessage *> *fetched = @[];
    dispatch_sync(self.queue, ^{
        if (!self.store.isOpen) { [self.store openWithError:NULL]; }
        fetched = [self.store fetchSinceDate:since limit:300];
    });
    if (messages) { *messages = fetched; }

    OVCPrefs *prefs = [OVCPrefs shared];
    OVCExtractOptions options = OVCExtractOptionsDefault();
    options.minDigits = prefs.minDigits;
    options.maxDigits = prefs.maxDigits;
    options.requiresKeyword = prefs.requiresKeyword;

    NSMutableArray<OVCCode *> *results = [NSMutableArray array];
    for (OVCMessage *message in fetched) {
        if (message.text.length == 0) { continue; }
        OVCCode *code = [OVCCodeExtractor extractFromText:message.text options:options];
        if (code) { [results addObject:code]; }
    }
    return results;
}

@end

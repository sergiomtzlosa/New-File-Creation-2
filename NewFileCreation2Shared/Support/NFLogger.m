#import "NFLogger.h"
#import "NFPaths.h"

static const unsigned long long NFLoggerMaxBytes = 1024 * 1024;

@implementation NFLogger

+ (instancetype)sharedLogger {
    static NFLogger *logger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[self alloc] init];
    });
    return logger;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *env = NSProcessInfo.processInfo.environment[@"NFC_LOG_LEVEL"];
        if ([env.lowercaseString isEqualToString:@"debug"]) {
            _level = NFLogLevelDebug;
        } else if ([env.lowercaseString isEqualToString:@"error"]) {
            _level = NFLogLevelError;
        } else {
            _level = NFLogLevelInfo;
        }
    }
    return self;
}

- (void)log:(NFLogLevel)level format:(NSString *)format, ... {
    if (level > self.level) {
        return;
    }
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });

    NSString *levelName = level == NFLogLevelError ? @"ERROR" : (level == NFLogLevelDebug ? @"DEBUG" : @"INFO");
    NSString *line = [NSString stringWithFormat:@"%@ [%@] %@\n", [formatter stringFromDate:[NSDate date]], levelName, message];

    @synchronized (self) {
        NSFileManager *fm = [NSFileManager defaultManager];
        [NFPaths ensureDirectory:[NFPaths logsDirectoryURL] error:nil];
        NSURL *logURL = [NFPaths logFileURL];

        NSDictionary *attributes = [fm attributesOfItemAtPath:logURL.path error:nil];
        if ([attributes[NSFileSize] unsignedLongLongValue] > NFLoggerMaxBytes) {
            NSURL *oldURL = [[logURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"log.1"];
            [fm removeItemAtURL:oldURL error:nil];
            [fm moveItemAtURL:logURL toURL:oldURL error:nil];
        }

        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (![fm fileExistsAtPath:logURL.path]) {
            [fm createFileAtPath:logURL.path contents:data attributes:nil];
            return;
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logURL.path];
        if (!handle) {
            return;
        }
        @try {
            [handle seekToEndOfFile];
            [handle writeData:data];
        } @catch (__unused NSException *exception) {
        } @finally {
            [handle closeFile];
        }
    }
}

- (void)error:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self log:NFLogLevelError format:@"%@", message];
}

- (void)info:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self log:NFLogLevelInfo format:@"%@", message];
}

- (void)debug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self log:NFLogLevelDebug format:@"%@", message];
}

- (NSString *)recentLogContentsWithLimit:(NSUInteger)limit {
    NSData *data = [NSData dataWithContentsOfURL:[NFPaths logFileURL]];
    if (!data) {
        return @"";
    }
    NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    NSArray<NSString *> *lines = [contents componentsSeparatedByString:@"\n"];
    if (lines.count <= limit) {
        return contents;
    }
    NSArray<NSString *> *tail = [lines subarrayWithRange:NSMakeRange(lines.count - limit, limit)];
    return [tail componentsJoinedByString:@"\n"];
}

@end

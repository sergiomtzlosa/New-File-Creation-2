#import "NFPaths.h"
#import "NFErrors.h"

static NSURL *NFSupportOverride = nil;

@implementation NFPaths

+ (NSURL *)supportDirectoryURL {
    NSString *env = NSProcessInfo.processInfo.environment[@"NFC_SUPPORT_DIR"];
    if (env.length > 0) {
        return [NSURL fileURLWithPath:env.stringByStandardizingPath isDirectory:YES];
    }
    if (NFSupportOverride) {
        return NFSupportOverride;
    }
    NSURL *base = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
    if (!base) {
        base = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"]
                          isDirectory:YES];
    }
    return [base URLByAppendingPathComponent:@"New File Creation 2" isDirectory:YES];
}

+ (void)setSupportDirectoryOverride:(NSURL *)url {
    NFSupportOverride = [url copy];
}

+ (NSURL *)configFileURL {
    return [[self supportDirectoryURL] URLByAppendingPathComponent:@"config.json" isDirectory:NO];
}

+ (NSURL *)templatesDirectoryURL {
    return [[self supportDirectoryURL] URLByAppendingPathComponent:@"Templates" isDirectory:YES];
}

+ (NSURL *)backupsDirectoryURL {
    return [[self supportDirectoryURL] URLByAppendingPathComponent:@"Backups" isDirectory:YES];
}

+ (NSURL *)logsDirectoryURL {
    return [[self supportDirectoryURL] URLByAppendingPathComponent:@"logs" isDirectory:YES];
}

+ (NSURL *)lockFileURL {
    return [[self supportDirectoryURL] URLByAppendingPathComponent:@"config.lock" isDirectory:NO];
}

+ (NSURL *)logFileURL {
    return [[self logsDirectoryURL] URLByAppendingPathComponent:@"nfc.log" isDirectory:NO];
}

+ (NSURL *)bundledTemplatesDirectoryURL {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSURL *> *candidates = [NSMutableArray array];

    NSURL *resourceURL = [NSBundle mainBundle].resourceURL;
    if (resourceURL) {
        [candidates addObject:[resourceURL URLByAppendingPathComponent:@"Templates" isDirectory:YES]];
    }

    NSString *executablePath = [NSBundle mainBundle].executableURL.path;
    if (executablePath.length > 0) {
        NSURL *executableURL = [NSURL fileURLWithPath:executablePath];
        [candidates addObject:[executableURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Templates" isDirectory:YES]];
        NSURL *contentsURL = executableURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent;
        if ([contentsURL.lastPathComponent isEqualToString:@"Contents"]) {
            [candidates addObject:[[contentsURL URLByAppendingPathComponent:@"Resources" isDirectory:YES]
                                   URLByAppendingPathComponent:@"Templates" isDirectory:YES]];
        }
    }

    NSURL *bundleURL = [NSBundle mainBundle].bundleURL;
    if (bundleURL) {
        [candidates addObject:[[bundleURL URLByAppendingPathComponent:@"Contents/Resources" isDirectory:YES]
                               URLByAppendingPathComponent:@"Templates" isDirectory:YES]];
    }

    for (NSURL *candidate in candidates) {
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:candidate.path isDirectory:&isDir] && isDir) {
            return candidate;
        }
    }
    return nil;
}

+ (BOOL)ensureDirectory:(NSURL *)url error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:url.path isDirectory:&isDir]) {
        if (isDir) {
            return YES;
        }
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorDestinationInvalid
                                   description:[NSString stringWithFormat:@"A file exists where a folder is required: %@", url.path]];
        }
        return NO;
    }
    NSError *createError = nil;
    if (![fm createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&createError]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorDestinationNotWritable
                                   description:createError.localizedDescription ?: @"The folder could not be created."];
        }
        return NO;
    }
    return YES;
}

+ (BOOL)ensureSupportDirectories:(NSError **)error {
    NSArray<NSURL *> *dirs = @[[self supportDirectoryURL],
                               [self templatesDirectoryURL],
                               [self backupsDirectoryURL],
                               [self logsDirectoryURL]];
    for (NSURL *dir in dirs) {
        if (![self ensureDirectory:dir error:error]) {
            return NO;
        }
    }
    return YES;
}

@end

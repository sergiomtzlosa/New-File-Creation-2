#import "NFConfigStore.h"
#import "NFPaths.h"
#import "NFLock.h"
#import "NFErrors.h"
#import "NFVersion.h"
#import "NFLogger.h"
#import "NFTemplate.h"
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>

NSNotificationName const NFConfigDidChangeNotification = @"NFConfigDidChangeNotification";
NSString * const NFConfigDistributedChangeNotification = @"com.sid.newfilecreation2.configchanged";

static const NSTimeInterval NFConfigLockTimeout = 5.0;

@interface NFConfigStore ()
@property (nonatomic, readwrite) NSURL *supportURL;
@property (nonatomic, readwrite) NSURL *configURL;
@property (nonatomic, readwrite) NSURL *templatesURL;
@property (nonatomic, readonly) NSURL *lockURL;
@property (nonatomic, readonly) NSURL *backupsURL;
- (BOOL)ensureStoreDirectories:(NSError **)error;
@end

@implementation NFConfigStore

@synthesize backupsURL = _backupsURL;

static NFConfigStore *NFSharedConfigStore = nil;
static dispatch_once_t NFSharedConfigStoreOnceToken;

+ (instancetype)sharedStore {
    dispatch_once(&NFSharedConfigStoreOnceToken, ^{
        NFSharedConfigStore = [[self alloc] init];
    });
    return NFSharedConfigStore;
}

+ (void)resetSharedStore {
    NFSharedConfigStore = nil;
    NFSharedConfigStoreOnceToken = 0;
}

- (instancetype)init {
    return [self initWithSupportDirectory:[NFPaths supportDirectoryURL]];
}

- (instancetype)initWithConfigURL:(NSURL *)configURL {
    return [self initWithSupportDirectory:configURL.URLByDeletingLastPathComponent];
}

- (instancetype)initWithSupportDirectory:(NSURL *)supportDirectory {
    self = [super init];
    if (self) {
        _supportURL = [supportDirectory copy];
        _configURL = [_supportURL URLByAppendingPathComponent:@"config.json" isDirectory:NO];
        _templatesURL = [_supportURL URLByAppendingPathComponent:@"Templates" isDirectory:YES];
        _lockURL = [_supportURL URLByAppendingPathComponent:@"config.lock" isDirectory:NO];
        _backupsURL = [_supportURL URLByAppendingPathComponent:@"Backups" isDirectory:YES];
    }
    return self;
}

- (NSURL *)backupsURL {
    return _backupsURL ?: [self.supportURL URLByAppendingPathComponent:@"Backups" isDirectory:YES];
}

- (BOOL)ensureStoreDirectories:(NSError **)error {
    if (![NFPaths ensureDirectory:self.supportURL error:error]) {
        return NO;
    }
    if (![NFPaths ensureDirectory:self.templatesURL error:error]) {
        return NO;
    }
    return [NFPaths ensureDirectory:self.backupsURL error:error];
}

#pragma mark - Reading

- (NFConfig *)readConfigAtURL:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSFileNoSuchFileError
                                     userInfo:@{NSLocalizedDescriptionKey: @"The configuration file does not exist."}];
        }
        return nil;
    }
    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!object || ![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigCorrupt
                                   description:jsonError.localizedDescription ?: @"The configuration is not valid JSON."];
        }
        return nil;
    }
    NSDictionary *dictionary = object;
    id schemaValue = dictionary[@"schemaVersion"];
    NSInteger schema = [schemaValue respondsToSelector:@selector(integerValue)] ? [schemaValue integerValue] : 1;
    if (schema > NFCSchemaVersion) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorUnsupportedSchema
                                   description:[NSString stringWithFormat:@"The configuration uses schema %ld; this build supports %ld.", (long)schema, (long)NFCSchemaVersion]];
        }
        return nil;
    }
    return [[NFConfig alloc] initWithDictionary:dictionary];
}

- (NFConfig *)readConfigWithError:(NSError **)error {
    return [self readConfigAtURL:self.configURL error:error];
}

- (NFConfig *)readOnlySnapshot {
    NSError *error = nil;
    NFConfig *config = [self readConfigWithError:&error];
    if (config) {
        return config;
    }
    NFConfig *fallback = [NFConfig defaultConfig];
    return fallback;
}

- (BOOL)quarantineCorruptConfig:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.configURL.path]) {
        return YES;
    }
    if (![NFPaths ensureDirectory:self.backupsURL error:error]) {
        return NO;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *name = [NSString stringWithFormat:@"config-corrupt-%@.json", [formatter stringFromDate:[NSDate date]]];
    NSURL *destination = [self.backupsURL URLByAppendingPathComponent:name];
    NSError *moveError = nil;
    if (![fm moveItemAtURL:self.configURL toURL:destination error:&moveError]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:moveError.localizedDescription ?: @"The damaged configuration could not be moved aside."];
        }
        return NO;
    }
    [[NFLogger sharedLogger] error:@"Quarantined corrupt config at %@", destination.path];
    return YES;
}

#pragma mark - Writing

- (BOOL)writeConfig:(NFConfig *)config error:(NSError **)error {
    config.schemaVersion = NFCSchemaVersion;
    config.updatedAt = [NSDate date];

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[config dictionaryRepresentation]
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&jsonError];
    if (!data) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:jsonError.localizedDescription ?: @"The configuration could not be encoded."];
        }
        return NO;
    }

    if (![NFPaths ensureDirectory:self.supportURL error:error]) {
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *backupURL = [self.supportURL URLByAppendingPathComponent:@"config.json.bak"];
    if ([fm fileExistsAtPath:self.configURL.path]) {
        [fm removeItemAtURL:backupURL error:nil];
        NSError *backupError = nil;
        if (![fm copyItemAtURL:self.configURL toURL:backupURL error:&backupError]) {
            [[NFLogger sharedLogger] error:@"Could not write config backup: %@", backupError.localizedDescription];
        }
    }

    NSString *tempName = [NSString stringWithFormat:@".config.json.tmp.%d.%@", getpid(), NSUUID.UUID.UUIDString];
    NSURL *tempURL = [self.supportURL URLByAppendingPathComponent:tempName];
    int fd = open(tempURL.path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0644);
    if (fd < 0) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:[NSString stringWithFormat:@"Could not create the temporary config: %s", strerror(errno)]];
        }
        return NO;
    }

    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    BOOL writeOK = YES;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written <= 0) {
            writeOK = NO;
            break;
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    if (writeOK) {
        writeOK = (fsync(fd) == 0);
    }
    close(fd);

    if (!writeOK) {
        unlink(tempURL.path.fileSystemRepresentation);
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:[NSString stringWithFormat:@"Could not write the configuration: %s", strerror(errno)]];
        }
        return NO;
    }

    if (rename(tempURL.path.fileSystemRepresentation, self.configURL.path.fileSystemRepresentation) != 0) {
        unlink(tempURL.path.fileSystemRepresentation);
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:[NSString stringWithFormat:@"Could not replace the configuration: %s", strerror(errno)]];
        }
        return NO;
    }

    int dirFD = open(self.supportURL.path.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
    if (dirFD >= 0) {
        fsync(dirFD);
        close(dirFD);
    }
    return YES;
}

- (void)postChangeNotificationForRevision:(NSInteger)revision {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NFConfigDidChangeNotification
                                                            object:self
                                                          userInfo:@{@"revision": @(revision)}];
    });
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:NFConfigDistributedChangeNotification
                                                                   object:nil
                                                                 userInfo:@{@"revision": @(revision)}
                                                       deliverImmediately:YES];
}

#pragma mark - Seeding

- (BOOL)seedBundledTemplatesIfNeeded:(NFConfig *)config error:(NSError **)error {
    if ([config boolSettingForKey:@"didSeedBundledTemplates" defaultValue:NO]) {
        return YES;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *bundled = [NFPaths bundledTemplatesDirectoryURL];
    if (!bundled) {
        [config setSetting:@YES forKey:@"didSeedBundledTemplates"];
        return YES;
    }
    if (![NFPaths ensureDirectory:self.templatesURL error:error]) {
        return NO;
    }

    NSError *listError = nil;
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:bundled.path error:&listError];
    if (!names) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:listError.localizedDescription ?: @"The bundled templates could not be read."];
        }
        return NO;
    }
    names = [names sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSInteger index = (NSInteger)config.templates.count;
    for (NSString *name in names) {
        if ([name hasPrefix:@"."]) {
            continue;
        }
        NSURL *source = [bundled URLByAppendingPathComponent:name];
        NSURL *destination = [self.templatesURL URLByAppendingPathComponent:name];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:source.path isDirectory:&isDir]) {
            continue;
        }
        if (![fm fileExistsAtPath:destination.path]) {
            NSError *copyError = nil;
            if (![fm copyItemAtURL:source toURL:destination error:&copyError]) {
                [[NFLogger sharedLogger] error:@"Could not seed template %@: %@", name, copyError.localizedDescription];
                continue;
            }
        }
        if (![config templateWithFileName:name]) {
            NFTemplate *template = [NFTemplate templateWithFileName:name];
            template.identifier = NSUUID.UUID.UUIDString;
            template.displayName = [NFTemplate displayNameForFileName:name];
            template.category = [NFTemplate inferCategoryForFileExtension:name.pathExtension];
            template.enabled = YES;
            template.favorite = NO;
            template.sortIndex = index++;
            template.source = @"included";
            template.createdAt = [NSDate date];
            [config.templates addObject:template];
        }
    }
    [config.templates sortUsingComparator:^NSComparisonResult(NFTemplate *a, NFTemplate *b) {
        if (a.sortIndex != b.sortIndex) {
            return a.sortIndex < b.sortIndex ? NSOrderedAscending : NSOrderedDescending;
        }
        return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
    }];
    [config setSetting:@YES forKey:@"didSeedBundledTemplates"];
    if ([[config stringSettingForKey:@"defaultTemplateID" defaultValue:@""] length] == 0 && config.templates.count > 0) {
        [config setSetting:config.templates.firstObject.identifier forKey:@"defaultTemplateID"];
    }
    return YES;
}

#pragma mark - Public API

- (NFConfig *)loadConfigCreatingIfNeeded:(BOOL)create error:(NSError **)error {
    NSError *dirError = nil;
    if (![self ensureStoreDirectories:&dirError]) {
        if (error) {
            *error = dirError;
        }
        return nil;
    }

    NFLock *lock = [[NFLock alloc] initWithURL:self.lockURL];
    NSError *lockError = nil;
    if (![lock lockWithTimeout:NFConfigLockTimeout error:&lockError]) {
        if (error) {
            *error = lockError;
        }
        return nil;
    }

    NSError *readError = nil;
    NFConfig *config = [self readConfigWithError:&readError];

    if (!config && readError.code == NFErrorConfigCorrupt) {
        [self quarantineCorruptConfig:nil];
        NSURL *backupURL = [self.supportURL URLByAppendingPathComponent:@"config.json.bak"];
        config = [self readConfigAtURL:backupURL error:nil];
    }

    if (!config && readError.code == NFErrorUnsupportedSchema) {
        [lock unlock];
        if (error) {
            *error = readError;
        }
        return nil;
    }

    if (!config) {
        if (!create) {
            [lock unlock];
            if (error) {
                *error = readError;
            }
            return nil;
        }
        config = [NFConfig defaultConfig];
        if (![self seedBundledTemplatesIfNeeded:config error:nil]) {
            // Seeding is best-effort; the app can still run without bundled templates.
        }
        config.revision = 0;
        NSError *writeError = nil;
        if (![self writeConfig:config error:&writeError]) {
            [lock unlock];
            if (error) {
                *error = writeError;
            }
            return nil;
        }
        NSInteger revision = config.revision;
        [lock unlock];
        [self postChangeNotificationForRevision:revision];
        return config;
    }

    if (create && ![config boolSettingForKey:@"didSeedBundledTemplates" defaultValue:NO]) {
        if ([self seedBundledTemplatesIfNeeded:config error:nil]) {
            config.revision += 1;
            [self writeConfig:config error:nil];
        }
    }

    [lock unlock];
    return config;
}

- (BOOL)updateConfig:(BOOL (^)(NFConfig *config, NSError **error))block error:(NSError **)error {
    if (!block) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorUnknown description:@"No update block was provided."];
        }
        return NO;
    }

    NSError *lastError = nil;
    for (NSInteger attempt = 0; attempt < 2; attempt++) {
        NSError *dirError = nil;
        if (![self ensureStoreDirectories:&dirError]) {
            lastError = dirError;
            continue;
        }
        NFLock *lock = [[NFLock alloc] initWithURL:self.lockURL];
        NSError *lockError = nil;
        if (![lock lockWithTimeout:NFConfigLockTimeout error:&lockError]) {
            lastError = lockError;
            continue;
        }

        NFConfig *config = [self readConfigWithError:nil] ?: [NFConfig defaultConfig];
        NSError *blockError = nil;
        BOOL proceed = block(config, &blockError);
        if (!proceed) {
            [lock unlock];
            if (error) {
                *error = blockError ?: [NSError nf_errorWithCode:NFErrorUnknown description:@"The update was cancelled."];
            }
            return NO;
        }

        config.schemaVersion = NFCSchemaVersion;
        config.revision = MAX(config.revision, 0) + 1;
        NSError *writeError = nil;
        BOOL written = [self writeConfig:config error:&writeError];
        NSInteger revision = config.revision;
        [lock unlock];

        if (written) {
            [self postChangeNotificationForRevision:revision];
            return YES;
        }
        lastError = writeError;
    }

    if (error) {
        *error = lastError ?: [NSError nf_errorWithCode:NFErrorConfigWriteFailed];
    }
    return NO;
}

- (BOOL)replaceConfig:(NFConfig *)config error:(NSError **)error {
    return [self updateConfig:^BOOL(NFConfig *current, NSError **blockError) {
        current.settings = [config.settings mutableCopy] ?: [NSMutableDictionary dictionary];
        current.templates = [config.templates mutableCopy] ?: [NSMutableArray array];
        current.recentTemplateIDs = [config.recentTemplateIDs mutableCopy] ?: [NSMutableArray array];
        current.recentFiles = [config.recentFiles mutableCopy] ?: [NSMutableArray array];
        return YES;
    } error:error];
}

- (NSURL *)templateFileURLForTemplate:(NFTemplate *)template {
    if (template.fileName.length == 0) {
        return self.templatesURL;
    }
    return [self.templatesURL URLByAppendingPathComponent:template.fileName];
}

@end

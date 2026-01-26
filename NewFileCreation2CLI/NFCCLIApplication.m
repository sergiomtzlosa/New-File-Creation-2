#import "NFCCLIApplication.h"
#import "NFCCLIOptions.h"
#import "NFCCLIOutput.h"
#import "NFCCLIResolver.h"
#import "NFCStrings.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFFileCreator.h"
#import "NFSanitize.h"
#import "NFPaths.h"
#import "NFErrors.h"
#import "NFVersion.h"
#import "NFLegacyMigration.h"
#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>
#import <unistd.h>

typedef NS_ENUM(int, NFCLIExitCode) {
    NFCLIExitSuccess = 0,
    NFCLIExitGeneral = 1,
    NFCLIExitUsage = 2,
    NFCLIExitNotFound = 3,
    NFCLIExitAmbiguous = 4,
    NFCLIExitConflict = 5,
    NFCLIExitConfig = 6,
    NFCLIExitPermission = 7
};

@interface NFCCLIApplication ()

@property (nonatomic, strong) NFConfigStore *store;
@property (nonatomic, strong) NFCCLIOutput *output;
@property (nonatomic, copy) NSString *commandName;
@property (nonatomic, assign) BOOL verbose;

@end

@implementation NFCCLIApplication

- (instancetype)init {
    self = [super init];
    if (self) {
        _store = [NFConfigStore sharedStore];
        _output = [[NFCCLIOutput alloc] init];
    }
    return self;
}

#pragma mark - Entry point

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    NSMutableArray<NSString *> *remaining = [NSMutableArray array];
    BOOL helpRequested = NO;
    BOOL versionRequested = NO;
    NSString *configPath = nil;

    for (NSUInteger index = 0; index < arguments.count; index++) {
        NSString *argument = arguments[index];
        if ([argument isEqualToString:@"--json"]) {
            self.output.json = YES;
        } else if ([argument isEqualToString:@"--quiet"] || [argument isEqualToString:@"-q"]) {
            self.output.quiet = YES;
        } else if ([argument isEqualToString:@"--plain"]) {
            self.output.plain = YES;
        } else if ([argument isEqualToString:@"--no-color"]) {
            // Accepted for compatibility; output is uncolored.
        } else if ([argument isEqualToString:@"--verbose"]) {
            self.verbose = YES;
        } else if ([argument isEqualToString:@"--help"] || [argument isEqualToString:@"-h"]) {
            helpRequested = YES;
        } else if ([argument isEqualToString:@"--version"] || [argument isEqualToString:@"-v"]) {
            versionRequested = YES;
        } else if ([argument isEqualToString:@"--config"]) {
            if (index + 1 >= arguments.count) {
                [self.output errorLine:@"--config requires a path."];
                return NFCLIExitUsage;
            }
            configPath = arguments[++index];
        } else if ([argument hasPrefix:@"--config="]) {
            configPath = [argument substringFromIndex:9];
        } else {
            [remaining addObject:argument];
        }
    }

    if (configPath.length > 0) {
        NSString *expanded = [configPath stringByExpandingTildeInPath];
        if (![expanded isAbsolutePath]) {
            expanded = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:expanded];
        }
        NSURL *url = [NSURL fileURLWithPath:expanded.stringByStandardizingPath];
        self.store = [[NFConfigStore alloc] initWithConfigURL:url];
    }

    self.commandName = remaining.firstObject ?: @"";

    if (versionRequested && remaining.count == 0) {
        return [self runVersion:@[]];
    }
    if (remaining.count == 0) {
        [self printGeneralHelp];
        return NFCLIExitSuccess;
    }

    NSString *command = remaining.firstObject;
    NSArray<NSString *> *commandArguments = [remaining subarrayWithRange:NSMakeRange(1, remaining.count - 1)];

    if (helpRequested) {
        [self printHelpForCommand:command];
        return NFCLIExitSuccess;
    }

    if ([command isEqualToString:@"help"]) {
        return [self runHelp:commandArguments];
    }
    if ([command isEqualToString:@"version"]) {
        return [self runVersion:commandArguments];
    }
    if ([command isEqualToString:@"create"]) {
        return [self runCreate:commandArguments];
    }
    if ([command isEqualToString:@"list"] || [command isEqualToString:@"ls"]) {
        return [self runList:commandArguments];
    }
    if ([command isEqualToString:@"show"] || [command isEqualToString:@"info"]) {
        return [self runShow:commandArguments];
    }
    if ([command isEqualToString:@"add"]) {
        return [self runAdd:commandArguments];
    }
    if ([command isEqualToString:@"remove"] || [command isEqualToString:@"rm"]) {
        return [self runRemove:commandArguments];
    }
    if ([command isEqualToString:@"favorite"] || [command isEqualToString:@"fav"]) {
        return [self runFavorite:commandArguments];
    }
    if ([command isEqualToString:@"enable"]) {
        return [self runToggle:commandArguments enabled:YES];
    }
    if ([command isEqualToString:@"disable"]) {
        return [self runToggle:commandArguments enabled:NO];
    }
    if ([command isEqualToString:@"recent"]) {
        return [self runRecent:commandArguments];
    }
    if ([command isEqualToString:@"categories"] || [command isEqualToString:@"cats"]) {
        return [self runCategories:commandArguments];
    }
    if ([command isEqualToString:@"config"]) {
        return [self runConfig:commandArguments];
    }
    if ([command isEqualToString:@"status"]) {
        return [self runStatus:commandArguments];
    }
    if ([command isEqualToString:@"open"]) {
        return [self runOpen:commandArguments];
    }
    if ([command isEqualToString:@"doctor"]) {
        return [self runDoctor:commandArguments];
    }
    if ([command isEqualToString:@"completion"]) {
        return [self runCompletion:commandArguments];
    }
    if ([command isEqualToString:@"import-legacy"]) {
        return [self runImportLegacy:commandArguments];
    }

    [self.output errorLine:@"Unknown command “%@”.", command];
    [self.output errorLine:@"Run “nfc help” for usage."];
    return NFCLIExitUsage;
}

#pragma mark - Helpers

- (void)printGeneralHelp {
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"help" data:@{@"text": [NFCStrings generalHelp]}];
    } else {
        fputs([NFCStrings generalHelp].UTF8String, stdout);
    }
}

- (void)printHelpForCommand:(NSString *)command {
    NSString *help = command.length > 0 ? [NFCStrings helpForCommand:command] : [NFCStrings generalHelp];
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"help" data:@{@"command": command ?: @"", @"text": help}];
    } else {
        fputs(help.UTF8String, stdout);
    }
}

- (int)exitCodeForError:(NSError *)error {
    switch (error.code) {
        case NFErrorCLIUsage:
            return NFCLIExitUsage;
        case NFErrorCLINotFound:
        case NFErrorTemplateMissing:
            return NFCLIExitNotFound;
        case NFErrorCLIAmbiguous:
            return NFCLIExitAmbiguous;
        case NFErrorFileExists:
            return NFCLIExitConflict;
        case NFErrorConfigCorrupt:
        case NFErrorConfigWriteFailed:
        case NFErrorUnsupportedSchema:
            return NFCLIExitConfig;
        case NFErrorDestinationNotWritable:
        case NFErrorTemplateUnreadable:
        case NFErrorDestinationInvalid:
            return NFCLIExitPermission;
        default:
            return NFCLIExitGeneral;
    }
}

- (int)failWithError:(NSError *)error command:(NSString *)command {
    int code = [self exitCodeForError:error];
    if (self.output.json) {
        [self.output jsonFailureWithCommand:command error:error exitCode:code];
    } else {
        [self.output errorLine:@"nfc: %@", error.localizedDescription ?: @"An error occurred."];
        id suggestions = error.userInfo[@"suggestions"];
        if ([suggestions isKindOfClass:[NSArray class]] && [suggestions count] > 0) {
            [self.output errorLine:@"Templates: %@", [suggestions componentsJoinedByString:@", "]];
        }
    }
    return code;
}

- (int)failWithMessage:(NSString *)message command:(NSString *)command code:(int)code {
    NSError *error = [NSError nf_errorWithCode:code == NFCLIExitUsage ? NFErrorCLIUsage : NFErrorUnknown
                                   description:message];
    return [self failWithError:error command:command];
}

- (NFConfig *)loadConfig:(NSError **)error {
    return [self.store loadConfigCreatingIfNeeded:YES error:error];
}

- (NSString *)absolutePath:(NSString *)path {
    NSString *expanded = path.stringByExpandingTildeInPath;
    if (!expanded.isAbsolutePath) {
        expanded = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:expanded];
    }
    return expanded.stringByStandardizingPath;
}

- (NFCCLIOptions *)optionsForArguments:(NSArray<NSString *> *)arguments
                          valueOptions:(NSSet<NSString *> *)valueOptions
                           flagOptions:(NSSet<NSString *> *)flagOptions
                                 error:(NSError **)error {
    return [NFCCLIOptions parseArguments:arguments valueOptions:valueOptions flagOptions:flagOptions error:error];
}

- (NSString *)lastUsedDirectory {
    NSString *directory = [self.store loadConfigCreatingIfNeeded:NO error:nil] ? [[self.store loadConfigCreatingIfNeeded:NO error:nil] stringSettingForKey:@"lastUsedDirectory" defaultValue:@""] : @"";
    return directory;
}

- (NSDictionary *)templateDictionary:(NFTemplate *)template {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self.store templateFileURLForTemplate:template].path error:nil];
    NSNumber *size = attributes[NSFileSize] ?: @0;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = template.identifier;
    dict[@"fileName"] = template.fileName;
    dict[@"displayName"] = template.resolvedDisplayName;
    dict[@"category"] = template.category;
    dict[@"extension"] = template.fileExtension;
    dict[@"enabled"] = @(template.enabled);
    dict[@"favorite"] = @(template.favorite);
    dict[@"useCount"] = @(template.useCount);
    dict[@"size"] = size;
    dict[@"path"] = [self.store templateFileURLForTemplate:template].path;
    if (template.createdAt) {
        dict[@"createdAt"] = [self ISO8601String:template.createdAt];
    }
    if (template.lastUsedAt) {
        dict[@"lastUsedAt"] = [self ISO8601String:template.lastUsedAt];
    }
    return dict;
}

- (NSString *)ISO8601String:(NSDate *)date {
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

- (NSString *)runTaskWithLaunchPath:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:launchPath];
    task.arguments = arguments;
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        return @"";
    }
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

- (NSInteger)loginItemStatus {
    if (@available(macOS 13.0, *)) {
        return (NSInteger)SMAppService.mainAppService.status;
    }
    return -1;
}

- (NSString *)finderExtensionStatus {
    NSString *output = [self runTaskWithLaunchPath:@"/usr/bin/pluginkit"
                                        arguments:@[@"-m", @"-i", @"com.sid.newfilecreation2.finder"]];
    NSString *trimmed = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return @"not-registered";
    }
    if ([trimmed hasPrefix:@"+"]) {
        return @"enabled";
    }
    if ([trimmed hasPrefix:@"-"]) {
        return @"disabled";
    }
    return @"registered";
}

#pragma mark - Commands

- (int)runVersion:(NSArray<NSString *> *)arguments {
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"version" data:@{@"version": NFCVersionString, @"schemaVersion": @(NFCSchemaVersion)}];
    } else {
        [self.output line:@"%@", [NFCStrings versionLine]];
    }
    return NFCLIExitSuccess;
}

- (int)runHelp:(NSArray<NSString *> *)arguments {
    NSString *command = arguments.firstObject;
    [self printHelpForCommand:command ?: @""];
    return NFCLIExitSuccess;
}

- (int)runCreate:(NSArray<NSString *> *)arguments {
    NSSet *values = [NSSet setWithArray:@[@"name", @"n", @"output", @"o", @"dir", @"d", @"template"]];
    NSSet *flags = [NSSet setWithArray:@[@"no-unique", @"open", @"reveal", @"sound", @"dry-run", @"use-app-location"]];
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:values flagOptions:flags error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"create"];
    }
    if (options.positionals.count > 1) {
        [self.output errorLine:@"%@", [NFCStrings usageForCommand:@"create"]];
        return NFCLIExitUsage;
    }

    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"create"];
    }
    NSString *reference = options.positionals.firstObject ?: [options valueFor:@"template"];
    NFTemplate *template = [NFCCLIResolver resolveReference:reference inConfig:config error:&error];
    if (!template) {
        return [self failWithError:error command:@"create"];
    }
    NSURL *templateURL = [self.store templateFileURLForTemplate:template];
    if (![[NSFileManager defaultManager] fileExistsAtPath:templateURL.path]) {
        NSError *missing = [NSError nf_errorWithCode:NFErrorTemplateMissing
                                         description:[NSString stringWithFormat:@"The template file “%@” is missing.", template.fileName]];
        return [self failWithError:missing command:@"create"];
    }

    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    NSString *outputPath = [options valueFor:@"output"] ?: [options valueFor:@"o"];
    NSString *directoryPath = [options valueFor:@"dir"] ?: [options valueFor:@"d"];
    NSString *name = [options valueFor:@"name"] ?: [options valueFor:@"n"];
    NSString *baseName = name;
    NSString *directory = nil;
    NSURL *exactOutputURL = nil;

    if (outputPath.length > 0) {
        NSString *absolute = [self absolutePath:outputPath];
        exactOutputURL = [NSURL fileURLWithPath:absolute];
        directory = absolute.stringByDeletingLastPathComponent;
        if (baseName.length == 0) {
            baseName = absolute.lastPathComponent;
        }
    } else if (directoryPath.length > 0) {
        directory = [self absolutePath:directoryPath];
    } else if ([options hasFlag:@"use-app-location"]) {
        NSString *configured = [config stringSettingForKey:@"defaultDirectory" defaultValue:@""];
        directory = configured.length > 0 ? configured : cwd;
    } else {
        directory = cwd;
    }

    if (baseName.length == 0) {
        baseName = [config stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName];
    }
    BOOL unique = ![options hasFlag:@"no-unique"];
    BOOL dryRun = [options hasFlag:@"dry-run"];

    if (dryRun) {
        NSURL *destination = nil;
        if (exactOutputURL) {
            destination = exactOutputURL;
        } else {
            NSString *sanitized = [NFSanitize sanitizedBaseName:baseName fallback:NFDefaultBaseName];
            NSString *fileName = [NFSanitize fileNameForBaseName:sanitized templateFileName:templateURL.lastPathComponent];
            destination = [[NSURL fileURLWithPath:directory isDirectory:YES] URLByAppendingPathComponent:fileName];
        }
        if (!unique && [[NSFileManager defaultManager] fileExistsAtPath:destination.path]) {
            NSError *conflict = [NSError nf_errorWithCode:NFErrorFileExists
                                             description:[NSString stringWithFormat:@"“%@” already exists.", destination.lastPathComponent]];
            return [self failWithError:conflict command:@"create"];
        }
        if (unique) {
            destination = [NFSanitize uniqueDestinationURLForURL:destination];
        }
        if (self.output.json) {
            [self.output jsonSuccessWithCommand:@"create" data:@{@"path": destination.path, @"dryRun": @YES, @"template": [self templateDictionary:template]}];
        } else if (self.output.quiet) {
            [self.output line:@"%@", destination.path];
        } else {
            [self.output line:@"Would create %@", destination.path];
        }
        return NFCLIExitSuccess;
    }

    NSURL *created = nil;
    if (exactOutputURL) {
        created = [NFFileCreator createFileFromTemplateAtURL:templateURL
                                                 destination:exactOutputURL
                                                      unique:unique
                                                       error:&error];
    } else {
        created = [NFFileCreator createFileFromTemplateAtURL:templateURL
                                                    template:template
                                                   directory:[NSURL fileURLWithPath:directory isDirectory:YES]
                                                    baseName:baseName
                                                      unique:unique
                                                       error:&error];
    }
    if (!created) {
        return [self failWithError:error command:@"create"];
    }

    NSError *updateError = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
        NFTemplate *current = [latest templateWithIdentifier:template.identifier] ?: template;
        [latest recordUsageOfTemplate:current];
        [latest addRecentFile:created.path];
        [latest setSetting:directory forKey:@"lastUsedDirectory"];
        return YES;
    } error:&updateError];
    if (!updated) {
        [self.output errorLine:@"warning: the file was created, but metadata could not be saved: %@", updateError.localizedDescription];
    }

    if ([options hasFlag:@"open"]) {
        [[NSWorkspace sharedWorkspace] openURL:created];
    }
    if ([options hasFlag:@"reveal"]) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[created]];
    }
    if ([options hasFlag:@"sound"]) {
        [[NSSound soundNamed:@"Glass"] play];
    }

    if (self.output.json) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:created.path error:nil];
        [self.output jsonSuccessWithCommand:@"create" data:@{
            @"path": created.path,
            @"name": created.lastPathComponent,
            @"size": attributes[NSFileSize] ?: @0,
            @"template": [self templateDictionary:template]
        }];
    } else if (self.output.quiet) {
        [self.output line:@"%@", created.path];
    } else {
        [self.output line:@"Created %@", created.path];
    }
    return NFCLIExitSuccess;
}

- (int)runList:(NSArray<NSString *> *)arguments {
    NSSet *values = [NSSet setWithArray:@[@"category"]];
    NSSet *flags = [NSSet setWithArray:@[@"favorites", @"enabled", @"all"]];
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:values flagOptions:flags error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"list"];
    }
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"list"];
    }

    NSString *category = [options valueFor:@"category"];
    NSMutableArray<NFTemplate *> *result = [NSMutableArray array];
    for (NFTemplate *template in config.templates) {
        if ([options hasFlag:@"favorites"] && !template.favorite) {
            continue;
        }
        if ([options hasFlag:@"enabled"] && !template.enabled) {
            continue;
        }
        if (category.length > 0 && [template.category caseInsensitiveCompare:category] != NSOrderedSame) {
            continue;
        }
        [result addObject:template];
    }

    if (self.output.json) {
        NSMutableArray *items = [NSMutableArray array];
        for (NFTemplate *template in result) {
            [items addObject:[self templateDictionary:template]];
        }
        [self.output jsonSuccessWithCommand:@"list" data:@{@"templates": items, @"count": @(items.count)}];
        return NFCLIExitSuccess;
    }

    if (result.count == 0) {
        [self.output line:@"No templates match."];
        return NFCLIExitSuccess;
    }

    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
    for (NFTemplate *template in result) {
        [rows addObject:@[
            [template.identifier substringToIndex:MIN(8, template.identifier.length)],
            template.resolvedDisplayName,
            template.fileExtension.length > 0 ? template.fileExtension : @"-",
            template.category,
            template.favorite ? @"yes" : @"-",
            template.enabled ? @"yes" : @"no",
            [NSString stringWithFormat:@"%ld", (long)template.useCount]
        ]];
    }
    [self.output tableWithHeaders:@[@"ID", @"NAME", @"EXT", @"CATEGORY", @"FAV", @"ON", @"USES"] rows:rows];
    return NFCLIExitSuccess;
}

- (int)runShow:(NSArray<NSString *> *)arguments {
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:[NSSet set] flagOptions:[NSSet set] error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"show"];
    }
    if (options.positionals.count > 1) {
        [self.output errorLine:@"%@", [NFCStrings usageForCommand:@"show"]];
        return NFCLIExitUsage;
    }
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"show"];
    }
    NFTemplate *template = [NFCCLIResolver resolveReference:options.positionals.firstObject inConfig:config error:&error];
    if (!template) {
        return [self failWithError:error command:@"show"];
    }
    NSDictionary *dict = [self templateDictionary:template];
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"show" data:dict];
        return NFCLIExitSuccess;
    }
    [self.output line:@"ID:          %@", template.identifier];
    [self.output line:@"File:        %@", template.fileName];
    [self.output line:@"Name:        %@", template.resolvedDisplayName];
    [self.output line:@"Category:    %@", template.category];
    [self.output line:@"Extension:   %@", template.fileExtension.length > 0 ? template.fileExtension : @"(none)"];
    [self.output line:@"Enabled:     %@", template.enabled ? @"yes" : @"no"];
    [self.output line:@"Favorite:    %@", template.favorite ? @"yes" : @"no"];
    [self.output line:@"Uses:        %ld", (long)template.useCount];
    if (dict[@"createdAt"]) {
        [self.output line:@"Created:     %@", dict[@"createdAt"]];
    }
    if (dict[@"lastUsedAt"]) {
        [self.output line:@"Last used:   %@", dict[@"lastUsedAt"]];
    }
    [self.output line:@"Path:        %@", dict[@"path"]];
    return NFCLIExitSuccess;
}

- (int)runAdd:(NSArray<NSString *> *)arguments {
    NSSet *values = [NSSet setWithArray:@[@"name", @"category"]];
    NSSet *flags = [NSSet setWithArray:@[@"favorite", @"disabled"]];
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:values flagOptions:flags error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"add"];
    }
    if (options.positionals.count == 0) {
        [self.output errorLine:@"%@", [NFCStrings usageForCommand:@"add"]];
        return NFCLIExitUsage;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSDictionary *> *added = [NSMutableArray array];
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSString *displayNameOption = [options valueFor:@"name"];
    NSString *categoryOption = [options valueFor:@"category"];
    NSError *error = nil;
    [NFPaths ensureDirectory:self.store.templatesURL error:&error];

    for (NSString *argument in options.positionals) {
        NSString *path = [self absolutePath:argument];
        if (![fm fileExistsAtPath:path]) {
            [failures addObject:[NSString stringWithFormat:@"%@: file not found", argument]];
            continue;
        }
        NSURL *source = [NSURL fileURLWithPath:path];
        NSURL *destination = [self.store.templatesURL URLByAppendingPathComponent:source.lastPathComponent];
        if ([fm fileExistsAtPath:destination.path]) {
            destination = [NFSanitize uniqueDestinationURLForURL:destination];
        }
        NSError *copyError = nil;
        if (![fm copyItemAtURL:source toURL:destination error:&copyError]) {
            [failures addObject:[NSString stringWithFormat:@"%@: %@", argument, copyError.localizedDescription]];
            continue;
        }
        NSString *displayName = displayNameOption.length > 0 && options.positionals.count == 1
            ? displayNameOption
            : [NFTemplate displayNameForFileName:destination.lastPathComponent];
        NSString *category = categoryOption.length > 0
            ? categoryOption
            : [NFTemplate inferCategoryForFileExtension:destination.pathExtension];
        [added addObject:@{
            @"fileName": destination.lastPathComponent,
            @"displayName": displayName,
            @"category": category
        }];
    }

    if (added.count == 0) {
        NSError *addError = [NSError nf_errorWithCode:NFErrorTemplateUnreadable
                                         description:[failures componentsJoinedByString:@"\n"] ?: @"No files were added."];
        return [self failWithError:addError command:@"add"];
    }

    NSError *updateError = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *config, NSError **blockError) {
        NSInteger index = (NSInteger)config.templates.count;
        for (NSDictionary *entry in added) {
            NFTemplate *template = [NFTemplate templateWithFileName:entry[@"fileName"]];
            template.displayName = entry[@"displayName"];
            template.category = entry[@"category"];
            template.enabled = ![options hasFlag:@"disabled"];
            template.favorite = [options hasFlag:@"favorite"];
            template.sortIndex = index++;
            template.source = @"user";
            [config.templates addObject:template];
        }
        if ([[config stringSettingForKey:@"defaultTemplateID" defaultValue:@""] length] == 0 && config.templates.count > 0) {
            [config setSetting:config.templates.firstObject.identifier forKey:@"defaultTemplateID"];
        }
        return YES;
    } error:&updateError];
    if (!updated) {
        return [self failWithError:updateError command:@"add"];
    }

    for (NSString *failure in failures) {
        [self.output errorLine:@"warning: %@", failure];
    }
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"add" data:@{@"templates": added, @"count": @(added.count)}];
    } else if (self.output.quiet) {
        for (NSDictionary *entry in added) {
            [self.output line:@"%@", entry[@"fileName"]];
        }
    } else {
        [self.output line:@"Added %lu template%@.", (unsigned long)added.count, added.count == 1 ? @"" : @"s"];
        for (NSDictionary *entry in added) {
            [self.output line:@"  %@", entry[@"displayName"]];
        }
    }
    return failures.count > 0 ? NFCLIExitGeneral : NFCLIExitSuccess;
}

- (int)runRemove:(NSArray<NSString *> *)arguments {
    NSSet *flags = [NSSet setWithArray:@[@"keep-file", @"yes", @"y"]];
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:[NSSet set] flagOptions:flags error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"remove"];
    }
    if (options.positionals.count != 1) {
        [self.output errorLine:@"%@", [NFCStrings usageForCommand:@"remove"]];
        return NFCLIExitUsage;
    }
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"remove"];
    }
    NFTemplate *template = [NFCCLIResolver resolveReference:options.positionals.firstObject inConfig:config error:&error];
    if (!template) {
        return [self failWithError:error command:@"remove"];
    }

    BOOL confirmed = [options hasFlag:@"yes"] || [options hasFlag:@"y"];
    if (!confirmed) {
        if (!isatty(STDIN_FILENO)) {
            [self.output errorLine:@"Refusing to remove “%@” without --yes in a non-interactive session.", template.resolvedDisplayName];
            return NFCLIExitUsage;
        }
        fprintf(stderr, "Remove “%s” from the library? [y/N] ", template.resolvedDisplayName.UTF8String);
        char answer[16] = {0};
        if (!fgets(answer, sizeof(answer), stdin) || (answer[0] != 'y' && answer[0] != 'Y')) {
            [self.output line:@"Cancelled."];
            return NFCLIExitSuccess;
        }
    }

    NSURL *templateURL = [self.store templateFileURLForTemplate:template];
    NSString *removedName = template.resolvedDisplayName;
    NSError *updateError = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
        NFTemplate *current = [latest templateWithIdentifier:template.identifier];
        if (!current) {
            if (blockError) {
                *blockError = [NSError nf_errorWithCode:NFErrorCLINotFound description:@"The template no longer exists."];
            }
            return NO;
        }
        [latest.templates removeObject:current];
        if ([[latest stringSettingForKey:@"defaultTemplateID" defaultValue:@""] isEqualToString:current.identifier]) {
            NSString *next = latest.templates.firstObject.identifier ?: @"";
            [latest setSetting:next forKey:@"defaultTemplateID"];
        }
        return YES;
    } error:&updateError];
    if (!updated) {
        return [self failWithError:updateError command:@"remove"];
    }

    BOOL movedToTrash = NO;
    if (![options hasFlag:@"keep-file"] && [[NSFileManager defaultManager] fileExistsAtPath:templateURL.path]) {
        NSError *trashError = nil;
        if ([[NSFileManager defaultManager] trashItemAtURL:templateURL resultingItemURL:nil error:&trashError]) {
            movedToTrash = YES;
        } else {
            [self.output errorLine:@"warning: the template was removed from the library, but its file could not be moved to Trash: %@", trashError.localizedDescription];
        }
    }

    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"remove" data:@{@"id": template.identifier, @"name": removedName, @"trashed": @(movedToTrash)}];
    } else {
        [self.output line:@"Removed %@%@.", removedName, movedToTrash ? @" (file moved to Trash)" : @""];
    }
    return NFCLIExitSuccess;
}

- (int)runFavorite:(NSArray<NSString *> *)arguments {
    NSSet *flags = [NSSet setWithArray:@[@"on", @"off"]];
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:[NSSet set] flagOptions:flags error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"favorite"];
    }
    if ([options hasFlag:@"on"] && [options hasFlag:@"off"]) {
        [self.output errorLine:@"Use either --on or --off, not both."];
        return NFCLIExitUsage;
    }
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"favorite"];
    }
    NFTemplate *template = [NFCCLIResolver resolveReference:options.positionals.firstObject inConfig:config error:&error];
    if (!template) {
        return [self failWithError:error command:@"favorite"];
    }
    BOOL target = [options hasFlag:@"on"] ? YES : ([options hasFlag:@"off"] ? NO : !template.favorite);
    NSError *updateError = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
        NFTemplate *current = [latest templateWithIdentifier:template.identifier];
        if (!current) {
            return NO;
        }
        current.favorite = target;
        return YES;
    } error:&updateError];
    if (!updated) {
        return [self failWithError:updateError command:@"favorite"];
    }
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"favorite" data:@{@"id": template.identifier, @"name": template.resolvedDisplayName, @"favorite": @(target)}];
    } else {
        [self.output line:@"%@ %@.", target ? @"Favorited" : @"Unfavorited", template.resolvedDisplayName];
    }
    return NFCLIExitSuccess;
}

- (int)runToggle:(NSArray<NSString *> *)arguments enabled:(BOOL)enabled {
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:[NSSet set] flagOptions:[NSSet set] error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:enabled ? @"enable" : @"disable"];
    }
    if (options.positionals.count != 1) {
        [self.output errorLine:@"%@", [NFCStrings usageForCommand:enabled ? @"enable" : @"disable"]];
        return NFCLIExitUsage;
    }
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:enabled ? @"enable" : @"disable"];
    }
    NFTemplate *template = [NFCCLIResolver resolveReference:options.positionals.firstObject inConfig:config error:&error];
    if (!template) {
        return [self failWithError:error command:enabled ? @"enable" : @"disable"];
    }
    NSError *updateError = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
        NFTemplate *current = [latest templateWithIdentifier:template.identifier];
        if (!current) {
            return NO;
        }
        current.enabled = enabled;
        return YES;
    } error:&updateError];
    if (!updated) {
        return [self failWithError:updateError command:enabled ? @"enable" : @"disable"];
    }
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:enabled ? @"enable" : @"disable" data:@{@"id": template.identifier, @"name": template.resolvedDisplayName, @"enabled": @(enabled)}];
    } else {
        [self.output line:@"%@ %@.", enabled ? @"Enabled" : @"Disabled", template.resolvedDisplayName];
    }
    return NFCLIExitSuccess;
}

- (int)runRecent:(NSArray<NSString *> *)arguments {
    NSSet *values = [NSSet setWithArray:@[@"limit"]];
    NSError *parseError = nil;
    NFCCLIOptions *options = [self optionsForArguments:arguments valueOptions:values flagOptions:[NSSet set] error:&parseError];
    if (!options) {
        return [self failWithError:parseError command:@"recent"];
    }
    NSInteger limit = [options valueFor:@"limit"].integerValue;
    if (limit <= 0) {
        limit = 5;
    }
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"recent"];
    }
    NSMutableArray<NFTemplate *> *templates = [NSMutableArray array];
    for (NSString *identifier in config.recentTemplateIDs) {
        NFTemplate *template = [config templateWithIdentifier:identifier];
        if (template) {
            [templates addObject:template];
            if ((NSInteger)templates.count >= limit) {
                break;
            }
        }
    }
    if (self.output.json) {
        NSMutableArray *items = [NSMutableArray array];
        for (NFTemplate *template in templates) {
            [items addObject:[self templateDictionary:template]];
        }
        [self.output jsonSuccessWithCommand:@"recent" data:@{@"templates": items}];
        return NFCLIExitSuccess;
    }
    if (templates.count == 0) {
        [self.output line:@"No recent templates."];
        return NFCLIExitSuccess;
    }
    NSMutableArray *rows = [NSMutableArray array];
    for (NFTemplate *template in templates) {
        [rows addObject:@[template.resolvedDisplayName, template.category, template.fileName]];
    }
    [self.output tableWithHeaders:@[@"NAME", @"CATEGORY", @"FILE"] rows:rows];
    return NFCLIExitSuccess;
}

- (int)runCategories:(NSArray<NSString *> *)arguments {
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"categories"];
    }
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (NFTemplate *template in config.templates) {
        NSString *category = template.category.length > 0 ? template.category : NFDefaultCategoryOther;
        counts[category] = @(counts[category].integerValue + 1);
    }
    if (self.output.json) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *category in [counts.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
            [items addObject:@{@"name": category, @"count": counts[category]}];
        }
        [self.output jsonSuccessWithCommand:@"categories" data:@{@"categories": items}];
        return NFCLIExitSuccess;
    }
    if (counts.count == 0) {
        [self.output line:@"No categories."];
        return NFCLIExitSuccess;
    }
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *category in [counts.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        [rows addObject:@[category, [NSString stringWithFormat:@"%@", counts[category]]]];
    }
    [self.output tableWithHeaders:@[@"CATEGORY", @"COUNT"] rows:rows];
    return NFCLIExitSuccess;
}

- (int)runConfig:(NSArray<NSString *> *)arguments {
    NSString *action = arguments.firstObject ?: @"path";
    NSArray *rest = arguments.count > 1 ? [arguments subarrayWithRange:NSMakeRange(1, arguments.count - 1)] : @[];
    if ([action isEqualToString:@"path"]) {
        if (self.output.json) {
            [self.output jsonSuccessWithCommand:@"config" data:@{@"path": self.store.configURL.path}];
        } else {
            [self.output line:@"%@", self.store.configURL.path];
        }
        return NFCLIExitSuccess;
    }
    if ([action isEqualToString:@"export"]) {
        NSError *error = nil;
        NFConfig *config = [self loadConfig:&error];
        if (!config) {
            return [self failWithError:error command:@"config"];
        }
        NSString *destination = rest.firstObject;
        if (destination.length == 0 || [destination isEqualToString:@"-"]) {
            if (self.output.json) {
                [self.output jsonSuccessWithCommand:@"config" data:[config dictionaryRepresentation]];
            } else {
                NSError *jsonError = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:[config dictionaryRepresentation]
                                                               options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                                 error:&jsonError];
                if (!data) {
                    return [self failWithError:jsonError command:@"config"];
                }
                fwrite(data.bytes, 1, data.length, stdout);
                fputc('\n', stdout);
            }
            return NFCLIExitSuccess;
        }
        NSString *path = [self absolutePath:destination];
        NSData *data = [NSJSONSerialization dataWithJSONObject:[config dictionaryRepresentation]
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:&error];
        if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
            return [self failWithError:error ?: [NSError nf_errorWithCode:NFErrorConfigWriteFailed] command:@"config"];
        }
        if (self.output.json) {
            [self.output jsonSuccessWithCommand:@"config" data:@{@"path": path}];
        } else {
            [self.output line:@"Exported configuration to %@", path];
        }
        return NFCLIExitSuccess;
    }
    if ([action isEqualToString:@"import"]) {
        NSString *source = rest.firstObject;
        if (source.length == 0) {
            [self.output errorLine:@"%@", [NFCStrings usageForCommand:@"config"]];
            return NFCLIExitUsage;
        }
        NSString *path = [self absolutePath:source];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) {
            NSError *readError = [NSError nf_errorWithCode:NFErrorConfigCorrupt
                                              description:[NSString stringWithFormat:@"Could not read %@.", path]];
            return [self failWithError:readError command:@"config"];
        }
        NSError *jsonError = nil;
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (![object isKindOfClass:[NSDictionary class]]) {
            NSError *invalid = [NSError nf_errorWithCode:NFErrorConfigCorrupt
                                            description:jsonError.localizedDescription ?: @"The file is not a valid configuration."];
            return [self failWithError:invalid command:@"config"];
        }
        NFConfig *imported = [[NFConfig alloc] initWithDictionary:object];
        NSError *replaceError = nil;
        if (![self.store replaceConfig:imported error:&replaceError]) {
            return [self failWithError:replaceError command:@"config"];
        }
        if (self.output.json) {
            [self.output jsonSuccessWithCommand:@"config" data:@{@"imported": path, @"templates": @(imported.templates.count)}];
        } else {
            [self.output line:@"Imported %lu templates from %@.", (unsigned long)imported.templates.count, path];
        }
        return NFCLIExitSuccess;
    }
    if ([action isEqualToString:@"reset"]) {
        if (![rest containsObject:@"--yes"] && ![arguments containsObject:@"--yes"]) {
            [self.output errorLine:@"Refusing to reset without --yes."];
            return NFCLIExitUsage;
        }
        NSError *resetError = nil;
        if (![self.store replaceConfig:[NFConfig defaultConfig] error:&resetError]) {
            return [self failWithError:resetError command:@"config"];
        }
        if (self.output.json) {
            [self.output jsonSuccessWithCommand:@"config" data:@{@"reset": @YES}];
        } else {
            [self.output line:@"Configuration reset. Template files were kept."];
        }
        return NFCLIExitSuccess;
    }
    [self.output errorLine:@"%@", [NFCStrings usageForCommand:@"config"]];
    return NFCLIExitUsage;
}

- (int)runStatus:(NSArray<NSString *> *)arguments {
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"status"];
    }
    NSArray *running = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.sid.newfilecreation2"];
    NSString *cliPath = NSProcessInfo.processInfo.arguments.firstObject;
    NSString *homeLink = [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/nfc"];
    NSString *globalLink = @"/usr/local/bin/nfc";
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL homeInstalled = [fm fileExistsAtPath:homeLink];
    BOOL globalInstalled = [fm fileExistsAtPath:globalLink];
    NSInteger loginStatus = [self loginItemStatus];

    NSDictionary *status = @{
        @"version": NFCVersionString,
        @"schemaVersion": @(config.schemaVersion),
        @"revision": @(config.revision),
        @"configPath": self.store.configURL.path,
        @"templatesPath": self.store.templatesURL.path,
        @"templateCount": @(config.templates.count),
        @"enabledCount": @(config.enabledTemplates.count),
        @"favoriteCount": @(config.favoriteTemplates.count),
        @"defaultBaseName": [config stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName],
        @"defaultTemplateID": [config stringSettingForKey:@"defaultTemplateID" defaultValue:@""],
        @"appRunning": @(running.count > 0),
        @"finderExtension": [self finderExtensionStatus],
        @"loginItemStatus": @(loginStatus),
        @"globalShortcut": [config stringSettingForKey:@"globalShortcut" defaultValue:@""],
        @"cliPath": cliPath ?: @"",
        @"cliInstalledAtHome": @(homeInstalled),
        @"cliInstalledGlobally": @(globalInstalled)
    };

    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"status" data:status];
        return NFCLIExitSuccess;
    }
    [self.output line:@"New File Creation 2 %@", NFCVersionString];
    [self.output line:@"Config:        %@", status[@"configPath"]];
    [self.output line:@"Templates:     %@ templates (%@ enabled, %@ favorites)", status[@"templateCount"], status[@"enabledCount"], status[@"favoriteCount"]];
    [self.output line:@"Default name:  %@", status[@"defaultBaseName"]];
    [self.output line:@"App:           %@", [status[@"appRunning"] boolValue] ? @"running" : @"not running"];
    [self.output line:@"Finder:        %@", status[@"finderExtension"]];
    [self.output line:@"Login item:    %ld", (long)loginStatus];
    [self.output line:@"Shortcut:      %@", status[@"globalShortcut"]];
    [self.output line:@"CLI:           %@", status[@"cliPath"]];
    [self.output line:@"CLI links:     %@%@", homeInstalled ? @"~/.local/bin/nfc " : @"", globalInstalled ? @"/usr/local/bin/nfc" : @""];
    return NFCLIExitSuccess;
}

- (int)runOpen:(NSArray<NSString *> *)arguments {
    NSError *error = nil;
    NFConfig *config = [self loadConfig:&error];
    if (!config) {
        return [self failWithError:error command:@"open"];
    }
    NSURL *url = nil;
    if (arguments.count == 0) {
        url = self.store.templatesURL;
    } else {
        NFTemplate *template = [NFCCLIResolver resolveReference:arguments.firstObject inConfig:config error:&error];
        if (!template) {
            return [self failWithError:error command:@"open"];
        }
        url = [self.store templateFileURLForTemplate:template];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        NSError *missing = [NSError nf_errorWithCode:NFErrorTemplateMissing
                                         description:[NSString stringWithFormat:@"%@ does not exist.", url.path]];
        return [self failWithError:missing command:@"open"];
    }
    if (![[NSWorkspace sharedWorkspace] openURL:url]) {
        NSError *openError = [NSError nf_errorWithCode:NFErrorUnknown
                                           description:[NSString stringWithFormat:@"Could not open %@.", url.path]];
        return [self failWithError:openError command:@"open"];
    }
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"open" data:@{@"path": url.path}];
    } else if (!self.output.quiet) {
        [self.output line:@"Opened %@", url.path];
    }
    return NFCLIExitSuccess;
}

- (int)runDoctor:(NSArray<NSString *> *)arguments {
    NSMutableArray<NSDictionary *> *checks = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    void (^addCheck)(NSString *, NSString *, NSString *) = ^(NSString *name, NSString *status, NSString *message) {
        [checks addObject:@{@"name": name, @"status": status, @"message": message ?: @""}];
    };

    BOOL supportExists = [fm fileExistsAtPath:self.store.supportURL.path];
    addCheck(@"support-directory", supportExists ? @"ok" : @"fail",
             supportExists ? self.store.supportURL.path : @"The support folder is missing. Run the app or “nfc list” once.");

    NSError *readError = nil;
    NFConfig *config = [self.store loadConfigCreatingIfNeeded:NO error:&readError];
    if (config) {
        addCheck(@"config", @"ok", self.store.configURL.path);
    } else {
        addCheck(@"config", @"fail", readError.localizedDescription ?: @"The configuration could not be read.");
        config = [NFConfig defaultConfig];
    }

    if (config.schemaVersion <= NFCSchemaVersion) {
        addCheck(@"schema", @"ok", [NSString stringWithFormat:@"schema %ld, revision %ld", (long)config.schemaVersion, (long)config.revision]);
    } else {
        addCheck(@"schema", @"fail", @"The configuration schema is newer than this build.");
    }

    BOOL templatesExists = [fm fileExistsAtPath:self.store.templatesURL.path];
    addCheck(@"templates-directory", templatesExists ? @"ok" : @"warn",
             templatesExists ? self.store.templatesURL.path : @"The Templates folder does not exist yet.");

    NSUInteger missing = 0;
    for (NFTemplate *template in config.templates) {
        if (![fm fileExistsAtPath:[self.store templateFileURLForTemplate:template].path]) {
            missing += 1;
        }
    }
    addCheck(@"template-files", missing == 0 ? @"ok" : @"fail",
             missing == 0 ? [NSString stringWithFormat:@"%lu templates present", (unsigned long)config.templates.count]
                          : [NSString stringWithFormat:@"%lu template file(s) missing", (unsigned long)missing]);

    NSMutableSet *names = [NSMutableSet set];
    NSMutableSet *ids = [NSMutableSet set];
    NSUInteger duplicateNames = 0;
    NSUInteger duplicateIDs = 0;
    for (NFTemplate *template in config.templates) {
        if ([names containsObject:template.fileName.lowercaseString]) {
            duplicateNames += 1;
        }
        if ([ids containsObject:template.identifier.lowercaseString]) {
            duplicateIDs += 1;
        }
        [names addObject:template.fileName.lowercaseString];
        [ids addObject:template.identifier.lowercaseString];
    }
    addCheck(@"unique-names", duplicateNames == 0 ? @"ok" : @"warn",
             duplicateNames == 0 ? @"No duplicate file names" : [NSString stringWithFormat:@"%lu duplicate file name(s)", (unsigned long)duplicateNames]);
    addCheck(@"unique-ids", duplicateIDs == 0 ? @"ok" : @"fail",
             duplicateIDs == 0 ? @"No duplicate template IDs" : [NSString stringWithFormat:@"%lu duplicate ID(s)", (unsigned long)duplicateIDs]);

    BOOL appBundle = [fm fileExistsAtPath:@"/Applications/New File Creation 2.app"];
    addCheck(@"app-installed", appBundle ? @"ok" : @"warn",
             appBundle ? @"/Applications/New File Creation 2.app" : @"The app is not in /Applications.");

    NSString *finder = [self finderExtensionStatus];
    addCheck(@"finder-extension", [finder isEqualToString:@"enabled"] ? @"ok" : ([finder isEqualToString:@"not-registered"] ? @"warn" : @"warn"), finder);

    NSString *homeLink = [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/nfc"];
    NSString *globalLink = @"/usr/local/bin/nfc";
    BOOL linked = [fm fileExistsAtPath:homeLink] || [fm fileExistsAtPath:globalLink];
    addCheck(@"cli-link", linked ? @"ok" : @"warn",
             linked ? @"nfc is linked on PATH" : @"Install a symlink with scripts/install-cli.sh");

    NSInteger pass = 0, warn = 0, fail = 0;
    for (NSDictionary *check in checks) {
        if ([check[@"status"] isEqualToString:@"ok"]) pass++;
        else if ([check[@"status"] isEqualToString:@"warn"]) warn++;
        else fail++;
    }

    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"doctor" data:@{@"checks": checks, @"summary": @{@"pass": @(pass), @"warn": @(warn), @"fail": @(fail)}}];
    } else {
        for (NSDictionary *check in checks) {
            NSString *status = check[@"status"];
            NSString *mark = [status isEqualToString:@"ok"] ? @"OK  " : ([status isEqualToString:@"warn"] ? @"WARN" : @"FAIL");
    [self.output line:@"[%@] %@ — %@", mark, check[@"name"], check[@"message"]];
        }
        [self.output line:@""];
        [self.output line:@"%ld passed, %ld warnings, %ld failures", (long)pass, (long)warn, (long)fail];
    }
    return fail > 0 ? NFCLIExitGeneral : NFCLIExitSuccess;
}

- (int)runCompletion:(NSArray<NSString *> *)arguments {
    NSString *shell = arguments.firstObject.lowercaseString ?: @"zsh";
    NSString *script = nil;
    if ([shell isEqualToString:@"zsh"]) {
        script = @"#compdef nfc\n\n_nfc() {\n"
                 "  local -a commands\n"
                 "  commands=(\n"
                 "    'create:Create a file from a template'\n"
                 "    'list:List templates'\n"
                 "    'show:Show template details'\n"
                 "    'add:Add files as templates'\n"
                 "    'remove:Remove a template'\n"
                 "    'favorite:Toggle favorite'\n"
                 "    'enable:Enable a template'\n"
                 "    'disable:Disable a template'\n"
                 "    'recent:Show recent templates'\n"
                 "    'categories:Show categories'\n"
                 "    'config:Export, import, or reset configuration'\n"
                 "    'status:Show status'\n"
                 "    'open:Open a template'\n"
                 "    'doctor:Diagnose issues'\n"
                 "    'completion:Print completion'\n"
                 "    'help:Show help'\n"
                 "    'version:Show version'\n"
                 "  )\n"
                 "  _arguments '1:command:->command' '*::arg:->args'\n"
                 "  case $state in\n"
                 "    command) _describe 'command' commands ;;\n"
                 "    args) _files ;;\n"
                 "  esac\n"
                 "}\n\n_nfc \"$@\"\n";
    } else if ([shell isEqualToString:@"bash"]) {
        script = @"_nfc_completions() {\n"
                 "  local cur=\"${COMP_WORDS[COMP_CWORD]}\"\n"
                 "  local commands=\"create list show add remove favorite enable disable recent categories config status open doctor completion help version\"\n"
                 "  COMPREPLY=( $(compgen -W \"$commands\" -- \"$cur\") )\n"
                 "}\n"
                 "complete -F _nfc_completions nfc\n";
    } else {
        [self.output errorLine:@"Unsupported shell “%@”. Use zsh or bash.", shell];
        return NFCLIExitUsage;
    }
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"completion" data:@{@"shell": shell, @"script": script}];
    } else {
        fputs(script.UTF8String, stdout);
    }
    return NFCLIExitSuccess;
}

- (int)runImportLegacy:(NSArray<NSString *> *)arguments {
    NSError *error = nil;
    NSDictionary *result = [NFLegacyMigration migrateIntoStore:self.store error:&error];
    if (!result) {
        return [self failWithError:error command:@"import-legacy"];
    }
    if (self.output.json) {
        [self.output jsonSuccessWithCommand:@"import-legacy" data:result];
    } else {
        [self.output line:@"Imported %@ template(s) and %@ setting(s) from %lu legacy location(s).",
         result[@"templates"], result[@"settings"], (unsigned long)[result[@"sources"] count]];
    }
    return NFCLIExitSuccess;
}

@end

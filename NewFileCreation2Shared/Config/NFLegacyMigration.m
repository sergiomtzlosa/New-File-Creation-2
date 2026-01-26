#import "NFLegacyMigration.h"
#import "NFErrors.h"
#import "NFTemplate.h"
#import "NFLogger.h"

static NSString *NFStringValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL NFBoolValue(id value) {
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

@implementation NFLegacyMigration

+ (NSArray<NSURL *> *)legacyDirectories {
    NSMutableArray<NSURL *> *directories = [NSMutableArray array];
    NSString *home = NSHomeDirectory();
    NSArray<NSString *> *relativePaths = @[
        @"Library/Group Containers/9Z3J82KRJR.com.sergiomtzlosa.filecreation/NewFileCreation",
        @"Library/Containers/com.sergiomtzlosa.filecreation/Data/Library/Application Support/NewFileCreation",
        @"Library/Application Support/NewFileCreation"
    ];
    for (NSString *relative in relativePaths) {
        NSURL *url = [NSURL fileURLWithPath:[home stringByAppendingPathComponent:relative] isDirectory:YES];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDir] && isDir) {
            [directories addObject:url];
        }
    }
    return directories;
}

+ (BOOL)hasLegacyData {
    for (NSURL *directory in [self legacyDirectories]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[directory URLByAppendingPathComponent:@"templates_prefs.plist"].path]) {
            return YES;
        }
    }
    return NO;
}

+ (NSDictionary<NSString *, id> *)applicationPreferencesInDirectory:(NSURL *)directory {
    NSURL *url = [directory URLByAppendingPathComponent:@"application_prefs.plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:url];
    return [dict isKindOfClass:[NSDictionary class]] ? dict : @{};
}

+ (NSArray<NSDictionary *> *)templatePreferencesInDirectory:(NSURL *)directory {
    NSURL *url = [directory URLByAppendingPathComponent:@"templates_prefs.plist"];
    NSArray *array = [NSArray arrayWithContentsOfURL:url];
    if (![array isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (id entry in array) {
        if ([entry isKindOfClass:[NSDictionary class]]) {
            [result addObject:entry];
        }
    }
    return result;
}

+ (NSDictionary<NSString *, id> *)migrateIntoStore:(NFConfigStore *)store error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSURL *> *sources = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    NSDictionary *applicationPreferences = @{};

    for (NSURL *directory in [self legacyDirectories]) {
        NSArray<NSDictionary *> *found = [self templatePreferencesInDirectory:directory];
        if (found.count > 0) {
            [sources addObject:directory];
            [entries addObjectsFromArray:found];
        }
        if (applicationPreferences.count == 0) {
            NSDictionary *prefs = [self applicationPreferencesInDirectory:directory];
            if (prefs.count > 0) {
                applicationPreferences = prefs;
            }
        }
    }

    if (sources.count == 0 && applicationPreferences.count == 0) {
        return @{@"templates": @0, @"settings": @0, @"sources": @[]};
    }

    __block NSUInteger importedTemplates = 0;
    __block NSUInteger importedSettings = 0;
    NSError *updateError = nil;
    BOOL success = [store updateConfig:^BOOL(NFConfig *config, NSError **blockError) {
        NSInteger sortIndex = (NSInteger)config.templates.count;
        for (NSURL *sourceDirectory in sources) {
            NSArray<NSDictionary *> *templateEntries = [self templatePreferencesInDirectory:sourceDirectory];
            for (NSDictionary *entry in templateEntries) {
                NSString *fileName = NFStringValue(entry[@"templateColumn"]);
                if (fileName.length == 0) {
                    fileName = NFStringValue(entry[@"file"]);
                }
                if (fileName.length == 0 || [config templateWithFileName:fileName]) {
                    continue;
                }
                NSURL *sourceURL = [sourceDirectory URLByAppendingPathComponent:fileName];
                if (![fm fileExistsAtPath:sourceURL.path]) {
                    continue;
                }
                NSURL *destinationURL = [store.templatesURL URLByAppendingPathComponent:fileName];
                if (![fm fileExistsAtPath:destinationURL.path]) {
                    NSError *copyError = nil;
                    if (![fm copyItemAtURL:sourceURL toURL:destinationURL error:&copyError]) {
                        [[NFLogger sharedLogger] error:@"Migration could not copy %@: %@", fileName, copyError.localizedDescription];
                        continue;
                    }
                }
                NFTemplate *template = [NFTemplate templateWithFileName:fileName];
                template.identifier = NSUUID.UUID.UUIDString;
                template.displayName = NFStringValue(entry[@"displayName"]) ?: [NFTemplate displayNameForFileName:fileName];
                template.category = [NFTemplate inferCategoryForFileExtension:fileName.pathExtension];
                template.enabled = NFBoolValue(entry[@"enableColumn"]) || NFBoolValue(entry[@"active"]);
                template.favorite = NFBoolValue(entry[@"favorite"]);
                template.sortIndex = sortIndex++;
                template.source = @"migrated";
                template.createdAt = [NSDate date];
                [config.templates addObject:template];
                importedTemplates += 1;
            }
        }

        if (applicationPreferences.count > 0) {
            id value = applicationPreferences[@"soundEnabled"];
            if (value) {
                [config setSetting:@(NFBoolValue(value)) forKey:@"playSound"];
                importedSettings += 1;
            }
            value = applicationPreferences[@"revealOnCreation"] ?: applicationPreferences[@"reavealInFinder"];
            if (value) {
                [config setSetting:@(NFBoolValue(value)) forKey:@"revealAfterCreate"];
                importedSettings += 1;
            }
            value = applicationPreferences[@"openOncreation"] ?: applicationPreferences[@"openFileWhenCreated"];
            if (value) {
                [config setSetting:@(NFBoolValue(value)) forKey:@"openAfterCreate"];
                importedSettings += 1;
            }
        }
        [config setSetting:@YES forKey:@"didSeedBundledTemplates"];
        [config setSetting:@YES forKey:@"onboardingCompleted"];
        if ([[config stringSettingForKey:@"defaultTemplateID" defaultValue:@""] length] == 0 && config.templates.count > 0) {
            [config setSetting:config.templates.firstObject.identifier forKey:@"defaultTemplateID"];
        }
        return YES;
    } error:&updateError];

    if (!success) {
        if (error) {
            *error = updateError ?: [NSError nf_errorWithCode:NFErrorMigrationFailed];
        }
        return @{@"templates": @0, @"settings": @0, @"sources": @[]};
    }

    [[NFLogger sharedLogger] info:@"Migrated %lu templates and %lu settings from %lu legacy folders",
                            (unsigned long)importedTemplates, (unsigned long)importedSettings, (unsigned long)sources.count];
    return @{
        @"templates": @(importedTemplates),
        @"settings": @(importedSettings),
        @"sources": [sources valueForKey:@"path"]
    };
}

@end

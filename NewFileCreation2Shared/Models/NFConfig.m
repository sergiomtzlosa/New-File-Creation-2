#import "NFConfig.h"
#import "NFVersion.h"
#import "NFErrors.h"

static NSDictionary<NSString *, id> *NFDefaultSettings(void) {
    return @{
        @"defaultBaseName": NFDefaultBaseName,
        @"defaultTemplateID": @"",
        @"defaultDirectory": @"",
        @"revealAfterCreate": @YES,
        @"openAfterCreate": @NO,
        @"playSound": @NO,
        @"soundName": @"Glass",
        @"showToast": @YES,
        @"keepQuickPanelOpenAfterDrop": @NO,
        @"launchAtLogin": @NO,
        @"showMenuBarIcon": @YES,
        @"globalShortcut": @"control+option+n",
        @"favoritesFirst": @YES,
        @"groupByCategory": @NO,
        @"showFileIcons": @YES,
        @"includeNewFileInFinderMenu": @YES,
        @"includeAddAsTemplate": @YES,
        @"finderCreationBehavior": @"instant",
        @"sortMode": @"manual",
        @"logLevel": @"info",
        @"onboardingCompleted": @NO,
        @"lastUsedDirectory": @"",
        @"customCategories": @[],
        @"didSeedBundledTemplates": @NO
    };
}

@implementation NFConfig

+ (instancetype)defaultConfig {
    NFConfig *config = [[self alloc] init];
    config.schemaVersion = NFCSchemaVersion;
    config.revision = 0;
    config.updatedAt = [NSDate date];
    config.settings = [NFDefaultSettings() mutableCopy];
    config.templates = [NSMutableArray array];
    config.recentTemplateIDs = [NSMutableArray array];
    config.recentFiles = [NSMutableArray array];
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _schemaVersion = NFCSchemaVersion;
        _revision = 0;
        _updatedAt = [NSDate date];
        _settings = [NFDefaultSettings() mutableCopy];
        _templates = [NSMutableArray array];
        _recentTemplateIDs = [NSMutableArray array];
        _recentFiles = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary {
    self = [self init];
    if (!self) {
        return nil;
    }
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return self;
    }

    id schema = dictionary[@"schemaVersion"];
    if ([schema respondsToSelector:@selector(integerValue)]) {
        _schemaVersion = [schema integerValue];
    }
    id revision = dictionary[@"revision"];
    if ([revision respondsToSelector:@selector(integerValue)]) {
        _revision = [revision integerValue];
    }
    id updatedAt = dictionary[@"updatedAt"];
    if ([updatedAt isKindOfClass:[NSString class]]) {
        static NSISO8601DateFormatter *formatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSISO8601DateFormatter alloc] init];
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        });
        _updatedAt = [formatter dateFromString:updatedAt] ?: [NSDate date];
    }

    id settings = dictionary[@"settings"];
    if ([settings isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *merged = [NFDefaultSettings() mutableCopy];
        [(NSDictionary *)settings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && value && value != [NSNull null]) {
                merged[key] = value;
            }
        }];
        _settings = merged;
    }

    id templates = dictionary[@"templates"];
    if ([templates isKindOfClass:[NSArray class]]) {
        _templates = [NSMutableArray array];
        for (id entry in (NSArray *)templates) {
            if ([entry isKindOfClass:[NSDictionary class]]) {
                NFTemplate *template = [[NFTemplate alloc] initWithDictionary:entry];
                if (template.fileName.length > 0) {
                    [_templates addObject:template];
                }
            }
        }
        [_templates sortUsingComparator:^NSComparisonResult(NFTemplate *a, NFTemplate *b) {
            if (a.sortIndex != b.sortIndex) {
                return a.sortIndex < b.sortIndex ? NSOrderedAscending : NSOrderedDescending;
            }
            return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
        }];
    }

    id recentTemplateIDs = dictionary[@"recentTemplateIDs"];
    if ([recentTemplateIDs isKindOfClass:[NSArray class]]) {
        _recentTemplateIDs = [NSMutableArray array];
        for (id value in (NSArray *)recentTemplateIDs) {
            if ([value isKindOfClass:[NSString class]]) {
                [_recentTemplateIDs addObject:value];
            }
        }
    }

    id recentFiles = dictionary[@"recentFiles"];
    if ([recentFiles isKindOfClass:[NSArray class]]) {
        _recentFiles = [NSMutableArray array];
        for (id value in (NSArray *)recentFiles) {
            if ([value isKindOfClass:[NSString class]]) {
                [_recentFiles addObject:value];
            }
        }
    }
    return self;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });

    NSMutableArray *templateDicts = [NSMutableArray arrayWithCapacity:self.templates.count];
    for (NFTemplate *template in self.templates) {
        [templateDicts addObject:[template dictionaryRepresentation]];
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"schemaVersion"] = @(self.schemaVersion);
    dict[@"revision"] = @(self.revision);
    dict[@"updatedAt"] = [formatter stringFromDate:self.updatedAt ?: [NSDate date]];
    dict[@"settings"] = self.settings ?: NFDefaultSettings();
    dict[@"templates"] = templateDicts;
    dict[@"recentTemplateIDs"] = self.recentTemplateIDs ?: @[];
    dict[@"recentFiles"] = self.recentFiles ?: @[];
    return dict;
}

- (NFTemplate *)templateWithIdentifier:(NSString *)identifier {
    if (identifier.length == 0) {
        return nil;
    }
    for (NFTemplate *template in self.templates) {
        if ([template.identifier caseInsensitiveCompare:identifier] == NSOrderedSame) {
            return template;
        }
    }
    return nil;
}

- (NFTemplate *)templateWithFileName:(NSString *)fileName {
    for (NFTemplate *template in self.templates) {
        if ([template.fileName isEqualToString:fileName]) {
            return template;
        }
    }
    return nil;
}

- (NSArray<NFTemplate *> *)enabledTemplates {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NFTemplate *template, NSDictionary *bindings) {
        return template.enabled;
    }];
    return [self.templates filteredArrayUsingPredicate:predicate];
}

- (NSArray<NFTemplate *> *)favoriteTemplates {
    NSMutableArray *favorites = [NSMutableArray array];
    for (NFTemplate *template in self.templates) {
        if (template.favorite) {
            [favorites addObject:template];
        }
    }
    return favorites;
}

- (NSArray<NSString *> *)categories {
    NSMutableOrderedSet<NSString *> *categories = [NSMutableOrderedSet orderedSet];
    for (NSString *category in [self customCategories]) {
        [categories addObject:category];
    }
    for (NFTemplate *template in self.templates) {
        NSString *category = template.category.length > 0 ? template.category : NFDefaultCategoryOther;
        [categories addObject:category];
    }
    NSMutableArray *result = [categories.array mutableCopy];
    [result sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return result;
}

- (NSArray<NSString *> *)customCategories {
    id stored = self.settings[@"customCategories"];
    if (![stored isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableOrderedSet<NSString *> *unique = [NSMutableOrderedSet orderedSet];
    for (id value in (NSArray *)stored) {
        if (![value isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *name = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length > 0) {
            [unique addObject:name];
        }
    }
    return unique.array;
}

- (BOOL)addCustomCategory:(NSString *)category {
    NSString *name = [category stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        return NO;
    }
    for (NSString *existing in [self categories]) {
        if ([existing localizedCaseInsensitiveCompare:name] == NSOrderedSame) {
            return NO;
        }
    }
    NSMutableArray<NSString *> *custom = [[self customCategories] mutableCopy];
    [custom addObject:name];
    [self setSetting:custom forKey:@"customCategories"];
    return YES;
}

- (BOOL)removeCustomCategory:(NSString *)category {
    NSString *name = [category stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        return NO;
    }
    NSMutableArray<NSString *> *custom = [[self customCategories] mutableCopy];
    NSInteger match = -1;
    for (NSUInteger index = 0; index < custom.count; index++) {
        if ([custom[index] localizedCaseInsensitiveCompare:name] == NSOrderedSame) {
            match = (NSInteger)index;
            break;
        }
    }
    if (match < 0) {
        return NO;
    }
    [custom removeObjectAtIndex:(NSUInteger)match];
    [self setSetting:custom forKey:@"customCategories"];
    for (NFTemplate *template in self.templates) {
        if ([template.category localizedCaseInsensitiveCompare:name] == NSOrderedSame) {
            template.category = NFDefaultCategoryOther;
        }
    }
    return YES;
}

- (BOOL)removeCategory:(NSString *)category {
    NSString *name = [category stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        return NO;
    }
    BOOL found = [self removeCustomCategory:name];
    for (NFTemplate *template in self.templates) {
        if ([template.category localizedCaseInsensitiveCompare:name] == NSOrderedSame) {
            template.category = NFDefaultCategoryOther;
            found = YES;
        }
    }
    return found;
}


- (id)settingForKey:(NSString *)key {
    return self.settings[key];
}

- (BOOL)boolSettingForKey:(NSString *)key defaultValue:(BOOL)defaultValue {
    id value = self.settings[key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : defaultValue;
}

- (NSString *)stringSettingForKey:(NSString *)key defaultValue:(NSString *)defaultValue {
    id value = self.settings[key];
    return [value isKindOfClass:[NSString class]] ? value : defaultValue;
}

- (NSInteger)integerSettingForKey:(NSString *)key defaultValue:(NSInteger)defaultValue {
    id value = self.settings[key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : defaultValue;
}

- (void)setSetting:(id)value forKey:(NSString *)key {
    if (!self.settings) {
        self.settings = [NSMutableDictionary dictionary];
    }
    self.settings[key] = value ?: @"";
}

- (void)recordUsageOfTemplate:(NFTemplate *)template {
    if (!template) {
        return;
    }
    template.useCount += 1;
    template.lastUsedAt = [NSDate date];
    [self.recentTemplateIDs removeObject:template.identifier];
    [self.recentTemplateIDs insertObject:template.identifier atIndex:0];
    while (self.recentTemplateIDs.count > 8) {
        [self.recentTemplateIDs removeLastObject];
    }
}

- (void)addRecentFile:(NSString *)path {
    if (path.length == 0) {
        return;
    }
    [self.recentFiles removeObject:path];
    [self.recentFiles insertObject:path atIndex:0];
    while (self.recentFiles.count > 10) {
        [self.recentFiles removeLastObject];
    }
}

@end

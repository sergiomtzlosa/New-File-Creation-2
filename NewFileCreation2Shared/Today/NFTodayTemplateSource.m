#import "NFTodayTemplateSource.h"
#import "NFFinderMenuBuilder.h"
#import "NFVersion.h"
#import <pwd.h>
#import <unistd.h>

static NSString *NFTodayRealHomeDirectory(void) {
    struct passwd *pw = getpwuid(getuid());
    if (pw && pw->pw_dir) {
        return [NSString stringWithUTF8String:pw->pw_dir];
    }
    return NSHomeDirectory();
}

@interface NFTodayTemplateSource ()
@property (nonatomic, strong, readwrite) NSURL *supportDirectory;
@property (nonatomic, copy, readwrite) NSArray<NFTemplate *> *templates;
@property (nonatomic, strong, nullable) NFConfig *config;
@end

@implementation NFTodayTemplateSource

+ (NSURL *)defaultSupportDirectory {
    return [[NSURL fileURLWithPath:NFTodayRealHomeDirectory() isDirectory:YES]
            URLByAppendingPathComponent:@"Library/Application Support/New File Creation 2"
                             isDirectory:YES];
}

- (instancetype)init {
    return [self initWithSupportDirectory:[[self class] defaultSupportDirectory]];
}

- (instancetype)initWithSupportDirectory:(NSURL *)supportDirectory {
    self = [super init];
    if (self) {
        _supportDirectory = [supportDirectory copy];
        _templates = @[];
    }
    return self;
}

- (nullable NSDictionary<NSString *, id> *)readConfigDictionary {
    NSURL *url = [self.supportDirectory URLByAppendingPathComponent:@"config.json" isDirectory:NO];
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (!data) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *dictionary = object;
    id schemaValue = dictionary[@"schemaVersion"];
    NSInteger schema = [schemaValue respondsToSelector:@selector(integerValue)] ? [schemaValue integerValue] : 1;
    if (schema > NFCSchemaVersion) {
        return nil;
    }
    return dictionary;
}

- (NSArray<NFTemplate *> *)reloadTemplates {
    NSDictionary *dictionary = [self readConfigDictionary];
    if (!dictionary) {
        self.config = nil;
        self.templates = @[];
        return self.templates;
    }
    self.config = [[NFConfig alloc] initWithDictionary:dictionary];
    NFTemplateSortMode sortMode = [NFFinderMenuBuilder sortModeForConfig:self.config];
    NSArray<NFTemplate *> *enabled = self.config.enabledTemplates;
    self.templates = [enabled sortedArrayUsingComparator:^NSComparisonResult(NFTemplate *a, NFTemplate *b) {
        if (a.favorite != b.favorite) {
            return a.favorite ? NSOrderedAscending : NSOrderedDescending;
        }
        return [NFFinderMenuBuilder compareTemplate:a toTemplate:b sortMode:sortMode];
    }];
    return self.templates;
}

- (NSString *)defaultBaseName {
    if (self.config) {
        return [self.config stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName];
    }
    NSDictionary *dictionary = [self readConfigDictionary];
    if (dictionary) {
        self.config = [[NFConfig alloc] initWithDictionary:dictionary];
        return [self.config stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName];
    }
    return NFDefaultBaseName;
}

- (NSURL *)templateURLForTemplate:(NFTemplate *)template {
    NSURL *templates = [self.supportDirectory URLByAppendingPathComponent:@"Templates" isDirectory:YES];
    if (template.fileName.length == 0) {
        return templates;
    }
    return [templates URLByAppendingPathComponent:template.fileName isDirectory:NO];
}

@end

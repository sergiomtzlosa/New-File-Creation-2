#import "NFTestSupport.h"
#import "NFTodayTemplateSource.h"
#import "NFFinderMenuBuilder.h"
#import "NFConfig.h"
#import "NFTemplate.h"

@interface NFTodayTemplateSourceTests : NFTestCase
@end

@implementation NFTodayTemplateSourceTests

- (NSURL *)writeConfigWithTemplates:(NSArray<NFTemplate *> *)templates
                          sortMode:(NSString *)sortMode
                     defaultName:(NSString *)defaultName {
    NFConfig *config = [NFConfig defaultConfig];
    config.templates = [templates mutableCopy];
    [config setSetting:sortMode forKey:@"sortMode"];
    [config setSetting:defaultName forKey:@"defaultBaseName"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:[config dictionaryRepresentation]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];
    NSURL *configURL = [self.temporaryDirectory URLByAppendingPathComponent:@"config.json"];
    [data writeToURL:configURL atomically:YES];
    return configURL;
}

- (NFTemplate *)templateNamed:(NSString *)fileName
                     category:(NSString *)category
                    sortIndex:(NSInteger)sortIndex
                     favorite:(BOOL)favorite
                      enabled:(BOOL)enabled {
    NFTemplate *template = [NFTemplate templateWithFileName:fileName];
    template.category = category;
    template.sortIndex = sortIndex;
    template.favorite = favorite;
    template.enabled = enabled;
    return template;
}

- (void)testSourceReadsEnabledTemplatesAndPromisesTheDefaultName {
    NFTemplate *text = [self templateNamed:@"TextFile.txt" category:@"Documents" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *swift = [self templateNamed:@"Snippet.swift" category:@"Code" sortIndex:1 favorite:YES enabled:YES];
    NFTemplate *disabled = [self templateNamed:@"Hidden.md" category:@"Other" sortIndex:2 favorite:NO enabled:NO];
    [self writeConfigWithTemplates:@[text, swift, disabled] sortMode:@"name" defaultName:@"Draft"];

    NSURL *templates = [self makeDirectoryNamed:@"Templates"];
    [self writeFileNamed:@"TextFile.txt" contents:@"text" inDirectory:templates];
    [self writeFileNamed:@"Snippet.swift" contents:@"code" inDirectory:templates];

    NFTodayTemplateSource *source = [[NFTodayTemplateSource alloc] initWithSupportDirectory:self.temporaryDirectory];
    NSArray<NFTemplate *> *loaded = [source reloadTemplates];
    XCTAssertEqual(loaded.count, 2u);
    XCTAssertEqualObjects(loaded.firstObject, swift, @"Favorites stay first in the widget");
    XCTAssertEqualObjects(loaded.lastObject, text);
    XCTAssertEqualObjects([source defaultBaseName], @"Draft");
    XCTAssertTrue([[source templateURLForTemplate:text].path hasSuffix:@"Templates/TextFile.txt"]);
}

- (void)testSourceUsesThePersistedCategoryAndFileTypeSortModes {
    NFTemplate *zeta = [self templateNamed:@"Zeta.md" category:@"Work" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *alpha = [self templateNamed:@"Alpha.txt" category:@"Home" sortIndex:1 favorite:NO enabled:YES];
    NFTemplate *beta = [self templateNamed:@"Beta.swift" category:@"Home" sortIndex:2 favorite:NO enabled:YES];
    [self writeConfigWithTemplates:@[zeta, alpha, beta] sortMode:@"category" defaultName:@"Untitled"];

    NFTodayTemplateSource *source = [[NFTodayTemplateSource alloc] initWithSupportDirectory:self.temporaryDirectory];
    XCTAssertEqualObjects([source reloadTemplates], (@[alpha, beta, zeta]));

    [self writeConfigWithTemplates:@[zeta, alpha, beta] sortMode:@"fileType" defaultName:@"Untitled"];
    XCTAssertEqualObjects([source reloadTemplates], (@[zeta, beta, alpha]));
}

- (void)testSourceHandlesMissingAndDamagedConfigurationWithoutWriting {
    NFTodayTemplateSource *source = [[NFTodayTemplateSource alloc] initWithSupportDirectory:self.temporaryDirectory];
    XCTAssertEqual([source reloadTemplates].count, 0u);
    XCTAssertEqualObjects([source defaultBaseName], NFDefaultBaseName);

    [[@"not json" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:
        [self.temporaryDirectory URLByAppendingPathComponent:@"config.json"] atomically:YES];
    XCTAssertEqual([source reloadTemplates].count, 0u);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:
        [self.temporaryDirectory URLByAppendingPathComponent:@"Backups"].path]);
}

@end

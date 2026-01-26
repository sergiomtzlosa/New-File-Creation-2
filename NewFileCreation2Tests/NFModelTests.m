#import "NFTestSupport.h"
#import "NFTemplate.h"
#import "NFConfig.h"

@interface NFModelTests : NFTestCase
@end

@implementation NFModelTests

- (void)testDisplayNameHeuristics {
    XCTAssertEqualObjects([NFTemplate displayNameForFileName:@"TextFile.txt"], @"Text File");
    XCTAssertEqualObjects([NFTemplate displayNameForFileName:@"file.jsp"], @"JSP Page");
    XCTAssertEqualObjects([NFTemplate displayNameForFileName:@"RTFDocument.rtfd"], @"Rich Text");
    XCTAssertEqualObjects([NFTemplate displayNameForFileName:@"HTML5.html"], @"HTML5 Page");
    XCTAssertEqualObjects([NFTemplate displayNameForFileName:@"MyNotes.md"], @"My Notes");
    XCTAssertEqualObjects([NFTemplate displayNameForFileName:@"Makefile"], @"Makefile");
}

- (void)testCategoryInference {
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"txt"], @"Documents");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"RTF"], @"Documents");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"swift"], @"Code");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"png"], @"Images");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"csv"], @"Spreadsheets");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"zip"], @"Archives");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@"unknown"], @"Other");
    XCTAssertEqualObjects([NFTemplate inferCategoryForFileExtension:@""], @"Other");
}

- (void)testTemplateRoundTrip {
    NFTemplate *template = [NFTemplate templateWithFileName:@"Snippet.swift"];
    template.identifier = @"11111111-1111-1111-1111-111111111111";
    template.displayName = @"Swift Snippet";
    template.category = @"Code";
    template.favorite = YES;
    template.useCount = 4;
    template.notes = @"A reusable snippet";
    template.enabled = NO;

    NSDictionary *dictionary = [template dictionaryRepresentation];
    NFTemplate *restored = [[NFTemplate alloc] initWithDictionary:dictionary];

    XCTAssertEqualObjects(restored.identifier, template.identifier);
    XCTAssertEqualObjects(restored.fileName, @"Snippet.swift");
    XCTAssertEqualObjects(restored.resolvedDisplayName, @"Swift Snippet");
    XCTAssertEqualObjects(restored.category, @"Code");
    XCTAssertEqualObjects(restored.fileExtension, @"swift");
    XCTAssertTrue(restored.favorite);
    XCTAssertFalse(restored.enabled);
    XCTAssertEqual(restored.useCount, 4);
    XCTAssertEqualObjects(restored.notes, @"A reusable snippet");
}

- (void)testResolvedDisplayNameFallsBackToFileName {
    NFTemplate *template = [[NFTemplate alloc] init];
    template.fileName = @"TextFile.txt";
    template.displayName = @"";
    XCTAssertEqualObjects(template.resolvedDisplayName, @"Text File");
}

- (void)testConfigRoundTripAndSettings {
    NFConfig *config = [NFConfig defaultConfig];
    XCTAssertEqualObjects([config stringSettingForKey:@"defaultBaseName" defaultValue:@""], NFDefaultBaseName);
    XCTAssertTrue([config boolSettingForKey:@"revealAfterCreate" defaultValue:NO]);
    XCTAssertFalse([config boolSettingForKey:@"openAfterCreate" defaultValue:YES]);

    [config setSetting:@"Draft" forKey:@"defaultBaseName"];
    [config setSetting:@YES forKey:@"openAfterCreate"];

    NFTemplate *template = [NFTemplate templateWithFileName:@"Notes.md"];
    template.identifier = @"22222222-2222-2222-2222-222222222222";
    template.sortIndex = 2;
    [config.templates addObject:template];
    [config recordUsageOfTemplate:template];
    [config addRecentFile:@"/tmp/Notes.md"];

    NFConfig *restored = [[NFConfig alloc] initWithDictionary:[config dictionaryRepresentation]];
    XCTAssertEqualObjects([restored stringSettingForKey:@"defaultBaseName" defaultValue:@""], @"Draft");
    XCTAssertTrue([restored boolSettingForKey:@"openAfterCreate" defaultValue:NO]);
    XCTAssertEqual(restored.templates.count, 1);
    XCTAssertEqualObjects(restored.templates.firstObject.identifier, template.identifier);
    XCTAssertEqual(restored.templates.firstObject.useCount, 1);
    XCTAssertEqualObjects(restored.recentTemplateIDs.firstObject, template.identifier);
    XCTAssertEqualObjects(restored.recentFiles.firstObject, @"/tmp/Notes.md");
}

- (void)testEnabledAndFavoriteFiltering {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *enabledFavorite = [NFTemplate templateWithFileName:@"A.txt"];
    enabledFavorite.favorite = YES;
    NFTemplate *enabled = [NFTemplate templateWithFileName:@"B.txt"];
    NFTemplate *disabled = [NFTemplate templateWithFileName:@"C.txt"];
    disabled.enabled = NO;
    [config.templates addObjectsFromArray:@[enabledFavorite, enabled, disabled]];

    XCTAssertEqual(config.enabledTemplates.count, 2);
    XCTAssertEqual(config.favoriteTemplates.count, 1);
    XCTAssertEqualObjects(config.categories, (@[@"Documents"]));
}

- (void)testRecentUsageIsBoundedAndDeduplicated {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *template = [NFTemplate templateWithFileName:@"TextFile.txt"];
    [config.templates addObject:template];
    for (NSInteger index = 0; index < 12; index++) {
        [config recordUsageOfTemplate:template];
    }
    XCTAssertEqual(template.useCount, 12);
    XCTAssertEqual(config.recentTemplateIDs.count, 1);
    XCTAssertEqualObjects(config.recentTemplateIDs.firstObject, template.identifier);
}

@end

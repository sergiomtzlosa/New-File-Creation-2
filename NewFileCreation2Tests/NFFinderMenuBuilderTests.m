#import "NFTestSupport.h"
#import "NFFinderMenuBuilder.h"
#import "NFConfig.h"
#import "NFTemplate.h"

@interface NFFinderMenuBuilderTests : NFTestCase
@end

@implementation NFFinderMenuBuilderTests

- (NFTemplate *)templateWithName:(NSString *)fileName
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

- (void)testMenuOnlyContainsEnabledTemplates {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *text = [self templateWithName:@"TextFile.txt" category:@"Documents" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *code = [self templateWithName:@"Snippet.swift" category:@"Code" sortIndex:1 favorite:NO enabled:NO];
    [config.templates addObjectsFromArray:@[text, code]];

    NSMenu *menu = [NFFinderMenuBuilder menuForConfig:config target:nil action:@selector(noop:) options:NFFinderMenuOptionNone];
    XCTAssertEqual(menu.numberOfItems, 1);
    XCTAssertEqualObjects(menu.itemArray.firstObject.representedObject, text.identifier);
    XCTAssertEqualObjects(menu.itemArray.firstObject.title, @"New Text File");
}

- (void)testFavoritesAreSortedFirst {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *regular = [self templateWithName:@"Regular.txt" category:@"Documents" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *favorite = [self templateWithName:@"Favorite.txt" category:@"Documents" sortIndex:1 favorite:YES enabled:YES];
    [config.templates addObjectsFromArray:@[regular, favorite]];

    NSArray *ordered = [NFFinderMenuBuilder orderedTemplatesForConfig:config favoritesFirst:YES];
    XCTAssertEqualObjects(ordered.firstObject, favorite);
    XCTAssertEqualObjects(ordered.lastObject, regular);
}

- (void)testGroupingByCategoryCreatesSubmenus {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *text = [self templateWithName:@"TextFile.txt" category:@"Documents" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *swift = [self templateWithName:@"Snippet.swift" category:@"Code" sortIndex:1 favorite:NO enabled:YES];
    NFTemplate *favorite = [self templateWithName:@"Favorite.txt" category:@"Documents" sortIndex:2 favorite:YES enabled:YES];
    [config.templates addObjectsFromArray:@[text, swift, favorite]];

    NSMenu *menu = [NFFinderMenuBuilder menuForConfig:config
                                               target:nil
                                               action:@selector(noop:)
                                              options:NFFinderMenuOptionFavoritesFirst | NFFinderMenuOptionGroupByCategory];
    XCTAssertEqual(menu.numberOfItems, 4);
    XCTAssertEqualObjects(menu.itemArray[0].title, @"New Favorite");
    XCTAssertTrue(menu.itemArray[1].isSeparatorItem);
    XCTAssertEqualObjects(menu.itemArray[2].title, @"Code");
    XCTAssertTrue(menu.itemArray[2].hasSubmenu);
    XCTAssertEqualObjects(menu.itemArray[3].title, @"Documents");
    XCTAssertEqual(menu.itemArray[3].submenu.numberOfItems, 1);
}

- (void)testEmptyConfigShowsDisabledPlaceholder {
    NFConfig *config = [NFConfig defaultConfig];
    NSMenu *menu = [NFFinderMenuBuilder menuForConfig:config target:nil action:@selector(noop:) options:NFFinderMenuOptionNone];
    XCTAssertEqual(menu.numberOfItems, 1);
    XCTAssertEqualObjects(menu.itemArray.firstObject.title, @"No Templates");
    XCTAssertFalse(menu.itemArray.firstObject.enabled);
}

@end

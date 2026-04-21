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

    NSMenu *menu = [NFFinderMenuBuilder menuForConfig:config target:nil action:NSSelectorFromString(@"noop:") options:NFFinderMenuOptionNone];
    XCTAssertEqual(menu.numberOfItems, 1);
    XCTAssertEqualObjects(menu.itemArray.firstObject.representedObject, text.identifier);
    XCTAssertEqual(menu.itemArray.firstObject.tag, 1);
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
                                               action:NSSelectorFromString(@"noop:")
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
    NSMenu *menu = [NFFinderMenuBuilder menuForConfig:config target:nil action:NSSelectorFromString(@"noop:") options:NFFinderMenuOptionNone];
    XCTAssertEqual(menu.numberOfItems, 1);
    XCTAssertEqualObjects(menu.itemArray.firstObject.title, @"No Templates");
    XCTAssertFalse(menu.itemArray.firstObject.enabled);
}

- (void)testSortModesOrderByNameCategoryAndFileType {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *zeta = [self templateWithName:@"Zeta.md" category:@"Work" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *alpha = [self templateWithName:@"Alpha.txt" category:@"Home" sortIndex:1 favorite:NO enabled:YES];
    NFTemplate *beta = [self templateWithName:@"Beta.swift" category:@"Home" sortIndex:2 favorite:NO enabled:YES];
    [config.templates addObjectsFromArray:@[zeta, alpha, beta]];
    [config setSetting:@"name" forKey:@"sortMode"];

    NSArray<NFTemplate *> *byName = [NFFinderMenuBuilder orderedTemplatesForConfig:config favoritesFirst:NO];
    XCTAssertEqualObjects(byName, (@[alpha, beta, zeta]));

    [config setSetting:@"category" forKey:@"sortMode"];
    NSArray<NFTemplate *> *byCategory = [NFFinderMenuBuilder orderedTemplatesForConfig:config favoritesFirst:NO];
    XCTAssertEqualObjects(byCategory, (@[alpha, beta, zeta]),
                          @"Templates are grouped by category, then sorted by display name");

    [config setSetting:@"fileType" forKey:@"sortMode"];
    NSArray<NFTemplate *> *byType = [NFFinderMenuBuilder orderedTemplatesForConfig:config favoritesFirst:NO];
    XCTAssertEqualObjects(byType, (@[zeta, beta, alpha]),
                          @"File type sorting compares extensions: md, swift, txt");
    XCTAssertEqual([NFFinderMenuBuilder sortModeForConfig:config], NFTemplateSortFileType);
}

- (void)testFavoritesRemainFirstWithANonManualSortMode {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *zeta = [self templateWithName:@"Zeta.txt" category:@"Documents" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *alpha = [self templateWithName:@"Alpha.txt" category:@"Documents" sortIndex:1 favorite:YES enabled:YES];
    [config.templates addObjectsFromArray:@[zeta, alpha]];
    [config setSetting:@"name" forKey:@"sortMode"];

    NSArray<NFTemplate *> *ordered = [NFFinderMenuBuilder orderedTemplatesForConfig:config favoritesFirst:YES];
    XCTAssertEqualObjects(ordered, (@[alpha, zeta]));
}

- (void)testTemplateMenuItemsCarryUniquePositiveTags {
    NFConfig *config = [NFConfig defaultConfig];
    NFTemplate *text = [self templateWithName:@"TextFile.txt" category:@"Documents" sortIndex:0 favorite:NO enabled:YES];
    NFTemplate *swift = [self templateWithName:@"Snippet.swift" category:@"Code" sortIndex:1 favorite:NO enabled:YES];
    NFTemplate *favorite = [self templateWithName:@"Favorite.txt" category:@"Documents" sortIndex:2 favorite:YES enabled:YES];
    [config.templates addObjectsFromArray:@[text, swift, favorite]];

    NSMenu *menu = [NFFinderMenuBuilder menuForConfig:config
                                               target:nil
                                               action:NSSelectorFromString(@"noop:")
                                              options:NFFinderMenuOptionFavoritesFirst | NFFinderMenuOptionGroupByCategory];
    NSMutableArray<NSMenuItem *> *leafItems = [NSMutableArray array];
    [self collectTemplateItemsFromMenu:menu intoArray:leafItems];
    XCTAssertEqual(leafItems.count, 3);
    NSMutableSet<NSNumber *> *tags = [NSMutableSet set];
    for (NSMenuItem *item in leafItems) {
        XCTAssertGreaterThan(item.tag, 0);
        XCTAssertFalse([tags containsObject:@(item.tag)], @"Tags must identify a single template");
        [tags addObject:@(item.tag)];
        XCTAssertTrue([item.representedObject isKindOfClass:[NSString class]]);
    }
    XCTAssertEqual(tags.count, 3);
}

- (void)collectTemplateItemsFromMenu:(NSMenu *)menu intoArray:(NSMutableArray<NSMenuItem *> *)items {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.submenu) {
            [self collectTemplateItemsFromMenu:item.submenu intoArray:items];
        } else if (item.tag > 0) {
            [items addObject:item];
        }
    }
}

@end

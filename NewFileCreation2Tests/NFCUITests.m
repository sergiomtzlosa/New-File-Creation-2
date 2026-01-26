#import "NFTestSupport.h"
#import "NFCMainMenuBuilder.h"

@interface NFCUITests : NFTestCase
@end

@implementation NFCUITests

- (nullable NSMenuItem *)itemWithAction:(SEL)action inMenu:(NSMenu *)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == action) {
            return item;
        }
        if (item.submenu) {
            NSMenuItem *match = [self itemWithAction:action inMenu:item.submenu];
            if (match) {
                return match;
            }
        }
    }
    return nil;
}

- (void)testMenuIncludesSearchRevealAndFullScreenShortcuts {
    NSMenu *menu = [NFCMainMenuBuilder buildMainMenu];

    NSMenuItem *search = [self itemWithAction:@selector(focusSearchFromMenu:) inMenu:menu];
    XCTAssertNotNil(search);
    XCTAssertEqualObjects(search.keyEquivalent, @"f");
    XCTAssertEqual(search.keyEquivalentModifierMask, NSEventModifierFlagCommand);

    NSMenuItem *reveal = [self itemWithAction:@selector(revealSelectedTemplateFromMenu:) inMenu:menu];
    XCTAssertNotNil(reveal);
    XCTAssertEqualObjects(reveal.keyEquivalent, @"r");
    XCTAssertEqual(reveal.keyEquivalentModifierMask, NSEventModifierFlagCommand);

    NSMenuItem *fullScreen = [self itemWithAction:@selector(toggleFullScreen:) inMenu:menu];
    XCTAssertNotNil(fullScreen);
    XCTAssertEqualObjects(fullScreen.keyEquivalent, @"f");
    XCTAssertEqual(fullScreen.keyEquivalentModifierMask,
                   NSEventModifierFlagControl | NSEventModifierFlagCommand);
}

- (void)testMenuIncludesCoreFileCommands {
    NSMenu *menu = [NFCMainMenuBuilder buildMainMenu];
    SEL actions[] = {
        @selector(newFileFromMenu:),
        @selector(newFileWithPanelFromMenu:),
        @selector(addTemplatesFromMenu:),
        @selector(showQuickPanelFromMenu:),
        @selector(showLibraryFromMenu:)
    };
    for (size_t index = 0; index < sizeof(actions) / sizeof(actions[0]); index++) {
        XCTAssertNotNil([self itemWithAction:actions[index] inMenu:menu],
                        @"Missing menu action %@", NSStringFromSelector(actions[index]));
    }
}

- (void)testReadmeIsBundledForHelp {
    NSURL *readme = [[NSBundle mainBundle] URLForResource:@"README" withExtension:@"md"];
    XCTAssertNotNil(readme);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:readme.path]);
}

@end

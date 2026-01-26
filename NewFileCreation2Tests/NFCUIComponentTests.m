#import "NFTestSupport.h"
#import "NFCMainMenuBuilder.h"
#import "NFCMainWindowController.h"
#import "NFCSidebarViewController.h"
#import "NFCTemplateGridViewController.h"
#import "NFCTemplateCollectionItem.h"
#import "NFCInspectorViewController.h"
#import "NFCQuickPanelController.h"
#import "NFCMenuBarController.h"
#import "NFCSettingsWindowController.h"
#import "NFCWelcomeWindowController.h"
#import "NFCToastPresenter.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFLocalization.h"

@interface NFCQuickPanelController (NFCTesting)
- (void)searchChanged:(NSSearchField *)sender;
@end

@interface NFCTemplateGridViewController (NFCTesting)
- (void)toggleContextFavorite:(id)sender;
- (void)createContextTemplate:(id)sender;
@end

@interface NFCTemplateCollectionItem (NFCTesting)
- (void)handleDoubleClick:(id)sender;
@end

@interface NFCInspectorViewController (NFCTesting)
- (void)createAction:(id)sender;
- (void)createPanelAction:(id)sender;
- (void)toggleFavorite:(id)sender;
- (void)toggleEnabled:(id)sender;
@end

@interface NFCMenuBarController (NFCTesting)
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (void)createTemplateAction:(NSMenuItem *)sender;
- (void)quickPanelAction:(id)sender;
- (void)statusButtonClicked:(id)sender;
@end

static NSMenuItem *NFMenuItemWithAction(NSMenu *menu, SEL action) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == action) {
            return item;
        }
        if (item.submenu) {
            NSMenuItem *match = NFMenuItemWithAction(item.submenu, action);
            if (match) {
                return match;
            }
        }
    }
    return nil;
}

static NSMenuItem *NFMenuItemWithSubmenuContainingAction(NSMenu *menu, SEL action) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.submenu) {
            if (NFMenuItemWithAction(item.submenu, action)) {
                return item;
            }
            NSMenuItem *match = NFMenuItemWithSubmenuContainingAction(item.submenu, action);
            if (match) {
                return match;
            }
        }
    }
    return nil;
}

static NSInteger NFNumberOfItemsShownByGrid(NFCTemplateGridViewController *grid) {
    NSCollectionView *collectionView = [grid valueForKey:@"collectionView"];
    id<NSCollectionViewDataSource> dataSource = (id<NSCollectionViewDataSource>)grid;
    return [dataSource collectionView:collectionView numberOfItemsInSection:0];
}

@interface NFCUIComponentTests : NFTestCase
@end

@implementation NFCUIComponentTests

- (NFConfig *)config {
    return [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil];
}

- (void)testMainMenuHasEveryTopLevelMenuAndKeyCommand {
    NSMenu *menu = [NFCMainMenuBuilder buildMainMenu];
    XCTAssertEqual(menu.numberOfItems, 6u);
    XCTAssertNotNil(menu.itemArray[0].submenu); // Application
    XCTAssertNotNil(menu.itemArray[1].submenu); // File
    XCTAssertNotNil(menu.itemArray[2].submenu); // Edit
    XCTAssertNotNil(menu.itemArray[3].submenu); // View
    XCTAssertNotNil(menu.itemArray[4].submenu); // Window
    XCTAssertNotNil(menu.itemArray[5].submenu); // Help

    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(showSettingsFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(newFileFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(newFileWithPanelFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(addTemplatesFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(focusSearchFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(revealSelectedTemplateFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(showQuickPanelFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(showLibraryFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(showHelpFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(showWelcomeFromMenu:)));
    XCTAssertNotNil(NFMenuItemWithAction(menu, @selector(revealTemplatesFromMenu:)));

    NSMenuItem *fullScreen = NFMenuItemWithAction(menu, @selector(toggleFullScreen:));
    XCTAssertEqual(fullScreen.keyEquivalentModifierMask,
                   NSEventModifierFlagControl | NSEventModifierFlagCommand);

    XCTAssertNotNil(NSApp.servicesMenu);
    XCTAssertNotNil(NSApp.windowsMenu);
    XCTAssertNotNil(NSApp.helpMenu);
}

- (void)testMainWindowBuildsThreePaneLayoutAndToolbar {
    NFCMainWindowController *controller = [[NFCMainWindowController alloc] init];
    NSWindow *window = controller.window;
    XCTAssertNotNil(window);
    XCTAssertEqualObjects(window.title, @"New File Creation 2");
    XCTAssertTrue([window.contentViewController isKindOfClass:[NSSplitViewController class]]);

    NSSplitViewController *split = (NSSplitViewController *)window.contentViewController;
    XCTAssertEqual(split.splitViewItems.count, 3u);
    XCTAssertEqual(split.splitViewItems[0].minimumThickness, 180.0);
    XCTAssertEqual(split.splitViewItems[0].maximumThickness, 280.0);
    XCTAssertEqual(split.splitViewItems[1].minimumThickness, 420.0);
    XCTAssertEqual(split.splitViewItems[2].minimumThickness, 240.0);
    XCTAssertEqual(split.splitViewItems[2].maximumThickness, 320.0);

    NSToolbar *toolbar = window.toolbar;
    XCTAssertNotNil(toolbar);
    id<NSToolbarDelegate> delegate = (id<NSToolbarDelegate>)toolbar.delegate;
    NSArray<NSToolbarItemIdentifier> *defaults = [delegate toolbarDefaultItemIdentifiers:toolbar];
    XCTAssertTrue([defaults containsObject:@"NFCToolbarNewFile"]);
    XCTAssertTrue([defaults containsObject:@"NFCToolbarNewFilePanel"]);
    XCTAssertTrue([defaults containsObject:@"NFCToolbarAddTemplate"]);
    XCTAssertTrue([defaults containsObject:@"NFCToolbarSearch"]);
    XCTAssertTrue([defaults containsObject:@"NFCToolbarInspector"]);

    NFCTemplateGridViewController *grid = [controller valueForKey:@"gridViewController"];
    [grid view];
    [controller reloadAll];

    NFTemplate *template = self.config.enabledTemplates.lastObject;
    XCTAssertNotNil(template);
    [controller selectTemplateWithIdentifier:template.identifier];
    XCTAssertTrue([controller hasSelectedTemplate]);
    XCTAssertEqualObjects(grid.selectedTemplate.identifier, template.identifier);
    XCTAssertEqualObjects([controller valueForKeyPath:@"inspectorViewController.template.identifier"], template.identifier);
    [window orderOut:nil];
}

- (void)testSidebarListsLibraryCategoriesAndPublishesFilterChanges {
    NFCSidebarViewController *sidebar = [[NFCSidebarViewController alloc] init];
    [sidebar view];
    NSOutlineView *outline = [sidebar valueForKey:@"outlineView"];
    XCTAssertNotNil(outline);
    XCTAssertGreaterThan(outline.numberOfRows, 0);
    XCTAssertEqualObjects(outline.identifier, @"TemplateSidebar");

    __block NFCTemplateFilter receivedFilter = (NFCTemplateFilter)-1;
    __block NSString *receivedCategory = @"unset";
    sidebar.onFilterChanged = ^(NFCTemplateFilter filter, NSString *category) {
        receivedFilter = filter;
        receivedCategory = category;
    };

    NSInteger favoritesRow = -1;
    NSInteger allRow = -1;
    for (NSInteger row = 0; row < outline.numberOfRows; row++) {
        id item = [outline itemAtRow:row];
        NSString *title = [item valueForKey:@"title"];
        if ([title isEqualToString:NFLocalizedString(@"Favorites")]) {
            favoritesRow = row;
        } else if ([title isEqualToString:NFLocalizedString(@"All Templates")]) {
            allRow = row;
        }
    }
    XCTAssertGreaterThanOrEqual(favoritesRow, 0);
    XCTAssertGreaterThanOrEqual(allRow, 0);

    [outline selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)favoritesRow] byExtendingSelection:NO];
    XCTAssertEqual(receivedFilter, NFCTemplateFilterFavorites);
    XCTAssertNil(receivedCategory);

    [sidebar selectAllTemplates];
    XCTAssertEqual(receivedFilter, NFCTemplateFilterAll);
}

- (void)testGridFiltersSearchesSortsSelectsAndShowsEmptyState {
    NFCTemplateGridViewController *grid = [[NFCTemplateGridViewController alloc] init];
    [grid view];
    NSCollectionView *collection = [grid valueForKey:@"collectionView"];
    NSView *emptyState = [grid valueForKey:@"emptyStateView"];
    XCTAssertEqualObjects(collection.identifier, @"TemplateGrid");

    NFConfig *config = self.config;
    NFTemplate *first = config.enabledTemplates.firstObject;
    XCTAssertNotNil(first);
    XCTAssertEqual(NFNumberOfItemsShownByGrid(grid), (NSInteger)config.enabledTemplates.count);

    grid.searchQuery = first.fileName;
    XCTAssertEqual(NFNumberOfItemsShownByGrid(grid), 1);
    grid.searchQuery = @"no-such-template-zzzz";
    XCTAssertEqual(NFNumberOfItemsShownByGrid(grid), 0);
    XCTAssertTrue(collection.hidden);
    XCTAssertFalse(emptyState.hidden);

    grid.searchQuery = nil;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *latest, NSError **error) {
        latest.templates.firstObject.favorite = YES;
        return YES;
    } error:nil];
    grid.filter = NFCTemplateFilterFavorites;
    XCTAssertEqual(NFNumberOfItemsShownByGrid(grid), 1);

    grid.filter = NFCTemplateFilterAll;
    grid.sortMode = NFCTemplateSortName;
    NSArray<NFTemplate *> *displayed = [grid valueForKey:@"displayedTemplates"];
    for (NSUInteger index = 1; index < displayed.count; index++) {
        NSComparisonResult result = [displayed[index - 1].resolvedDisplayName
            localizedCaseInsensitiveCompare:displayed[index].resolvedDisplayName];
        XCTAssertNotEqual(result, NSOrderedDescending);
    }

    [grid selectTemplateWithIdentifier:first.identifier];
    XCTAssertEqualObjects(grid.selectedTemplate.identifier, first.identifier);

    __block NFTemplate *doubleClicked = nil;
    grid.onCreate = ^(NFTemplate *template) {
        doubleClicked = template;
    };
    NFCTemplateCollectionItem *item = (NFCTemplateCollectionItem *)[(id<NSCollectionViewDataSource>)grid collectionView:collection
        itemForRepresentedObjectAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    XCTAssertNotNil(item);
    item.onDoubleClick(item.template);
    XCTAssertEqualObjects(doubleClicked.identifier, item.template.identifier);
}

- (void)testGridContextMenuCommandsWorkWithoutOpeningASheet {
    NFCTemplateGridViewController *grid = [[NFCTemplateGridViewController alloc] init];
    [grid view];
    NSCollectionView *collection = [grid valueForKey:@"collectionView"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    NSMenu *(^provider)(NSIndexPath *) = [collection valueForKey:@"menuProvider"];
    NSMenu *menu = provider(indexPath);
    XCTAssertNotNil(menu);

    NSArray<NSString *> *expectedTitles = @[
        NFLocalizedString(@"New File"),
        NFLocalizedString(@"New File…"),
        NFLocalizedString(@"Favorite"),
        NFLocalizedString(@"Reveal in Finder"),
        NFLocalizedString(@"Rename…"),
        NFLocalizedString(@"Remove Template…")
    ];
    NSMutableArray<NSString *> *actualTitles = [NSMutableArray array];
    NSInteger separators = 0;
    for (NSMenuItem *item in menu.itemArray) {
        if (item.isSeparatorItem) {
            separators++;
        } else {
            [actualTitles addObject:item.title];
        }
    }
    XCTAssertEqual(separators, 2);
    for (NSString *title in expectedTitles) {
        XCTAssertTrue([actualTitles containsObject:title], @"Missing menu command: %@", title);
    }

    __block NFTemplate *created = nil;
    grid.onCreate = ^(NFTemplate *template) {
        created = template;
    };
    [grid createContextTemplate:nil];
    XCTAssertNotNil(created);

    NFTemplate *before = self.config.templates.firstObject;
    BOOL wasFavorite = before.favorite;
    [grid toggleContextFavorite:nil];
    NFTemplate *after = [self.config templateWithIdentifier:before.identifier];
    XCTAssertEqual(after.favorite, !wasFavorite);
}

- (void)testCollectionItemRendersTemplateAndSendsDoubleClick {
    NFCTemplateCollectionItem *item = [[NFCTemplateCollectionItem alloc] init];
    NFTemplate *template = self.config.enabledTemplates.firstObject;
    template.favorite = YES;
    item.template = template;
    [item.view layoutSubtreeIfNeeded];

    NSTextField *name = [item valueForKey:@"nameLabel"];
    NSTextField *category = [item valueForKey:@"categoryLabel"];
    NSImageView *icon = [item valueForKey:@"iconView"];
    NSImageView *favorite = [item valueForKey:@"favoriteView"];
    XCTAssertEqualObjects(name.stringValue, template.resolvedDisplayName);
    XCTAssertEqualObjects(category.stringValue, template.category);
    XCTAssertNotNil(icon.image);
    XCTAssertFalse(favorite.hidden);
    XCTAssertEqualObjects(item.view.accessibilityRole, NSAccessibilityButtonRole);

    __block NFTemplate *clicked = nil;
    item.onDoubleClick = ^(NFTemplate *selected) {
        clicked = selected;
    };
    [item handleDoubleClick:nil];
    XCTAssertEqualObjects(clicked.identifier, template.identifier);

    [item setSelected:YES];
    NSView *card = [item valueForKey:@"cardView"];
    XCTAssertEqual(card.layer.borderWidth, 2.0);
}

- (void)testInspectorShowsMetadataAndPublishesCommands {
    NFCInspectorViewController *inspector = [[NFCInspectorViewController alloc] init];
    NFTemplate *template = self.config.enabledTemplates.firstObject;
    template.useCount = 3;
    inspector.template = template;
    [inspector.view layoutSubtreeIfNeeded];

    NSTextField *name = [inspector valueForKey:@"nameLabel"];
    NSTextField *file = [inspector valueForKey:@"fileLabel"];
    NSTextField *category = [inspector valueForKey:@"categoryLabel"];
    NSTextField *details = [inspector valueForKey:@"detailsLabel"];
    NSButton *favorite = [inspector valueForKey:@"favoriteButton"];
    NSButton *enabled = [inspector valueForKey:@"enabledButton"];
    XCTAssertEqualObjects(name.stringValue, template.resolvedDisplayName);
    XCTAssertEqualObjects(file.stringValue, template.fileName);
    XCTAssertEqualObjects(category.stringValue, NFLocalizedString(template.category).uppercaseString);
    XCTAssertTrue([details.stringValue containsString:@"Used 3 times"]);
    XCTAssertEqual(favorite.state, NSControlStateValueOff);
    XCTAssertEqual(enabled.state, NSControlStateValueOn);

    __block NSInteger changes = 0;
    inspector.onChange = ^{
        changes++;
    };
    [inspector toggleFavorite:nil];
    XCTAssertEqual(changes, 1);
    XCTAssertTrue([self.config templateWithIdentifier:template.identifier].favorite);

    [inspector toggleEnabled:nil];
    XCTAssertEqual(changes, 2);
    XCTAssertFalse([self.config templateWithIdentifier:template.identifier].enabled);

    __block NFTemplate *created = nil;
    __block NFTemplate *createdWithPanel = nil;
    inspector.onCreate = ^(NFTemplate *selected) {
        created = selected;
    };
    inspector.onCreateWithPanel = ^(NFTemplate *selected) {
        createdWithPanel = selected;
    };
    [inspector createAction:nil];
    [inspector createPanelAction:nil];
    XCTAssertEqualObjects(created.identifier, template.identifier);
    XCTAssertEqualObjects(createdWithPanel.identifier, template.identifier);
}

- (void)testQuickPanelPresentsVisualRowsAndFiltersTemplates {
    NFCQuickPanelController *panel = [[NFCQuickPanelController alloc] init];
    [panel reloadData];
    NSTableView *tableView = [panel valueForKey:@"tableView"];
    NSSearchField *searchField = [panel valueForKey:@"searchField"];
    NSTextField *emptyLabel = [panel valueForKey:@"emptyLabel"];
    XCTAssertNotNil(tableView);
    XCTAssertNotNil(searchField);
    XCTAssertEqualObjects(tableView.identifier, @"QuickPanelTemplateTable");
    XCTAssertEqualObjects(searchField.identifier, @"QuickPanelSearchField");
    XCTAssertEqual(panel.window.level, NSFloatingWindowLevel);
    XCTAssertTrue((panel.window.collectionBehavior & NSWindowCollectionBehaviorFullScreenAuxiliary) != 0);
    XCTAssertEqualWithAccuracy(tableView.rowHeight, 52.0, 0.001);

    NFConfig *config = self.config;
    XCTAssertEqual(tableView.numberOfRows, (NSInteger)config.enabledTemplates.count);

    NSTableColumn *column = tableView.tableColumns.firstObject;
    NSTableCellView *cell = (NSTableCellView *)[(id<NSTableViewDelegate>)panel
        tableView:tableView viewForTableColumn:column row:0];
    XCTAssertNotNil(cell.imageView.image);
    XCTAssertFalse(cell.textField.stringValue.length == 0);
    NSTextField *detail = [cell viewWithTag:200];
    XCTAssertTrue([detail.stringValue containsString:@"·"]);

    NSTextField *hint = [self labelWithString:NFLocalizedString(@"↩ Create file    ⠿ Drag to Finder    esc Close")
                                      inView:panel.window.contentView];
    XCTAssertNotNil(hint);
    XCTAssertEqualObjects(hint.identifier, @"QuickPanelDragHint");

    searchField.stringValue = config.enabledTemplates.firstObject.fileName;
    [panel searchChanged:searchField];
    XCTAssertEqual(tableView.numberOfRows, 1);
    searchField.stringValue = @"no-such-template-zzzz";
    [panel searchChanged:searchField];
    XCTAssertEqual(tableView.numberOfRows, 0);
    XCTAssertFalse(emptyLabel.hidden);

    searchField.stringValue = @"";
    [panel searchChanged:searchField];
    XCTAssertEqual(tableView.numberOfRows, (NSInteger)config.enabledTemplates.count);
    XCTAssertTrue(emptyLabel.hidden);
    [panel.window orderOut:nil];
}

- (void)testMenuBarBuildsStatusMenuAndCanShowOrHideTheStatusItem {
    NFCMenuBarController *menuBar = [[NFCMenuBarController alloc] init];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"test"];
    [menuBar menuNeedsUpdate:menu];

    XCTAssertEqual(menu.numberOfItems, 9u);
    NSMenuItem *quick = NFMenuItemWithAction(menu, @selector(quickPanelAction:));
    XCTAssertNotNil(quick);
    XCTAssertTrue(quick.toolTip.length > 0);
    NSMenuItem *newFile = NFMenuItemWithSubmenuContainingAction(menu, @selector(createTemplateAction:));
    XCTAssertNotNil(newFile);
    XCTAssertEqual(newFile.submenu.numberOfItems, (NSInteger)self.config.enabledTemplates.count);
    NSMenuItem *firstTemplate = newFile.submenu.itemArray.firstObject;
    XCTAssertNotNil(firstTemplate.image);
    XCTAssertNotNil(firstTemplate.representedObject);

    __block NFTemplate *created = nil;
    menuBar.onCreateTemplate = ^(NFTemplate *template) {
        created = template;
    };
    [menuBar createTemplateAction:firstTemplate];
    XCTAssertEqualObjects(created.identifier, firstTemplate.representedObject);

    @try {
        menuBar.visible = YES;
        NSStatusItem *statusItem = [menuBar valueForKey:@"statusItem"];
        XCTAssertNotNil(statusItem);
        XCTAssertNotNil(statusItem.button.image);
        XCTAssertEqualObjects(statusItem.button.toolTip, @"New File Creation 2");
        XCTAssertEqual(statusItem.button.action, @selector(statusButtonClicked:));
    } @finally {
        menuBar.visible = NO;
    }
    XCTAssertNil([menuBar valueForKey:@"statusItem"]);
}

- (void)testSettingsWindowContainsAllPanesAndReloadsWithoutCrashing {
    NFCSettingsWindowController *settings = [[NFCSettingsWindowController alloc] init];
    NSTabViewController *tabs = [settings valueForKey:@"tabViewController"];
    [tabs view];
    XCTAssertEqual(tabs.tabViewItems.count, 5u);
    XCTAssertEqualObjects(tabs.view.identifier, @"SettingsTabs");

    NSArray<NSString *> *expectedTitles = @[
        NFLocalizedString(@"General"),
        NFLocalizedString(@"Templates"),
        NFLocalizedString(@"Finder"),
        NFLocalizedString(@"Advanced"),
        NFLocalizedString(@"About")
    ];
    for (NSUInteger index = 0; index < tabs.tabViewItems.count; index++) {
        NSTabViewItem *tab = tabs.tabViewItems[index];
        XCTAssertEqualObjects(tab.label, expectedTitles[index]);
        [tab.viewController view];
        [tab.viewController.view layoutSubtreeIfNeeded];
    }

    [settings reloadPanes];

    NSViewController *general = tabs.tabViewItems[0].viewController;
    NSTextField *baseName = [general valueForKey:@"baseNameField"];
    XCTAssertEqualObjects(baseName.stringValue, @"Untitled");
    baseName.stringValue = @"  Draft  ";
    [baseName sendAction:baseName.action to:baseName.target];
    XCTAssertEqualObjects([self.config stringSettingForKey:@"defaultBaseName" defaultValue:@""], @"Draft");

    NSViewController *templates = tabs.tabViewItems[1].viewController;
    NSTableView *table = [templates valueForKey:@"tableView"];
    XCTAssertEqual(table.numberOfRows, (NSInteger)self.config.templates.count);
    XCTAssertEqual(table.tableColumns.count, 5u);

    NSViewController *finder = tabs.tabViewItems[2].viewController;
    NSTextField *status = [finder valueForKey:@"statusLabel"];
    XCTAssertTrue(status.stringValue.length > 0);

    NSViewController *advanced = tabs.tabViewItems[3].viewController;
    NSTextField *configPath = [advanced valueForKey:@"configPathLabel"];
    XCTAssertTrue([configPath.stringValue hasSuffix:@"config.json"]);
    NSTextField *templatesPath = [advanced valueForKey:@"templatesPathLabel"];
    XCTAssertTrue([templatesPath.stringValue hasSuffix:@"Templates"]);

    NSViewController *about = tabs.tabViewItems[4].viewController;
    XCTAssertNotNil([self buttonWithTitle:NFLocalizedString(@"View License") inView:about.view]);
    [settings.window orderOut:nil];
}

- (void)testWelcomeWindowGetStartedAndSettingsCallbacks {
    NFCWelcomeWindowController *welcome = [[NFCWelcomeWindowController alloc] init];
    NSWindow *window = welcome.window;
    XCTAssertNotNil(window);
    XCTAssertEqualObjects(window.title, NFLocalizedString(@"Welcome"));

    NSButton *getStarted = [self buttonWithTitle:NFLocalizedString(@"Get Started") inView:window.contentView];
    NSButton *openSettings = [self buttonWithTitle:NFLocalizedString(@"Open Settings") inView:window.contentView];
    XCTAssertNotNil(getStarted);
    XCTAssertNotNil(openSettings);
    XCTAssertNotNil([self labelWithString:NFLocalizedString(@"Welcome to New File Creation 2") inView:window.contentView]);

    __block BOOL started = NO;
    welcome.onGetStarted = ^{
        started = YES;
    };
    [getStarted performClick:nil];
    XCTAssertTrue(started);
    XCTAssertFalse(window.isVisible);
    XCTAssertTrue([self.config boolSettingForKey:@"onboardingCompleted" defaultValue:NO]);

    NFCWelcomeWindowController *second = [[NFCWelcomeWindowController alloc] init];
    __block BOOL openedSettings = NO;
    second.onOpenSettings = ^{
        openedSettings = YES;
    };
    NSButton *secondSettings = [self buttonWithTitle:NFLocalizedString(@"Open Settings") inView:second.window.contentView];
    [secondSettings performClick:nil];
    XCTAssertTrue(openedSettings);
    [second.window orderOut:nil];
}

- (void)testToastPresenterAddsMessageAndInvokesAction {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 320)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    __block BOOL invoked = NO;
    [NFCToastPresenter showMessage:@"File created" inWindow:window actionTitle:@"Open" action:^{
        invoked = YES;
    }];
    [window.contentView layoutSubtreeIfNeeded];

    NSVisualEffectView *toast = (NSVisualEffectView *)[self firstSubviewOfClass:[NSVisualEffectView class]
                                                                        inView:window.contentView];
    XCTAssertNotNil(toast);
    XCTAssertNotNil([self labelWithString:@"File created" inView:toast]);
    NSButton *button = [self buttonWithTitle:@"Open" inView:toast];
    XCTAssertNotNil(button);
    [button performClick:nil];
    XCTAssertTrue(invoked);
    [window orderOut:nil];
}

@end

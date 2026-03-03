#import "NFCMainWindowController.h"
#import "NFCSidebarViewController.h"
#import "NFCTemplateGridViewController.h"
#import "NFCInspectorViewController.h"
#import "NFCreateCoordinator.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFCFloatingPanel.h"
#import "NFCToastPresenter.h"
#import "NFFinderMenuBuilder.h"
#import "NFLocalization.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSToolbarItemIdentifier const NFCToolbarNewFile = @"NFCToolbarNewFile";
static NSToolbarItemIdentifier const NFCToolbarNewFilePanel = @"NFCToolbarNewFilePanel";
static NSToolbarItemIdentifier const NFCToolbarAddTemplate = @"NFCToolbarAddTemplate";
static NSToolbarItemIdentifier const NFCToolbarSearch = @"NFCToolbarSearch";
static NSToolbarItemIdentifier const NFCToolbarInspector = @"NFCToolbarInspector";

@interface NFCMainWindowController () <NSToolbarDelegate, NSSearchFieldDelegate>
@property (nonatomic, strong) NSSplitViewController *splitViewController;
@property (nonatomic, strong) NFCSidebarViewController *sidebarViewController;
@property (nonatomic, strong) NFCTemplateGridViewController *gridViewController;
@property (nonatomic, strong) NFCInspectorViewController *inspectorViewController;
@property (nonatomic, strong) NSSplitViewItem *sidebarItem;
@property (nonatomic, strong) NSSplitViewItem *inspectorItem;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, assign) BOOL didPositionWindow;
@end

@implementation NFCMainWindowController

- (instancetype)init {
    NFCFloatingPanel *window = [NFCFloatingPanel floatingPanelWithContentRect:NSMakeRect(0, 0, 1040, 660)
                                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                                             NSWindowStyleMaskResizable |
                                                                             NSWindowStyleMaskFullSizeContentView];
    window.title = @"New File Creation 2";
    window.minSize = NSMakeSize(780, 480);
    window.titlebarAppearsTransparent = NO;
    window.toolbarStyle = NSWindowToolbarStyleUnified;
    window.tabbingMode = NSWindowTabbingModeDisallowed;

    self = [super initWithWindow:window];
    if (self) {
        [self setupInterface];
        [self setupToolbar];
    }
    return self;
}

- (void)showWindow:(id)sender {
    if (!self.didPositionWindow) {
        [(NFCFloatingPanel *)self.window centerOnActiveScreen];
        self.didPositionWindow = YES;
    }
    [super showWindow:sender];
}

- (void)setupInterface {
    self.sidebarViewController = [[NFCSidebarViewController alloc] init];
    self.gridViewController = [[NFCTemplateGridViewController alloc] init];
    self.inspectorViewController = [[NFCInspectorViewController alloc] init];

    self.splitViewController = [[NSSplitViewController alloc] init];
    self.splitViewController.splitView.dividerStyle = NSSplitViewDividerStyleThin;

    self.sidebarItem = [NSSplitViewItem sidebarWithViewController:self.sidebarViewController];
    self.sidebarItem.minimumThickness = 180;
    self.sidebarItem.maximumThickness = 280;
    self.sidebarItem.canCollapse = YES;
    [self.splitViewController addSplitViewItem:self.sidebarItem];

    NSSplitViewItem *contentItem = [NSSplitViewItem splitViewItemWithViewController:self.gridViewController];
    contentItem.minimumThickness = 420;
    [self.splitViewController addSplitViewItem:contentItem];

    self.inspectorItem = [NSSplitViewItem splitViewItemWithViewController:self.inspectorViewController];
    self.inspectorItem.minimumThickness = 240;
    self.inspectorItem.maximumThickness = 320;
    self.inspectorItem.canCollapse = YES;
    [self.splitViewController addSplitViewItem:self.inspectorItem];

    self.window.contentViewController = self.splitViewController;
    self.window.contentMinSize = NSMakeSize(780, 480);

    __weak typeof(self) weakSelf = self;
    self.sidebarViewController.onFilterChanged = ^(NFCTemplateFilter filter, NSString *category) {
        weakSelf.gridViewController.filter = filter;
        weakSelf.gridViewController.categoryFilter = category;
    };
    self.gridViewController.onCreate = ^(NFTemplate *template) {
        [[NFCreateCoordinator sharedCoordinator] createInDefaultLocation:template window:weakSelf.window];
    };
    self.gridViewController.onAddTemplates = ^{
        [weakSelf showAddTemplatesPanel];
    };
    self.gridViewController.onSelectionChanged = ^(NFTemplate *template) {
        weakSelf.inspectorViewController.template = template;
        weakSelf.inspectorViewController.onChange = ^{
            [weakSelf reloadAll];
        };
        weakSelf.inspectorViewController.onCreate = ^(NFTemplate *selected) {
            [[NFCreateCoordinator sharedCoordinator] createInDefaultLocation:selected window:weakSelf.window];
        };
        weakSelf.inspectorViewController.onCreateWithPanel = ^(NFTemplate *selected) {
            [[NFCreateCoordinator sharedCoordinator] createWithSavePanel:selected window:weakSelf.window];
        };
    };

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(configDidChange:)
                                                 name:NFConfigDidChangeNotification
                                               object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(configDidChange:)
                                                            name:NFConfigDistributedChangeNotification
                                                          object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf selectInitialTemplate];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupToolbar {
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"NFCMainToolbar"];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
    toolbar.allowsUserCustomization = YES;
    toolbar.autosavesConfiguration = YES;
    self.window.toolbar = toolbar;
}

- (void)selectInitialTemplate {
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil];
    if (!config) {
        return;
    }
    NSString *defaultID = [config stringSettingForKey:@"defaultTemplateID" defaultValue:@""];
    if (defaultID.length == 0) {
        defaultID = config.templates.firstObject.identifier;
    }
    if (defaultID.length > 0) {
        [self.gridViewController selectTemplateWithIdentifier:defaultID];
    }
}

- (void)reloadAll {
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
    self.gridViewController.sortMode = [NFFinderMenuBuilder sortModeForConfig:config];
    [self.sidebarViewController reloadData];
    [self.gridViewController reloadData];
    NFTemplate *selected = self.gridViewController.selectedTemplate;
    if (selected) {
        [self.gridViewController selectTemplateWithIdentifier:selected.identifier];
    }
}

- (void)selectTemplateWithIdentifier:(NSString *)identifier {
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil];
    NFTemplate *template = [config templateWithIdentifier:identifier];
    if (template) {
        self.inspectorViewController.template = template;
    }
    [self.sidebarViewController selectAllTemplates];
    self.gridViewController.filter = NFCTemplateFilterAll;
    self.gridViewController.categoryFilter = nil;
    if (identifier.length > 0) {
        [self.gridViewController selectTemplateWithIdentifier:identifier];
    }
}

- (NFTemplate *)selectedOrDefaultTemplate {
    NFTemplate *template = self.gridViewController.selectedTemplate;
    if (template) {
        return template;
    }
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil];
    NSString *defaultID = [config stringSettingForKey:@"defaultTemplateID" defaultValue:@""];
    template = [config templateWithIdentifier:defaultID];
    if (!template) {
        template = config.enabledTemplates.firstObject;
    }
    return template;
}

- (void)createSelectedTemplate {
    NFTemplate *template = [self selectedOrDefaultTemplate];
    if (!template) {
        NSBeep();
        return;
    }
    [[NFCreateCoordinator sharedCoordinator] createInDefaultLocation:template window:self.window];
}

- (void)createSelectedTemplateWithPanel {
    NFTemplate *template = [self selectedOrDefaultTemplate];
    if (!template) {
        NSBeep();
        return;
    }
    [[NFCreateCoordinator sharedCoordinator] createWithSavePanel:template window:self.window];
}

- (BOOL)hasSelectedTemplate {
    return self.gridViewController.selectedTemplate != nil;
}

- (void)revealSelectedTemplate {
    NFTemplate *template = self.gridViewController.selectedTemplate;
    if (!template) {
        NSBeep();
        return;
    }
    NSURL *url = [[NFConfigStore sharedStore] templateFileURLForTemplate:template];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
}

- (void)focusSearch {
    if (!self.searchField) {
        NSToolbar *toolbar = self.window.toolbar;
        if (toolbar) {
            [toolbar insertItemWithItemIdentifier:NFCToolbarSearch atIndex:toolbar.items.count];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.window makeKeyAndOrderFront:nil];
        if (self.searchField) {
            [self.window makeFirstResponder:self.searchField];
        }
    });
}

- (void)showAddTemplatesPanel {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = NFLocalizedString(@"Add Templates");
    panel.message = NFLocalizedString(@"Choose files or packages to use as templates.");
    panel.prompt = NFLocalizedString(@"Add");
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = YES;
    panel.resolvesAliases = YES;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) {
            return;
        }
        [[NFCreateCoordinator sharedCoordinator] addTemplatesFromURLs:panel.URLs window:self.window];
        [self reloadAll];
    }];
}

- (void)configDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadAll];
    });
}

#pragma mark - Toolbar

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[NFCToolbarNewFile, NFCToolbarNewFilePanel, NFCToolbarAddTemplate,
             NSToolbarFlexibleSpaceItemIdentifier, NFCToolbarSearch, NFCToolbarInspector];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[NFCToolbarNewFile, NFCToolbarNewFilePanel, NFCToolbarAddTemplate,
             NSToolbarFlexibleSpaceItemIdentifier, NFCToolbarSearch, NFCToolbarInspector];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    if ([itemIdentifier isEqualToString:NFCToolbarNewFile]) {
        item.label = NFLocalizedString(@"Create File");
        item.paletteLabel = NFLocalizedString(@"Create File");
        item.toolTip = NFLocalizedString(@"Create the selected template in the default folder");
        item.image = [NSImage imageWithSystemSymbolName:@"doc.badge.plus" accessibilityDescription:NFLocalizedString(@"Create File")];
        item.target = self;
        item.action = @selector(createSelectedTemplate);
    } else if ([itemIdentifier isEqualToString:NFCToolbarNewFilePanel]) {
        item.label = NFLocalizedString(@"Create with Name…");
        item.paletteLabel = NFLocalizedString(@"Create with Name…");
        item.toolTip = NFLocalizedString(@"Choose a name and location for the new file");
        item.image = [NSImage imageWithSystemSymbolName:@"square.and.pencil" accessibilityDescription:NFLocalizedString(@"Create with Name…")];
        item.target = self;
        item.action = @selector(createSelectedTemplateWithPanel);
    } else if ([itemIdentifier isEqualToString:NFCToolbarAddTemplate]) {
        item.label = NFLocalizedString(@"Add Template");
        item.paletteLabel = NFLocalizedString(@"Add Template");
        item.toolTip = NFLocalizedString(@"Add files as templates");
        item.image = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:NFLocalizedString(@"Add Template")];
        item.target = self;
        item.action = @selector(showAddTemplatesPanel);
    } else if ([itemIdentifier isEqualToString:NFCToolbarSearch]) {
        NSSearchField *field = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 220, 28)];
        field.translatesAutoresizingMaskIntoConstraints = NO;
        field.placeholderString = NFLocalizedString(@"Search templates");
        field.delegate = self;
        field.sendsWholeSearchString = NO;
        field.sendsSearchStringImmediately = YES;
        field.target = self;
        field.action = @selector(searchChanged:);
        self.searchField = field;
        item.view = field;
        item.label = NFLocalizedString(@"Search");
        item.paletteLabel = NFLocalizedString(@"Search");
        [field.widthAnchor constraintEqualToConstant:220].active = YES;
        [field setContentHuggingPriority:NSLayoutPriorityRequired
                          forOrientation:NSLayoutConstraintOrientationHorizontal];
    } else if ([itemIdentifier isEqualToString:NFCToolbarInspector]) {
        item.label = NFLocalizedString(@"Inspector");
        item.paletteLabel = NFLocalizedString(@"Inspector");
        item.toolTip = NFLocalizedString(@"Show or hide the inspector");
        item.image = [NSImage imageWithSystemSymbolName:@"sidebar.right" accessibilityDescription:NFLocalizedString(@"Inspector")];
        item.target = self;
        item.action = @selector(toggleInspector:);
    }
    return item;
}

- (void)searchChanged:(NSSearchField *)sender {
    self.gridViewController.searchQuery = sender.stringValue;
}

- (void)toggleInspector:(id)sender {
    self.inspectorItem.collapsed = !self.inspectorItem.collapsed;
}

@end

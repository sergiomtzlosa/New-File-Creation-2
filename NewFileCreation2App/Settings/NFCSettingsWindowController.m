#import "NFCSettingsWindowController.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFCreateCoordinator.h"
#import "NFShortcutCenter.h"
#import "NFLoginItemManager.h"
#import "NFCLIInstallController.h"
#import "NFPaths.h"
#import "NFVersion.h"
#import "NFLogger.h"
#import "NFLocalization.h"

@protocol NFCSettingsPaneReloading <NSObject>
- (void)reloadData;
@end

#pragma mark - Helpers

static NSTextField *NFMakeLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSTextField *NFMakeSectionLabel(NSString *text) {
    NSTextField *label = NFMakeLabel(text, [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold], NSColor.secondaryLabelColor);
    label.stringValue = text.uppercaseString;
    return label;
}

static NSButton *NFMakeCheckbox(NSString *title, id target, SEL action) {
    NSButton *button = [NSButton checkboxWithTitle:title target:target action:action];
    button.font = [NSFont systemFontOfSize:13];
    return button;
}

static NSGridView *NFMakeGrid(void) {
    NSGridView *grid = [[NSGridView alloc] init];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.rowSpacing = 10;
    grid.columnSpacing = 14;
    grid.xPlacement = NSGridCellPlacementLeading;
    return grid;
}

static NSView *NFGridViewContainer(NSGridView *grid) {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 660, 520)];
    [container addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.topAnchor constraintEqualToAnchor:container.topAnchor constant:24],
        [grid.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [grid.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-28]
    ]];
    return container;
}

static void NFSetSetting(id value, NSString *key) {
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        [config setSetting:value forKey:key];
        return YES;
    } error:nil];
}

static void NFShowSettingsError(NSWindow *window, NSString *message, NSString *informative) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    alert.informativeText = informative ?: @"";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NFLocalizedString(@"OK")];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

#pragma mark - General

@interface NFCGeneralSettingsViewController : NSViewController <NSTextFieldDelegate>
@property (nonatomic, strong) NSTextField *baseNameField;
@property (nonatomic, strong) NSPopUpButton *templatePopup;
@property (nonatomic, strong) NSTextField *directoryField;
@property (nonatomic, strong) NSButton *revealCheckbox;
@property (nonatomic, strong) NSButton *openCheckbox;
@property (nonatomic, strong) NSButton *soundCheckbox;
@property (nonatomic, strong) NSButton *toastCheckbox;
@property (nonatomic, strong) NSButton *launchCheckbox;
@property (nonatomic, strong) NSButton *menuBarCheckbox;
@property (nonatomic, strong) NSButton *dockCheckbox;
@property (nonatomic, strong) NSPopUpButton *shortcutPopup;
@property (nonatomic, copy) NSArray<NSString *> *templateIDs;
@end

@implementation NFCGeneralSettingsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = NFLocalizedString(@"General");
    }
    return self;
}

- (void)loadView {
    NSGridView *grid = NFMakeGrid();
    self.baseNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    self.baseNameField.delegate = self;
    self.baseNameField.placeholderString = NFLocalizedString(@"Untitled");
    self.baseNameField.target = self;
    self.baseNameField.action = @selector(baseNameChanged:);

    self.templatePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 260, 26) pullsDown:NO];
    self.templatePopup.target = self;
    self.templatePopup.action = @selector(templateChanged:);

    self.directoryField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    self.directoryField.delegate = self;
    self.directoryField.placeholderString = NFLocalizedString(@"Desktop");
    self.directoryField.target = self;
    self.directoryField.action = @selector(directoryChanged:);
    NSButton *choose = [NSButton buttonWithTitle:NFLocalizedString(@"Choose…") target:self action:@selector(chooseDirectory:)];

    NSStackView *directoryRow = [NSStackView stackViewWithViews:@[self.directoryField, choose]];
    directoryRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    directoryRow.spacing = 8;
    [self.directoryField.widthAnchor constraintEqualToConstant:300].active = YES;

    self.revealCheckbox = NFMakeCheckbox(NFLocalizedString(@"Reveal the new file in Finder"), self, @selector(checkboxChanged:));
    self.openCheckbox = NFMakeCheckbox(NFLocalizedString(@"Open the new file after creating it"), self, @selector(checkboxChanged:));
    self.soundCheckbox = NFMakeCheckbox(NFLocalizedString(@"Play a sound after creating a file"), self, @selector(checkboxChanged:));
    self.toastCheckbox = NFMakeCheckbox(NFLocalizedString(@"Show a confirmation in the app window"), self, @selector(checkboxChanged:));
    self.launchCheckbox = NFMakeCheckbox(NFLocalizedString(@"Launch New File Creation 2 at login"), self, @selector(checkboxChanged:));
    self.menuBarCheckbox = NFMakeCheckbox(NFLocalizedString(@"Show the menu bar icon"), self, @selector(checkboxChanged:));
    self.dockCheckbox = NFMakeCheckbox(NFLocalizedString(@"Show the Dock icon"), self, @selector(checkboxChanged:));

    self.shortcutPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 240, 26) pullsDown:NO];
    self.shortcutPopup.target = self;
    self.shortcutPopup.action = @selector(shortcutChanged:);
    for (NSString *shortcut in [NFShortcutCenter presetShortcuts]) {
        [self.shortcutPopup addItemWithTitle:[NFShortcutCenter displayNameForShortcut:shortcut]];
        self.shortcutPopup.lastItem.representedObject = shortcut;
    }

    NSArray *rows = @[
        @[NFMakeSectionLabel(NFLocalizedString(@"New files")), [NSGridCell emptyContentView]],
        @[NFMakeLabel(NFLocalizedString(@"Default name:"), [NSFont systemFontOfSize:13], NSColor.labelColor), self.baseNameField],
        @[NFMakeLabel(NFLocalizedString(@"Default template:"), [NSFont systemFontOfSize:13], NSColor.labelColor), self.templatePopup],
        @[NFMakeLabel(NFLocalizedString(@"Default folder:"), [NSFont systemFontOfSize:13], NSColor.labelColor), directoryRow],
        @[NFMakeSectionLabel(NFLocalizedString(@"After creating")), [NSGridCell emptyContentView]],
        @[self.revealCheckbox, [NSGridCell emptyContentView]],
        @[self.openCheckbox, [NSGridCell emptyContentView]],
        @[self.soundCheckbox, [NSGridCell emptyContentView]],
        @[self.toastCheckbox, [NSGridCell emptyContentView]],
        @[NFMakeSectionLabel(NFLocalizedString(@"Application")), [NSGridCell emptyContentView]],
        @[self.launchCheckbox, [NSGridCell emptyContentView]],
        @[self.menuBarCheckbox, [NSGridCell emptyContentView]],
        @[self.dockCheckbox, [NSGridCell emptyContentView]],
        @[NFMakeLabel(NFLocalizedString(@"Global shortcut:"), [NSFont systemFontOfSize:13], NSColor.labelColor), self.shortcutPopup]
    ];
    [grid addRowWithViews:rows[0]];
    for (NSUInteger index = 1; index < rows.count; index++) {
        [grid addRowWithViews:rows[index]];
    }
    [grid columnAtIndex:0].xPlacement = NSGridCellPlacementLeading;

    NSView *container = NFGridViewContainer(grid);
    NSTextField *note = NFMakeLabel(NFLocalizedString(@"The default name is used by the app, the Finder extension, and the nfc command. Existing files are never overwritten."),
                                    [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    note.maximumNumberOfLines = 2;
    note.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:note];
    [NSLayoutConstraint activateConstraints:@[
        [note.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:20],
        [note.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [note.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28]
    ]];

    self.view = container;
    [self reloadData];
}

- (void)reloadData {
    if (!self.viewLoaded) {
        return;
    }
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
    self.baseNameField.stringValue = [config stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName];

    [self.templatePopup removeAllItems];
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (NFTemplate *template in config.templates) {
        [self.templatePopup addItemWithTitle:template.resolvedDisplayName];
        [ids addObject:template.identifier];
    }
    self.templateIDs = ids;
    NSString *defaultID = [config stringSettingForKey:@"defaultTemplateID" defaultValue:@""];
    NSUInteger index = [ids indexOfObject:defaultID];
    if (index != NSNotFound) {
        [self.templatePopup selectItemAtIndex:(NSInteger)index];
    }

    self.directoryField.stringValue = [config stringSettingForKey:@"defaultDirectory" defaultValue:@""];
    self.directoryField.placeholderString = NSHomeDirectory();
    self.revealCheckbox.state = [config boolSettingForKey:@"revealAfterCreate" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.openCheckbox.state = [config boolSettingForKey:@"openAfterCreate" defaultValue:NO] ? NSControlStateValueOn : NSControlStateValueOff;
    self.soundCheckbox.state = [config boolSettingForKey:@"playSound" defaultValue:NO] ? NSControlStateValueOn : NSControlStateValueOff;
    self.toastCheckbox.state = [config boolSettingForKey:@"showToast" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.menuBarCheckbox.state = [config boolSettingForKey:@"showMenuBarIcon" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.dockCheckbox.state = [config boolSettingForKey:@"showDockIcon" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.launchCheckbox.state = [NFLoginItemManager isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;

    NSString *shortcut = [config stringSettingForKey:@"globalShortcut" defaultValue:@"control+option+n"];
    for (NSMenuItem *item in self.shortcutPopup.itemArray) {
        if ([item.representedObject isEqualToString:shortcut]) {
            [self.shortcutPopup selectItem:item];
            break;
        }
    }
}

- (void)baseNameChanged:(id)sender {
    NSString *value = [self.baseNameField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (value.length == 0) {
        value = NFDefaultBaseName;
    }
    self.baseNameField.stringValue = value;
    NFSetSetting(value, @"defaultBaseName");
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if (notification.object == self.baseNameField) {
        [self baseNameChanged:self.baseNameField];
    } else if (notification.object == self.directoryField) {
        [self directoryChanged:self.directoryField];
    }
}

- (void)directoryChanged:(id)sender {
    NSString *value = [self.directoryField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (value.length > 0) {
        value = value.stringByExpandingTildeInPath;
    }
    NFSetSetting(value, @"defaultDirectory");
}

- (void)chooseDirectory:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.prompt = NFLocalizedString(@"Choose");
    panel.message = NFLocalizedString(@"Choose the folder where new files are created by default.");
    NSString *current = self.directoryField.stringValue;
    if (current.length > 0) {
        panel.directoryURL = [NSURL fileURLWithPath:current.stringByExpandingTildeInPath isDirectory:YES];
    }
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        self.directoryField.stringValue = panel.URL.path;
        NFSetSetting(panel.URL.path, @"defaultDirectory");
    }];
}

- (void)templateChanged:(id)sender {
    NSInteger index = self.templatePopup.indexOfSelectedItem;
    if (index < 0 || index >= (NSInteger)self.templateIDs.count) {
        return;
    }
    NFSetSetting(self.templateIDs[(NSUInteger)index], @"defaultTemplateID");
}

- (void)checkboxChanged:(NSButton *)sender {
    NSString *key = nil;
    if (sender == self.revealCheckbox) key = @"revealAfterCreate";
    else if (sender == self.openCheckbox) key = @"openAfterCreate";
    else if (sender == self.soundCheckbox) key = @"playSound";
    else if (sender == self.toastCheckbox) key = @"showToast";
    else if (sender == self.menuBarCheckbox) key = @"showMenuBarIcon";
    else if (sender == self.dockCheckbox) key = @"showDockIcon";
    BOOL value = sender.state == NSControlStateValueOn;

    if (sender == self.launchCheckbox) {
        NSError *error = nil;
        if (![NFLoginItemManager setEnabled:value error:&error]) {
            sender.state = value ? NSControlStateValueOff : NSControlStateValueOn;
            NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not change the login item"), error.localizedDescription);
            return;
        }
        NFSetSetting(@(value), @"launchAtLogin");
        if (value && [NFLoginItemManager status] == 2) {
            NFShowSettingsError(self.view.window, NFLocalizedString(@"Approval required"),
                                NFLocalizedString(@"Allow New File Creation 2 in System Settings › General › Login Items."));
        }
        return;
    }

    if (!value && (sender == self.menuBarCheckbox || sender == self.dockCheckbox)) {
        BOOL otherVisible = sender == self.menuBarCheckbox
            ? self.dockCheckbox.state == NSControlStateValueOn
            : self.menuBarCheckbox.state == NSControlStateValueOn;
        if (!otherVisible) {
            sender.state = NSControlStateValueOn;
            NFShowSettingsError(self.view.window,
                                NFLocalizedString(@"At least one icon must stay visible"),
                                NFLocalizedString(@"Turn on the Dock icon or the menu bar icon before turning off the other."));
            return;
        }
    }

    if (key.length > 0) {
        NFSetSetting(@(value), key);
    }
    if (sender == self.dockCheckbox) {
        [NSApp setActivationPolicy:value ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    }
}

- (void)shortcutChanged:(id)sender {
    NSString *shortcut = self.shortcutPopup.selectedItem.representedObject ?: @"none";
    NSError *error = nil;
    if (![[NFShortcutCenter sharedCenter] registerShortcut:shortcut error:&error]) {
        NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:NO error:nil];
        NSString *previous = [config stringSettingForKey:@"globalShortcut" defaultValue:@"none"];
        for (NSMenuItem *item in self.shortcutPopup.itemArray) {
            if ([item.representedObject isEqualToString:previous]) {
                [self.shortcutPopup selectItem:item];
                break;
            }
        }
        [[NFShortcutCenter sharedCenter] registerShortcut:previous error:nil];
        NFShowSettingsError(self.view.window, NFLocalizedString(@"The shortcut is unavailable"), error.localizedDescription);
        return;
    }
    NFSetSetting(shortcut, @"globalShortcut");
}

@end

#pragma mark - Templates

@interface NFCTemplatesSettingsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSArray<NFTemplate *> *templates;
@property (nonatomic, strong) NSButton *removeButton;
@property (nonatomic, strong) NSButton *defaultButton;
@end

@implementation NFCTemplatesSettingsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = NFLocalizedString(@"Templates");
    }
    return self;
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 660, 520)];

    NSTextField *heading = NFMakeLabel(NFLocalizedString(@"Templates included in the library"), [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold], NSColor.labelColor);
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:heading];

    NSTextField *subheading = NFMakeLabel(NFLocalizedString(@"Disabled templates do not appear in the app, the menu bar, or Finder menus."),
                                          [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    subheading.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:subheading];

    self.tableView = [[NSTableView alloc] init];
    self.tableView.style = NSTableViewStyleInset;
    self.tableView.rowHeight = 28;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;

    NSArray<NSArray *> *columns = @[
        @[@"on", NFLocalizedString(@"On"), @58.0],
        @[@"favorite", @"★", @34.0],
        @[@"name", NFLocalizedString(@"Name"), @210.0],
        @[@"category", NFLocalizedString(@"Category"), @130.0],
        @[@"file", NFLocalizedString(@"File"), @200.0]
    ];
    for (NSArray *entry in columns) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:entry[0]];
        column.title = entry[1];
        column.width = [entry[2] doubleValue];
        column.minWidth = 30;
        [self.tableView addTableColumn:column];
    }
    self.tableView.headerView = nil;

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = self.tableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;
    [container addSubview:scrollView];

    NSButton *add = [NSButton buttonWithTitle:NFLocalizedString(@"Add…") target:self action:@selector(addTemplates:)];
    self.removeButton = [NSButton buttonWithTitle:NFLocalizedString(@"Remove…") target:self action:@selector(removeTemplate:)];
    self.defaultButton = [NSButton buttonWithTitle:NFLocalizedString(@"Set as Default") target:self action:@selector(setDefaultTemplate:)];
    for (NSButton *button in @[add, self.removeButton, self.defaultButton]) {
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [heading.topAnchor constraintEqualToAnchor:container.topAnchor constant:24],
        [heading.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [heading.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28],
        [subheading.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:4],
        [subheading.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [subheading.trailingAnchor constraintEqualToAnchor:heading.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:subheading.bottomAnchor constant:14],
        [scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28],
        [scrollView.bottomAnchor constraintEqualToAnchor:add.topAnchor constant:-12],
        [add.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [add.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-24],
        [self.removeButton.leadingAnchor constraintEqualToAnchor:add.trailingAnchor constant:8],
        [self.removeButton.centerYAnchor constraintEqualToAnchor:add.centerYAnchor],
        [self.defaultButton.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [self.defaultButton.centerYAnchor constraintEqualToAnchor:add.centerYAnchor]
    ]];

    self.view = container;
    [self reloadData];
}

- (void)reloadData {
    if (!self.viewLoaded) {
        return;
    }
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
    self.templates = config.templates.copy;
    [self.tableView reloadData];
    self.removeButton.enabled = self.tableView.selectedRow >= 0;
    self.defaultButton.enabled = self.tableView.selectedRow >= 0;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.templates.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return nil;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 28)];
        cell.identifier = identifier;
        if ([identifier isEqualToString:@"on"] || [identifier isEqualToString:@"favorite"]) {
            NSButton *checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(toggleCellCheckbox:)];
            checkbox.identifier = identifier;
            checkbox.tag = row;
            checkbox.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:checkbox];
            [NSLayoutConstraint activateConstraints:@[
                [checkbox.centerXAnchor constraintEqualToAnchor:cell.centerXAnchor],
                [checkbox.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
        } else {
            NSTextField *label = [NSTextField labelWithString:@""];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.font = [NSFont systemFontOfSize:12];
            label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [cell addSubview:label];
            cell.textField = label;
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
                [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-2],
                [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
        }
    }
    if ([identifier isEqualToString:@"on"] || [identifier isEqualToString:@"favorite"]) {
        NSButton *checkbox = cell.subviews.firstObject;
        checkbox.identifier = identifier;
        checkbox.tag = row;
        checkbox.state = ([identifier isEqualToString:@"on"] ? template.enabled : template.favorite) ? NSControlStateValueOn : NSControlStateValueOff;
    } else if ([identifier isEqualToString:@"name"]) {
        cell.textField.stringValue = template.resolvedDisplayName;
    } else if ([identifier isEqualToString:@"category"]) {
        cell.textField.stringValue = NFLocalizedString(template.category);
    } else if ([identifier isEqualToString:@"file"]) {
        cell.textField.stringValue = template.fileName;
        cell.textField.textColor = NSColor.secondaryLabelColor;
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    BOOL hasSelection = self.tableView.selectedRow >= 0;
    self.removeButton.enabled = hasSelection;
    self.defaultButton.enabled = hasSelection;
}

- (void)toggleCellCheckbox:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    BOOL isFavoriteColumn = [sender.identifier isEqualToString:@"favorite"];
    NSString *identifier = template.identifier;
    BOOL newState = sender.state == NSControlStateValueOn;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        NFTemplate *current = [config templateWithIdentifier:identifier];
        if (!current) {
            return NO;
        }
        if (isFavoriteColumn) {
            current.favorite = newState;
        } else {
            current.enabled = newState;
        }
        return YES;
    } error:nil];
    [self reloadData];
}

- (void)addTemplates:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = YES;
    panel.prompt = NFLocalizedString(@"Add");
    panel.message = NFLocalizedString(@"Choose files or packages to use as templates.");
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) {
            return;
        }
        [[NFCreateCoordinator sharedCoordinator] addTemplatesFromURLs:panel.URLs window:self.view.window];
        [self reloadData];
    }];
}

- (void)removeTemplate:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NFLocalizedString(@"Remove “%@”?"), template.resolvedDisplayName];
    alert.informativeText = NFLocalizedString(@"The template is removed from the library and its file is moved to Trash.");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NFLocalizedString(@"Remove")];
    [alert addButtonWithTitle:NFLocalizedString(@"Cancel")];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) {
            return;
        }
        NSURL *fileURL = [[NFConfigStore sharedStore] templateFileURLForTemplate:template];
        [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
            NFTemplate *current = [config templateWithIdentifier:template.identifier];
            if (!current) {
                return NO;
            }
            [config.templates removeObject:current];
            if ([[config stringSettingForKey:@"defaultTemplateID" defaultValue:@""] isEqualToString:current.identifier]) {
                [config setSetting:config.templates.firstObject.identifier ?: @"" forKey:@"defaultTemplateID"];
            }
            return YES;
        } error:nil];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
            [[NSFileManager defaultManager] trashItemAtURL:fileURL resultingItemURL:nil error:nil];
        }
        [self reloadData];
    }];
}

- (void)setDefaultTemplate:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NFSetSetting(template.identifier, @"defaultTemplateID");
}

@end

#pragma mark - Finder

@interface NFCFinderSettingsViewController : NSViewController
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *includeNewFileCheckbox;
@property (nonatomic, strong) NSButton *includeAddCheckbox;
@property (nonatomic, strong) NSButton *favoritesCheckbox;
@property (nonatomic, strong) NSButton *groupCheckbox;
@property (nonatomic, strong) NSButton *iconsCheckbox;
@property (nonatomic, strong) NSPopUpButton *behaviorPopup;
@end

@implementation NFCFinderSettingsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = NFLocalizedString(@"Finder");
    }
    return self;
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 660, 520)];
    NSTextField *heading = NFMakeLabel(NFLocalizedString(@"Finder extension"), [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold], NSColor.labelColor);
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:heading];

    self.statusLabel = NFMakeLabel(@"", [NSFont systemFontOfSize:12], NSColor.secondaryLabelColor);
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.statusLabel];

    NSButton *enableButton = [NSButton buttonWithTitle:NFLocalizedString(@"Enable Extension") target:self action:@selector(enableExtension:)];
    enableButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:enableButton];

    NSButton *openSettings = [NSButton buttonWithTitle:NFLocalizedString(@"Open System Settings…") target:self action:@selector(openExtensionSettings:)];
    openSettings.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:openSettings];

    NSGridView *grid = NFMakeGrid();
    self.includeNewFileCheckbox = NFMakeCheckbox(NFLocalizedString(@"Add “New File” to Finder menus"), self, @selector(checkboxChanged:));
    self.includeAddCheckbox = NFMakeCheckbox(NFLocalizedString(@"Add “Add as Template” for selected files"), self, @selector(checkboxChanged:));
    self.favoritesCheckbox = NFMakeCheckbox(NFLocalizedString(@"Show favorites first"), self, @selector(checkboxChanged:));
    self.groupCheckbox = NFMakeCheckbox(NFLocalizedString(@"Group templates by category"), self, @selector(checkboxChanged:));
    self.iconsCheckbox = NFMakeCheckbox(NFLocalizedString(@"Show template icons"), self, @selector(checkboxChanged:));
    self.behaviorPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 220, 26) pullsDown:NO];
    [self.behaviorPopup addItemWithTitle:NFLocalizedString(@"Create immediately")];
    [self.behaviorPopup addItemWithTitle:NFLocalizedString(@"Ask for a name")];
    self.behaviorPopup.target = self;
    self.behaviorPopup.action = @selector(behaviorChanged:);

    [grid addRowWithViews:@[NFMakeSectionLabel(NFLocalizedString(@"Menu contents")), [NSGridCell emptyContentView]]];
    [grid addRowWithViews:@[self.includeNewFileCheckbox, [NSGridCell emptyContentView]]];
    [grid addRowWithViews:@[self.includeAddCheckbox, [NSGridCell emptyContentView]]];
    [grid addRowWithViews:@[self.favoritesCheckbox, [NSGridCell emptyContentView]]];
    [grid addRowWithViews:@[self.groupCheckbox, [NSGridCell emptyContentView]]];
    [grid addRowWithViews:@[self.iconsCheckbox, [NSGridCell emptyContentView]]];
    [grid addRowWithViews:@[NFMakeLabel(NFLocalizedString(@"Creation:"), [NSFont systemFontOfSize:13], NSColor.labelColor), self.behaviorPopup]];

    [container addSubview:grid];
    NSTextField *note = NFMakeLabel(NFLocalizedString(@"The Finder extension reads the shared configuration and creates files in the selected folder. If the extension is not listed, open System Settings › General › Login Items & Extensions › Finder Extensions."),
                                    [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    note.maximumNumberOfLines = 3;
    note.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:note];

    [NSLayoutConstraint activateConstraints:@[
        [heading.topAnchor constraintEqualToAnchor:container.topAnchor constant:24],
        [heading.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [self.statusLabel.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:6],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [enableButton.leadingAnchor constraintEqualToAnchor:self.statusLabel.trailingAnchor constant:12],
        [enableButton.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
        [openSettings.leadingAnchor constraintEqualToAnchor:enableButton.trailingAnchor constant:8],
        [openSettings.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
        [grid.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:22],
        [grid.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [grid.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-28],
        [note.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:22],
        [note.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [note.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28]
    ]];

    self.view = container;
    [self reloadData];
}

- (NSString *)extensionStatusText {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/pluginkit"];
    task.arguments = @[@"-m", @"-i", @"com.sid.newfilecreation2.finder"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        return NFLocalizedString(@"Finder extension status unavailable");
    }
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (output.length == 0) {
        return NFLocalizedString(@"Finder extension: not registered. Build and open the app once.");
    }
    if ([output hasPrefix:@"+"]) {
        return NFLocalizedString(@"Finder extension: enabled");
    }
    if ([output hasPrefix:@"-"]) {
        return NFLocalizedString(@"Finder extension: disabled");
    }
    return NFLocalizedString(@"Finder extension: registered");
}

- (void)reloadData {
    if (!self.viewLoaded) {
        return;
    }
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
    self.statusLabel.stringValue = [self extensionStatusText];
    self.includeNewFileCheckbox.state = [config boolSettingForKey:@"includeNewFileInFinderMenu" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.includeAddCheckbox.state = [config boolSettingForKey:@"includeAddAsTemplate" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.favoritesCheckbox.state = [config boolSettingForKey:@"favoritesFirst" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    self.groupCheckbox.state = [config boolSettingForKey:@"groupByCategory" defaultValue:NO] ? NSControlStateValueOn : NSControlStateValueOff;
    self.iconsCheckbox.state = [config boolSettingForKey:@"showFileIcons" defaultValue:YES] ? NSControlStateValueOn : NSControlStateValueOff;
    NSString *behavior = [config stringSettingForKey:@"finderCreationBehavior" defaultValue:@"instant"];
    [self.behaviorPopup selectItemAtIndex:[behavior isEqualToString:@"ask"] ? 1 : 0];
}

- (void)checkboxChanged:(NSButton *)sender {
    NSString *key = nil;
    if (sender == self.includeNewFileCheckbox) key = @"includeNewFileInFinderMenu";
    else if (sender == self.includeAddCheckbox) key = @"includeAddAsTemplate";
    else if (sender == self.favoritesCheckbox) key = @"favoritesFirst";
    else if (sender == self.groupCheckbox) key = @"groupByCategory";
    else if (sender == self.iconsCheckbox) key = @"showFileIcons";
    if (key.length > 0) {
        NFSetSetting(@(sender.state == NSControlStateValueOn), key);
    }
}

- (void)behaviorChanged:(id)sender {
    NFSetSetting(self.behaviorPopup.indexOfSelectedItem == 1 ? @"ask" : @"instant", @"finderCreationBehavior");
}

- (void)enableExtension:(id)sender {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/pluginkit"];
    task.arguments = @[@"-e", @"use", @"-i", @"com.sid.newfilecreation2.finder"];
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not enable the Finder extension"), error.localizedDescription);
        return;
    }
    [task waitUntilExit];
    [self reloadData];
    if (task.terminationStatus != 0) {
        NFShowSettingsError(self.view.window, NFLocalizedString(@"The Finder extension could not be enabled"),
                            NFLocalizedString(@"Open System Settings and enable “New File Creation 2 Finder” manually."));
    }
}

- (void)openExtensionSettings:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.Extensions-Settings.extension"];
    if (!url) {
        url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"];
    }
    [[NSWorkspace sharedWorkspace] openURL:url];
}

@end

#pragma mark - Advanced

@interface NFCAdvancedSettingsViewController : NSViewController
@property (nonatomic, strong) NSTextField *configPathLabel;
@property (nonatomic, strong) NSTextField *templatesPathLabel;
@property (nonatomic, strong) NSTextField *cliStatusLabel;
@end

@implementation NFCAdvancedSettingsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = NFLocalizedString(@"Advanced");
    }
    return self;
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 660, 520)];

    NSTextField *heading = NFMakeLabel(NFLocalizedString(@"Configuration and command line"), [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold], NSColor.labelColor);
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:heading];

    self.configPathLabel = NFMakeLabel(@"", [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    self.configPathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.configPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.configPathLabel.selectable = YES;
    [container addSubview:self.configPathLabel];

    NSButton *revealConfig = [NSButton buttonWithTitle:NFLocalizedString(@"Reveal Config") target:self action:@selector(revealConfig:)];
    revealConfig.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:revealConfig];

    NSButton *exportButton = [NSButton buttonWithTitle:NFLocalizedString(@"Export…") target:self action:@selector(exportConfig:)];
    exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:exportButton];

    NSButton *importButton = [NSButton buttonWithTitle:NFLocalizedString(@"Import…") target:self action:@selector(importConfig:)];
    importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:importButton];

    NSButton *resetButton = [NSButton buttonWithTitle:NFLocalizedString(@"Reset Configuration…") target:self action:@selector(resetConfig:)];
    resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:resetButton];

    self.templatesPathLabel = NFMakeLabel(@"", [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    self.templatesPathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.templatesPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.templatesPathLabel.selectable = YES;
    [container addSubview:self.templatesPathLabel];

    NSButton *revealTemplates = [NSButton buttonWithTitle:NFLocalizedString(@"Open Templates Folder") target:self action:@selector(revealTemplates:)];
    revealTemplates.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:revealTemplates];

    NSTextField *cliHeading = NFMakeLabel(NFLocalizedString(@"Command-line tool"), [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold], NSColor.labelColor);
    cliHeading.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:cliHeading];

    self.cliStatusLabel = NFMakeLabel(@"", [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    self.cliStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cliStatusLabel];

    NSButton *installCLI = [NSButton buttonWithTitle:NFLocalizedString(@"Install nfc") target:self action:@selector(installCLI:)];
    installCLI.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:installCLI];

    NSButton *uninstallCLI = [NSButton buttonWithTitle:NFLocalizedString(@"Uninstall nfc") target:self action:@selector(uninstallCLI:)];
    uninstallCLI.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:uninstallCLI];

    NSButton *revealLog = [NSButton buttonWithTitle:NFLocalizedString(@"Reveal Log") target:self action:@selector(revealLog:)];
    revealLog.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:revealLog];

    NSButton *welcome = [NSButton buttonWithTitle:NFLocalizedString(@"Show Welcome Again") target:self action:@selector(showWelcome:)];
    welcome.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:welcome];

    NSTextField *note = NFMakeLabel(NFLocalizedString(@"The app and nfc coordinate writes with a lock and atomic replacement. The Finder extension reads the configuration only."),
                                    [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    note.maximumNumberOfLines = 2;
    note.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:note];

    [NSLayoutConstraint activateConstraints:@[
        [heading.topAnchor constraintEqualToAnchor:container.topAnchor constant:24],
        [heading.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [self.configPathLabel.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:12],
        [self.configPathLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [self.configPathLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28],
        [revealConfig.topAnchor constraintEqualToAnchor:self.configPathLabel.bottomAnchor constant:8],
        [revealConfig.leadingAnchor constraintEqualToAnchor:self.configPathLabel.leadingAnchor],
        [exportButton.leadingAnchor constraintEqualToAnchor:revealConfig.trailingAnchor constant:8],
        [exportButton.centerYAnchor constraintEqualToAnchor:revealConfig.centerYAnchor],
        [importButton.leadingAnchor constraintEqualToAnchor:exportButton.trailingAnchor constant:8],
        [importButton.centerYAnchor constraintEqualToAnchor:revealConfig.centerYAnchor],
        [resetButton.leadingAnchor constraintEqualToAnchor:importButton.trailingAnchor constant:8],
        [resetButton.centerYAnchor constraintEqualToAnchor:revealConfig.centerYAnchor],
        [self.templatesPathLabel.topAnchor constraintEqualToAnchor:revealConfig.bottomAnchor constant:20],
        [self.templatesPathLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [self.templatesPathLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28],
        [revealTemplates.topAnchor constraintEqualToAnchor:self.templatesPathLabel.bottomAnchor constant:8],
        [revealTemplates.leadingAnchor constraintEqualToAnchor:self.templatesPathLabel.leadingAnchor],
        [cliHeading.topAnchor constraintEqualToAnchor:revealTemplates.bottomAnchor constant:28],
        [cliHeading.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [self.cliStatusLabel.topAnchor constraintEqualToAnchor:cliHeading.bottomAnchor constant:8],
        [self.cliStatusLabel.leadingAnchor constraintEqualToAnchor:cliHeading.leadingAnchor],
        [self.cliStatusLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28],
        [installCLI.topAnchor constraintEqualToAnchor:self.cliStatusLabel.bottomAnchor constant:8],
        [installCLI.leadingAnchor constraintEqualToAnchor:self.cliStatusLabel.leadingAnchor],
        [uninstallCLI.leadingAnchor constraintEqualToAnchor:installCLI.trailingAnchor constant:8],
        [uninstallCLI.centerYAnchor constraintEqualToAnchor:installCLI.centerYAnchor],
        [revealLog.leadingAnchor constraintEqualToAnchor:uninstallCLI.trailingAnchor constant:8],
        [revealLog.centerYAnchor constraintEqualToAnchor:installCLI.centerYAnchor],
        [welcome.topAnchor constraintEqualToAnchor:installCLI.bottomAnchor constant:24],
        [welcome.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [note.topAnchor constraintEqualToAnchor:welcome.bottomAnchor constant:24],
        [note.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:28],
        [note.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-28]
    ]];

    self.view = container;
    [self reloadData];
}

- (void)reloadData {
    if (!self.viewLoaded) {
        return;
    }
    self.configPathLabel.stringValue = [NFConfigStore sharedStore].configURL.path;
    self.templatesPathLabel.stringValue = [NFConfigStore sharedStore].templatesURL.path;
    if ([NFCLIInstallController isInstalled]) {
        self.cliStatusLabel.stringValue = [NSString stringWithFormat:NFLocalizedString(@"Installed at %@%@"),
                                           [NFCLIInstallController installPath],
                                           [NFCLIInstallController isInstallDirectoryOnPATH] ? @"" : NFLocalizedString(@" (not on PATH)")];
    } else {
        self.cliStatusLabel.stringValue = NFLocalizedString(@"Not installed. The bundled helper is at Contents/Helpers/nfc.");
    }
}

- (void)revealConfig:(id)sender {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NFConfigStore sharedStore].configURL]];
}

- (void)revealTemplates:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NFConfigStore sharedStore].templatesURL];
}

- (void)exportConfig:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = @"new-file-creation-2-config.json";
    panel.allowedContentTypes = @[];
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil];
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:[config dictionaryRepresentation]
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:&error];
        if (!data || ![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) {
            NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not export the configuration"), error.localizedDescription);
        }
    }];
}

- (void)importConfig:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        NSData *data = [NSData dataWithContentsOfURL:panel.URL];
        NSError *error = nil;
        id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
        if (![object isKindOfClass:[NSDictionary class]]) {
            NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not import the configuration"),
                                error.localizedDescription ?: NFLocalizedString(@"The file is not valid JSON."));
            return;
        }
        NFConfig *imported = [[NFConfig alloc] initWithDictionary:object];
        if (![[NFConfigStore sharedStore] replaceConfig:imported error:&error]) {
            NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not import the configuration"), error.localizedDescription);
            return;
        }
        [self reloadData];
    }];
}

- (void)resetConfig:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NFLocalizedString(@"Reset the configuration?");
    alert.informativeText = NFLocalizedString(@"Settings and the template library are reset. Template files in the Templates folder are kept.");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NFLocalizedString(@"Reset")];
    [alert addButtonWithTitle:NFLocalizedString(@"Cancel")];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) {
            return;
        }
        NSError *error = nil;
        if (![[NFConfigStore sharedStore] replaceConfig:[NFConfig defaultConfig] error:&error]) {
            NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not reset the configuration"), error.localizedDescription);
        }
    }];
}

- (void)installCLI:(id)sender {
    NSError *error = nil;
    if (![NFCLIInstallController install:&error]) {
        NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not install nfc"), error.localizedDescription);
        return;
    }
    [self reloadData];
}

- (void)uninstallCLI:(id)sender {
    NSError *error = nil;
    if (![NFCLIInstallController uninstall:&error]) {
        NFShowSettingsError(self.view.window, NFLocalizedString(@"Could not uninstall nfc"), error.localizedDescription);
        return;
    }
    [self reloadData];
}

- (void)revealLog:(id)sender {
    NSURL *log = [NFPaths logFileURL];
    if (![[NSFileManager defaultManager] fileExistsAtPath:log.path]) {
        [[NFLogger sharedLogger] info:@"Log opened from Settings"];
    }
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[log]];
}

- (void)showWelcome:(id)sender {
    if (self.presentingViewController) {
        // no-op
    }
    SEL selector = NSSelectorFromString(@"showWelcomeFromSettings:");
    if ([NSApp.delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [NSApp.delegate performSelector:selector withObject:sender];
#pragma clang diagnostic pop
    }
}

@end

#pragma mark - About

@interface NFCAboutSettingsViewController : NSViewController
@end

@implementation NFCAboutSettingsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = NFLocalizedString(@"About");
    }
    return self;
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 660, 520)];

    NSImageView *icon = [[NSImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = NSApp.applicationIconImage;
    [container addSubview:icon];

    NSTextField *name = NFMakeLabel(@"New File Creation 2", [NSFont systemFontOfSize:24 weight:NSFontWeightBold], NSColor.labelColor);
    name.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:name];

    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: NFCVersionString;
    NSTextField *versionLabel = NFMakeLabel([NSString stringWithFormat:NFLocalizedString(@"Version %@"), version], [NSFont systemFontOfSize:12], NSColor.secondaryLabelColor);
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:versionLabel];

    NSTextField *tagline = NFMakeLabel(NFLocalizedString(@"Create files from templates in Finder, the menu bar, the library, and the command line."),
                                       [NSFont systemFontOfSize:13], NSColor.labelColor);
    tagline.maximumNumberOfLines = 2;
    tagline.alignment = NSTextAlignmentCenter;
    tagline.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:tagline];

    NSTextField *copyright = NFMakeLabel(NFLocalizedString(@"Copyright © 2024–2026 Sergio Martinez-Losa\nMIT License"),
                                         [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    copyright.maximumNumberOfLines = 2;
    copyright.alignment = NSTextAlignmentCenter;
    copyright.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:copyright];

    NSButton *license = [NSButton buttonWithTitle:NFLocalizedString(@"View License") target:self action:@selector(openLicense:)];
    license.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:license];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:container.topAnchor constant:54],
        [icon.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:96],
        [icon.heightAnchor constraintEqualToConstant:96],
        [name.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:18],
        [name.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [versionLabel.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:4],
        [versionLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [tagline.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:22],
        [tagline.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:60],
        [tagline.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-60],
        [copyright.topAnchor constraintEqualToAnchor:tagline.bottomAnchor constant:22],
        [copyright.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [license.topAnchor constraintEqualToAnchor:copyright.bottomAnchor constant:14],
        [license.centerXAnchor constraintEqualToAnchor:container.centerXAnchor]
    ]];

    self.view = container;
}

- (void)openLicense:(id)sender {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"LICENSE" withExtension:nil];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NFLocalizedString(@"MIT License");
    alert.informativeText = NFLocalizedString(@"Copyright © 2024–2026 Sergio Martinez-Losa. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction.");
    [alert addButtonWithTitle:NFLocalizedString(@"OK")];
    [alert runModal];
}

@end

#pragma mark - Window controller

@interface NFCSettingsWindowController ()
@property (nonatomic, strong) NSTabViewController *tabViewController;
@end

@implementation NFCSettingsWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 680, 560)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = NFLocalizedString(@"Settings");
    window.releasedWhenClosed = NO;
    window.toolbarStyle = NSWindowToolbarStylePreference;
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        _tabViewController = [[NSTabViewController alloc] init];
        _tabViewController.tabStyle = NSTabViewControllerTabStyleToolbar;
        _tabViewController.transitionOptions = NSViewControllerTransitionCrossfade;
        _tabViewController.view.identifier = @"SettingsTabs";
        _tabViewController.view.accessibilityLabel = NFLocalizedString(@"Settings");

        NSArray<NSViewController *> *panes = @[
            [[NFCGeneralSettingsViewController alloc] init],
            [[NFCTemplatesSettingsViewController alloc] init],
            [[NFCFinderSettingsViewController alloc] init],
            [[NFCAdvancedSettingsViewController alloc] init],
            [[NFCAboutSettingsViewController alloc] init]
        ];
        for (NSViewController *pane in panes) {
            [_tabViewController addChildViewController:pane];
        }
        window.contentViewController = _tabViewController;
        window.contentMinSize = NSMakeSize(680, 500);
    }
    return self;
}

- (void)showWindow:(id)sender {
    [self reloadPanes];
    [super showWindow:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)reloadPanes {
    for (NSTabViewItem *item in self.tabViewController.tabViewItems) {
        NSViewController *pane = item.viewController;
        if ([pane respondsToSelector:@selector(reloadData)]) {
            [(id<NFCSettingsPaneReloading>)pane reloadData];
        }
    }
}

@end

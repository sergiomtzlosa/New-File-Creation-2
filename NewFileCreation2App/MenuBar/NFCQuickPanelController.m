#import "NFCQuickPanelController.h"
#import "NFCFloatingPanel.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFFinderMenuBuilder.h"
#import "NFFilePromiseProvider.h"
#import "NFCreateCoordinator.h"
#import "NFLocalization.h"

static NSScreen *NFCScreenContainingPoint(NSPoint point) {
    for (NSScreen *screen in NSScreen.screens) {
        if (NSMouseInRect(point, screen.frame, NO)) {
            return screen;
        }
    }
    return NSScreen.screens.firstObject ?: NSScreen.mainScreen;
}

/// The table is the first responder after a row is clicked. Return and Escape
/// must keep working there, not only in the search field.
@interface NFCQuickPanelTableView : NSTableView
@property (nonatomic, copy, nullable) void (^onReturnKey)(void);
@property (nonatomic, copy, nullable) void (^onCancelKey)(void);
@end

@implementation NFCQuickPanelTableView
- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 36 || event.keyCode == 76) {
        if (self.onReturnKey) {
            self.onReturnKey();
            return;
        }
    } else if (event.keyCode == 53) {
        if (self.onCancelKey) {
            self.onCancelKey();
            return;
        }
    }
    [super keyDown:event];
}
@end

@interface NFCQuickPanelController () <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSArray<NFTemplate *> *templates;
@property (nonatomic, strong) NSTextField *emptyLabel;
@property (nonatomic, assign) BOOL draggingPromise;
@end

@implementation NFCQuickPanelController

- (instancetype)init {
    NFCFloatingPanel *panel = [NFCFloatingPanel floatingPanelWithContentRect:NSMakeRect(0, 0, 460, 420)
                                                                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                                            NSWindowStyleMaskFullSizeContentView];
    panel.title = NFLocalizedString(@"Quick New File");
    panel.titleVisibility = NSWindowTitleHidden;
    panel.titlebarAppearsTransparent = YES;
    panel.movableByWindowBackground = YES;
    panel.delegate = self;

    self = [super initWithWindow:panel];
    if (self) {
        [self setupInterface];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(configDidChange:) name:NFConfigDidChangeNotification object:nil];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(configDidChange:)
                                                                name:NFConfigDistributedChangeNotification
                                                              object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.window.isVisible) {
            [self reloadData];
        }
    });
}

- (void)setupInterface {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    NSButton *getStarted = [NSButton buttonWithImage:NSApp.applicationIconImage
                                              target:self
                                              action:@selector(openGetStarted:)];
    getStarted.identifier = @"QuickPanelGetStartedButton";
    getStarted.translatesAutoresizingMaskIntoConstraints = NO;
    getStarted.bordered = NO;
    getStarted.imagePosition = NSImageOnly;
    getStarted.imageScaling = NSImageScaleProportionallyUpOrDown;
    getStarted.toolTip = NFLocalizedString(@"Get Started");
    getStarted.accessibilityLabel = NFLocalizedString(@"Get Started");
    [content addSubview:getStarted];

    NSTextField *title = [NSTextField labelWithString:NFLocalizedString(@"Quick New File")];
    title.identifier = @"QuickPanelTitle";
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    title.alignment = NSTextAlignmentCenter;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    [title setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    [content addSubview:title];

    NSImage *gearImage = [NSImage imageWithSystemSymbolName:@"gearshape"
                                  accessibilityDescription:NFLocalizedString(@"Settings…")];
    NSButton *preferences = [NSButton buttonWithImage:gearImage target:self action:@selector(openPreferences:)];
    preferences.identifier = @"QuickPanelPreferencesButton";
    preferences.translatesAutoresizingMaskIntoConstraints = NO;
    preferences.bordered = NO;
    preferences.imagePosition = NSImageOnly;
    preferences.toolTip = NFLocalizedString(@"Settings…");
    preferences.accessibilityLabel = NFLocalizedString(@"Settings…");
    [content addSubview:preferences];

    NSImage *quitImage = [NSImage imageWithSystemSymbolName:@"power"
                                  accessibilityDescription:NFLocalizedString(@"Quit New File Creation 2")];
    NSButton *quit = [NSButton buttonWithImage:quitImage target:self action:@selector(quitAction:)];
    quit.identifier = @"QuickPanelQuitButton";
    quit.translatesAutoresizingMaskIntoConstraints = NO;
    quit.bordered = NO;
    quit.imagePosition = NSImageOnly;
    quit.toolTip = NFLocalizedString(@"Quit New File Creation 2");
    quit.accessibilityLabel = NFLocalizedString(@"Quit New File Creation 2");
    [content addSubview:quit];

    self.searchField = [[NSSearchField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.identifier = @"QuickPanelSearchField";
    self.searchField.placeholderString = NFLocalizedString(@"Search templates");
    self.searchField.delegate = self;
    self.searchField.sendsWholeSearchString = NO;
    self.searchField.sendsSearchStringImmediately = YES;
    self.searchField.target = self;
    self.searchField.action = @selector(searchChanged:);
    [content addSubview:self.searchField];

    self.tableView = [[NFCQuickPanelTableView alloc] init];
    self.tableView.identifier = @"QuickPanelTemplateTable";
    self.tableView.accessibilityLabel = NFLocalizedString(@"Quick New File");
    self.tableView.headerView = nil;
    self.tableView.rowHeight = 52;
    self.tableView.style = NSTableViewStylePlain;
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    self.tableView.allowsEmptySelection = YES;
    self.tableView.backgroundColor = NSColor.clearColor;
    self.tableView.usesAlternatingRowBackgroundColors = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(tableDoubleClicked:);
    __weak typeof(self) weakSelf = self;
    ((NFCQuickPanelTableView *)self.tableView).onReturnKey = ^{
        [weakSelf createSelected];
    };
    ((NFCQuickPanelTableView *)self.tableView).onCancelKey = ^{
        [weakSelf hidePanel];
    };
    [self.tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"template"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:column];

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = self.tableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    [content addSubview:scrollView];

    self.emptyLabel = [NSTextField labelWithString:NFLocalizedString(@"No matching templates")];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.textColor = NSColor.secondaryLabelColor;
    self.emptyLabel.font = [NSFont systemFontOfSize:13];
    self.emptyLabel.hidden = YES;
    [content addSubview:self.emptyLabel];

    NSTextField *hint = [NSTextField labelWithString:NFLocalizedString(@"↩ Create file    ⠿ Drag to Finder    esc Close")];
    hint.identifier = @"QuickPanelDragHint";
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = NSColor.tertiaryLabelColor;
    [content addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [title.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:56],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:getStarted.leadingAnchor constant:-10],
        [getStarted.trailingAnchor constraintEqualToAnchor:preferences.leadingAnchor constant:-8],
        [getStarted.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [getStarted.widthAnchor constraintEqualToConstant:22],
        [getStarted.heightAnchor constraintEqualToConstant:22],
        [preferences.trailingAnchor constraintEqualToAnchor:quit.leadingAnchor constant:-4],
        [preferences.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [preferences.widthAnchor constraintEqualToConstant:24],
        [preferences.heightAnchor constraintEqualToConstant:24],
        [quit.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [quit.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [quit.widthAnchor constraintEqualToConstant:24],
        [quit.heightAnchor constraintEqualToConstant:24],
        [self.searchField.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [self.searchField.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [self.searchField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [scrollView.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:10],
        [scrollView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12],
        [scrollView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [scrollView.bottomAnchor constraintEqualToAnchor:hint.topAnchor constant:-8],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:scrollView.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:scrollView.centerYAnchor],
        [hint.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
        [hint.centerXAnchor constraintEqualToAnchor:content.centerXAnchor]
    ]];
}

- (NFConfig *)config {
    return [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
}

- (void)showPanel {
    [self showPanelAnchoredToRect:NSZeroRect];
}

- (void)showPanelAnchoredToRect:(NSRect)screenRect {
    [self reloadData];
    NSPoint referencePoint = NSEqualRects(screenRect, NSZeroRect)
        ? NSEvent.mouseLocation
        : NSMakePoint(NSMidX(screenRect), NSMidY(screenRect));
    NSScreen *screen = NFCScreenContainingPoint(referencePoint);
    if (screen) {
        NSRect visible = screen.visibleFrame;
        NSRect frame = self.window.frame;
        NSPoint origin = NSZeroPoint;
        if (!NSEqualRects(screenRect, NSZeroRect)) {
            origin = NSMakePoint(NSMidX(screenRect) - NSWidth(frame) / 2.0,
                                 NSMinY(screenRect) - NSHeight(frame) - 8.0);
        } else {
            origin = NSMakePoint(NSMidX(visible) - NSWidth(frame) / 2.0,
                                 NSMaxY(visible) - NSHeight(frame) - 90);
        }
        CGFloat minX = NSMinX(visible) + 8.0;
        CGFloat maxX = NSMaxX(visible) - NSWidth(frame) - 8.0;
        origin.x = MIN(MAX(origin.x, minX), MAX(minX, maxX));
        if (origin.y < NSMinY(visible) + 8.0) {
            origin.y = NSMinY(visible) + 8.0;
        }
        [self.window setFrameOrigin:origin];
    }
    self.draggingPromise = NO;
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.searchField];
    self.searchField.stringValue = @"";
    [self reloadData];
}

- (void)hidePanel {
    [self.window orderOut:nil];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    if (self.draggingPromise) {
        return;
    }
    [self hidePanel];
}

- (void)reloadData {
    if (!self.isWindowLoaded) {
        return;
    }
    NFConfig *config = [self config];
    NSString *query = self.searchField.stringValue.lowercaseString;
    NSMutableArray<NFTemplate *> *matches = [NSMutableArray array];
    NSArray<NFTemplate *> *ordered = [NFFinderMenuBuilder orderedTemplatesForConfig:config favoritesFirst:YES];
    for (NFTemplate *template in ordered) {
        if (query.length > 0) {
            BOOL match = [template.resolvedDisplayName.lowercaseString containsString:query] ||
                         [template.fileName.lowercaseString containsString:query] ||
                         [template.category.lowercaseString containsString:query] ||
                         [template.fileExtension.lowercaseString containsString:query];
            if (!match) {
                continue;
            }
        }
        [matches addObject:template];
    }
    self.templates = matches;
    [self.tableView reloadData];
    self.emptyLabel.hidden = matches.count > 0;
    if (matches.count > 0) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.tableView scrollRowToVisible:0];
    }
}

- (void)searchChanged:(NSSearchField *)sender {
    [self reloadData];
}

#pragma mark - Table view

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.templates.count;
}

- (nullable id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return nil;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NSURL *templateURL = [[NFConfigStore sharedStore] templateFileURLForTemplate:template];
    if (![[NSFileManager defaultManager] fileExistsAtPath:templateURL.path]) {
        return nil;
    }
    NSString *baseName = [[self config] stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName];
    NFFilePromiseProvider *provider = [[NFFilePromiseProvider alloc] initWithTemplate:template
                                                                         templateURL:templateURL
                                                                            fileName:[NFFilePromiseProvider promisedFileNameForTemplate:template
                                                                                                                         defaultBaseName:baseName]];
    __weak typeof(self) weakSelf = self;
    provider.didWriteFile = ^(NSURL *url) {
        [weakSelf recordDraggedFile:url forTemplate:template];
    };
    return provider;
}

- (void)recordDraggedFile:(NSURL *)url forTemplate:(NFTemplate *)template {
    NSError *error = nil;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
        NFTemplate *current = [latest templateWithIdentifier:template.identifier] ?: template;
        [latest recordUsageOfTemplate:current];
        [latest addRecentFile:url.path];
        [latest setSetting:url.URLByDeletingLastPathComponent.path forKey:@"lastUsedDirectory"];
        return YES;
    } error:&error];
    if (error) {
        NSLog(@"New File Creation 2: could not save drag metadata: %@", error.localizedDescription);
    }
    [[NFCreateCoordinator sharedCoordinator] playConfiguredSound];
}

- (void)openPreferences:(id)sender {
    [self hidePanel];
    if (self.onOpenPreferences) {
        self.onOpenPreferences();
    }
}

- (void)openGetStarted:(id)sender {
    [self hidePanel];
    if (self.onOpenGetStarted) {
        self.onOpenGetStarted();
    }
}

- (void)quitAction:(id)sender {
    [NSApp terminate:nil];
}

- (void)tableView:(NSTableView *)tableView
    draggingSession:(NSDraggingSession *)session
   willBeginAtPoint:(NSPoint)screenPoint
      forRowIndexes:(NSIndexSet *)rowIndexes {
    self.draggingPromise = YES;
    session.draggingFormation = NSDraggingFormationNone;
}

- (void)finishDraggingWithOperation:(NSDragOperation)operation {
    self.draggingPromise = NO;
    if (operation == NSDragOperationNone) {
        return;
    }
    if (![[self config] boolSettingForKey:@"keepQuickPanelOpenAfterDrop" defaultValue:NO]) {
        [self hidePanel];
    }
}

- (void)tableView:(NSTableView *)tableView
    draggingSession:(NSDraggingSession *)session
     endedAtPoint:(NSPoint)screenPoint
       operation:(NSDragOperation)operation {
    [self finishDraggingWithOperation:operation];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return nil;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"quick-cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 420, 52)];
        cell.identifier = @"quick-cell";
        NSImageView *icon = [[NSImageView alloc] init];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:icon];
        cell.imageView = icon;
        NSTextField *name = [NSTextField labelWithString:@""];
        name.translatesAutoresizingMaskIntoConstraints = NO;
        name.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        name.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:name];
        cell.textField = name;
        NSTextField *detail = [NSTextField labelWithString:@""];
        detail.translatesAutoresizingMaskIntoConstraints = NO;
        detail.font = [NSFont systemFontOfSize:11];
        detail.textColor = NSColor.secondaryLabelColor;
        detail.lineBreakMode = NSLineBreakByTruncatingTail;
        detail.tag = 200;
        [cell addSubview:detail];
        NSTextField *star = [NSTextField labelWithString:@"★"];
        star.translatesAutoresizingMaskIntoConstraints = NO;
        star.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        star.textColor = NSColor.systemYellowColor;
        star.alignment = NSTextAlignmentRight;
        star.tag = 201;
        [cell addSubview:star];
        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:10],
            [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:32],
            [icon.heightAnchor constraintEqualToConstant:32],
            [name.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
            [name.topAnchor constraintEqualToAnchor:cell.topAnchor constant:8],
            [name.trailingAnchor constraintLessThanOrEqualToAnchor:star.leadingAnchor constant:-8],
            [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
            [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2],
            [detail.trailingAnchor constraintLessThanOrEqualToAnchor:star.leadingAnchor constant:-8],
            [star.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-12],
            [star.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [star.widthAnchor constraintEqualToConstant:18]
        ]];
    }
    cell.imageView.image = [NFFinderMenuBuilder iconForTemplate:template];
    cell.textField.stringValue = template.resolvedDisplayName;
    NSString *extension = template.fileExtension.length > 0
        ? [@"." stringByAppendingString:template.fileExtension]
        : NFLocalizedString(@"no extension");
    NSTextField *detail = [cell viewWithTag:200];
    detail.stringValue = [NSString stringWithFormat:@"%@ · %@", NFLocalizedString(template.category), extension];
    NSTextField *star = [cell viewWithTag:201];
    star.hidden = !template.favorite;
    cell.toolTip = [NSString stringWithFormat:NFLocalizedString(@"%@ — drag to create %@"),
                    template.fileName, template.resolvedDisplayName];
    cell.accessibilityLabel = [NSString stringWithFormat:NFLocalizedString(@"%@ template, drag to create a file"),
                               template.resolvedDisplayName];
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
}

- (void)tableDoubleClicked:(id)sender {
    [self createSelected];
}

- (void)searchFieldDidStartSearching:(NSSearchField *)sender {
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        [self createSelected];
        return YES;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        [self hidePanel];
        return YES;
    }
    if (commandSelector == @selector(moveDown:)) {
        NSInteger row = MIN(self.tableView.selectedRow + 1, (NSInteger)self.templates.count - 1);
        if (row >= 0) {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [self.tableView scrollRowToVisible:row];
        }
        return YES;
    }
    if (commandSelector == @selector(moveUp:)) {
        NSInteger row = MAX(self.tableView.selectedRow - 1, 0);
        if (self.templates.count > 0) {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [self.tableView scrollRowToVisible:row];
        }
        return YES;
    }
    return NO;
}

- (void)createSelected {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 && self.templates.count > 0) {
        row = 0;
    }
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        NSBeep();
        return;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    [self hidePanel];
    if (self.onCreateTemplate) {
        self.onCreateTemplate(template);
    }
}

@end

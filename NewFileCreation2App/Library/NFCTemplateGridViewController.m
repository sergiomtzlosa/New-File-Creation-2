#import "NFCTemplateGridViewController.h"
#import "NFCTemplateCollectionItem.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFCreateCoordinator.h"
#import "NFCToastPresenter.h"
#import "NFLocalization.h"

@class NFCTemplateGridViewController;

@interface NFCTemplateCollectionView : NSCollectionView
@property (nonatomic, copy, nullable) NSMenu *(^menuProvider)(NSIndexPath *indexPath);
@property (nonatomic, copy, nullable) void (^onReturnKey)(void);
@property (nonatomic, strong, nullable) NSIndexPath *contextIndexPath;
@end

@implementation NFCTemplateCollectionView
- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    NSString *characters = event.charactersIgnoringModifiers;
    if ((event.keyCode == 36 || event.keyCode == 76 ||
         [characters isEqualToString:@"\r"] || [characters isEqualToString:@"\n"]) &&
        self.onReturnKey) {
        self.onReturnKey();
        return;
    }
    [super keyDown:event];
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSIndexPath *indexPath = [self indexPathForItemAtPoint:point];
    if (!indexPath) {
        return nil;
    }
    self.contextIndexPath = indexPath;
    if (![self.selectionIndexPaths containsObject:indexPath]) {
        [self deselectAll:self];
        [self selectItemsAtIndexPaths:[NSSet setWithObject:indexPath] scrollPosition:NSCollectionViewScrollPositionNone];
    }
    return self.menuProvider ? self.menuProvider(indexPath) : nil;
}
- (void)deselectAll:(nullable id)sender {
    [super deselectAll:sender];
}
@end

@interface NFCTemplateGridViewController () <NSCollectionViewDataSource, NSCollectionViewDelegate>
@property (nonatomic, strong) NFCTemplateCollectionView *collectionView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSArray<NFTemplate *> *displayedTemplates;
@property (nonatomic, strong) NSView *emptyStateView;
@property (nonatomic, strong) NFTemplate *contextTemplate;
@end

@implementation NFCTemplateGridViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _filter = NFCTemplateFilterAll;
        _sortMode = NFTemplateSortManual;
        _displayedTemplates = @[];
    }
    return self;
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 620, 600)];
    self.view = root;

    NSCollectionViewFlowLayout *layout = [[NSCollectionViewFlowLayout alloc] init];
    layout.itemSize = NSMakeSize(168, 150);
    layout.sectionInset = NSEdgeInsetsMake(22, 22, 22, 22);
    layout.minimumInteritemSpacing = 14;
    layout.minimumLineSpacing = 14;

    self.collectionView = [[NFCTemplateCollectionView alloc] initWithFrame:root.bounds];
    self.collectionView.identifier = @"TemplateGrid";
    self.collectionView.accessibilityLabel = NFLocalizedString(@"Templates");
    self.collectionView.collectionViewLayout = layout;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.selectable = YES;
    self.collectionView.allowsMultipleSelection = NO;
    self.collectionView.backgroundColors = @[NSColor.clearColor];
    [self.collectionView registerClass:[NFCTemplateCollectionItem class] forItemWithIdentifier:@"template"];
    [self.collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];

    __weak typeof(self) weakSelf = self;
    self.collectionView.menuProvider = ^NSMenu *(NSIndexPath *indexPath) {
        return [weakSelf contextMenuForIndexPath:indexPath];
    };
    self.collectionView.onReturnKey = ^{
        NFTemplate *template = weakSelf.selectedTemplate;
        if (template && weakSelf.onCreate) {
            weakSelf.onCreate(template);
        }
    };

    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.collectionView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.drawsBackground = NO;
    [root addSubview:self.scrollView];

    self.emptyStateView = [[NSView alloc] init];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.emptyStateView];

    NSImageView *emptyIcon = [[NSImageView alloc] init];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.image = [NSImage imageWithSystemSymbolName:@"doc.badge.plus" accessibilityDescription:NFLocalizedString(@"No templates")];
    emptyIcon.contentTintColor = NSColor.tertiaryLabelColor;
    emptyIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:42 weight:NSFontWeightRegular];
    [self.emptyStateView addSubview:emptyIcon];

    NSTextField *emptyTitle = [NSTextField labelWithString:NFLocalizedString(@"No Templates")];
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptyTitle.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    [self.emptyStateView addSubview:emptyTitle];

    NSTextField *emptySubtitle = [NSTextField labelWithString:NFLocalizedString(@"Add a file to use it as a template, or restore the included set.")];
    emptySubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptySubtitle.font = [NSFont systemFontOfSize:12];
    emptySubtitle.textColor = NSColor.secondaryLabelColor;
    emptySubtitle.alignment = NSTextAlignmentCenter;
    emptySubtitle.maximumNumberOfLines = 2;
    [self.emptyStateView addSubview:emptySubtitle];

    NSButton *addButton = [NSButton buttonWithTitle:NFLocalizedString(@"Add Template…") target:self action:@selector(addTemplatesAction:)];
    addButton.translatesAutoresizingMaskIntoConstraints = NO;
    addButton.bezelStyle = NSBezelStyleRounded;
    addButton.controlSize = NSControlSizeLarge;
    [self.emptyStateView addSubview:addButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:root.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:root.centerYAnchor constant:-20],
        [self.emptyStateView.widthAnchor constraintLessThanOrEqualToConstant:360],
        [emptyIcon.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:56],
        [emptyIcon.heightAnchor constraintEqualToConstant:56],
        [emptyTitle.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:12],
        [emptyTitle.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [emptySubtitle.topAnchor constraintEqualToAnchor:emptyTitle.bottomAnchor constant:6],
        [emptySubtitle.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor],
        [emptySubtitle.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor],
        [addButton.topAnchor constraintEqualToAnchor:emptySubtitle.bottomAnchor constant:16],
        [addButton.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [addButton.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor]
    ]];

    [self reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self reloadData];
}

- (NFConfig *)config {
    return [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
}

- (void)reloadData {
    if (!self.viewLoaded) {
        return;
    }
    NFConfig *config = [self config];
    NSMutableArray<NFTemplate *> *templates = [NSMutableArray array];

    if (self.filter == NFCTemplateFilterRecent) {
        for (NSString *identifier in config.recentTemplateIDs) {
            NFTemplate *template = [config templateWithIdentifier:identifier];
            if (template && template.enabled) {
                [templates addObject:template];
            }
        }
    } else {
        for (NFTemplate *template in config.templates) {
            if (!template.enabled) {
                continue;
            }
            if (self.filter == NFCTemplateFilterFavorites && !template.favorite) {
                continue;
            }
            if (self.filter == NFCTemplateFilterCategory && self.categoryFilter.length > 0 &&
                [template.category caseInsensitiveCompare:self.categoryFilter] != NSOrderedSame) {
                continue;
            }
            [templates addObject:template];
        }
    }

    if (self.searchQuery.length > 0) {
        NSString *query = self.searchQuery.lowercaseString;
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NFTemplate *template, NSDictionary *bindings) {
            return [template.resolvedDisplayName.lowercaseString containsString:query] ||
                   [template.fileName.lowercaseString containsString:query] ||
                   [template.category.lowercaseString containsString:query] ||
                   [template.fileExtension.lowercaseString containsString:query];
        }];
        [templates filterUsingPredicate:predicate];
    }

    [templates sortUsingComparator:^NSComparisonResult(NFTemplate *a, NFTemplate *b) {
        switch (self.sortMode) {
            case NFTemplateSortName:
                return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
            case NFTemplateSortCategory:
                if ([a.category isEqualToString:b.category]) {
                    return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
                }
                return [a.category localizedCaseInsensitiveCompare:b.category];
            case NFTemplateSortFileType: {
                NSString *aType = a.fileExtension.length > 0 ? a.fileExtension : a.resolvedDisplayName.pathExtension;
                NSString *bType = b.fileExtension.length > 0 ? b.fileExtension : b.resolvedDisplayName.pathExtension;
                NSComparisonResult typeOrder = [aType localizedCaseInsensitiveCompare:bType];
                if (typeOrder != NSOrderedSame) {
                    return typeOrder;
                }
                return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
            }
            case NFTemplateSortLastUsed:
                if (!a.lastUsedAt && !b.lastUsedAt) {
                    return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
                }
                if (!a.lastUsedAt) return NSOrderedDescending;
                if (!b.lastUsedAt) return NSOrderedAscending;
                return [b.lastUsedAt compare:a.lastUsedAt];
            case NFTemplateSortMostUsed:
                if (a.useCount == b.useCount) {
                    return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
                }
                return a.useCount > b.useCount ? NSOrderedAscending : NSOrderedDescending;
            case NFTemplateSortManual:
            default:
                if (a.sortIndex != b.sortIndex) {
                    return a.sortIndex < b.sortIndex ? NSOrderedAscending : NSOrderedDescending;
                }
                return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
        }
    }];

    self.displayedTemplates = templates;
    [self.collectionView reloadData];
    self.collectionView.hidden = templates.count == 0;
    self.emptyStateView.hidden = templates.count > 0;
    if (templates.count == 0) {
        self.emptyStateView.hidden = NO;
    }
    [self notifySelectionChanged];
}

- (void)setFilter:(NFCTemplateFilter)filter {
    _filter = filter;
    [self reloadData];
}

- (void)setCategoryFilter:(NSString *)categoryFilter {
    _categoryFilter = [categoryFilter copy];
    [self reloadData];
}

- (void)setSearchQuery:(NSString *)searchQuery {
    _searchQuery = [searchQuery copy];
    [self reloadData];
}

- (void)setSortMode:(NFTemplateSortMode)sortMode {
    _sortMode = sortMode;
    [self reloadData];
}

- (NFTemplate *)selectedTemplate {
    NSIndexPath *indexPath = self.collectionView.selectionIndexPaths.anyObject;
    if (!indexPath || indexPath.item >= (NSInteger)self.displayedTemplates.count) {
        return nil;
    }
    return self.displayedTemplates[indexPath.item];
}

- (void)selectTemplateWithIdentifier:(NSString *)identifier {
    for (NSUInteger index = 0; index < self.displayedTemplates.count; index++) {
        if ([self.displayedTemplates[index].identifier isEqualToString:identifier]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
            [self.collectionView selectItemsAtIndexPaths:[NSSet setWithObject:indexPath] scrollPosition:NSCollectionViewScrollPositionCenteredVertically];
            [self notifySelectionChanged];
            return;
        }
    }
}

- (void)notifySelectionChanged {
    if (self.onSelectionChanged) {
        self.onSelectionChanged(self.selectedTemplate);
    }
}

#pragma mark - Collection view

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.displayedTemplates.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NFCTemplateCollectionItem *item = (NFCTemplateCollectionItem *)[collectionView makeItemWithIdentifier:@"template" forIndexPath:indexPath];
    NFTemplate *template = self.displayedTemplates[indexPath.item];
    item.template = template;
    __weak typeof(self) weakSelf = self;
    item.onDoubleClick = ^(NFTemplate *selected) {
        if (weakSelf.onCreate) {
            weakSelf.onCreate(selected);
        }
    };
    return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    [self notifySelectionChanged];
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    [self notifySelectionChanged];
}

- (NSPasteboardItem *)collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= (NSInteger)self.displayedTemplates.count) {
        return nil;
    }
    NFTemplate *template = self.displayedTemplates[indexPath.item];
    NSURL *url = [[NFConfigStore sharedStore] templateFileURLForTemplate:template];
    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
    [item setString:url.absoluteString forType:NSPasteboardTypeFileURL];
    return item;
}

#pragma mark - Actions

- (NSMenu *)contextMenuForIndexPath:(NSIndexPath *)indexPath {
    NFTemplate *template = indexPath.item < (NSInteger)self.displayedTemplates.count ? self.displayedTemplates[indexPath.item] : nil;
    if (!template) {
        return nil;
    }
    self.contextTemplate = template;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [menu addItemWithTitle:NFLocalizedString(@"Create in Default Folder") action:@selector(createContextTemplate:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:NFLocalizedString(@"Choose Name and Location…") action:@selector(createContextTemplateWithPanel:) keyEquivalent:@""].target = self;
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *favorite = [menu addItemWithTitle:template.favorite ? NFLocalizedString(@"Remove Favorite") : NFLocalizedString(@"Favorite") action:@selector(toggleContextFavorite:) keyEquivalent:@""];
    favorite.target = self;
    NSMenuItem *reveal = [menu addItemWithTitle:NFLocalizedString(@"Reveal in Finder") action:@selector(revealContextTemplate:) keyEquivalent:@""];
    reveal.target = self;
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *rename = [menu addItemWithTitle:NFLocalizedString(@"Rename…") action:@selector(renameContextTemplate:) keyEquivalent:@""];
    rename.target = self;
    NSMenuItem *remove = [menu addItemWithTitle:NFLocalizedString(@"Remove Template…") action:@selector(removeContextTemplate:) keyEquivalent:@""];
    remove.target = self;
    return menu;
}

- (void)createContextTemplate:(id)sender {
    if (self.contextTemplate && self.onCreate) {
        self.onCreate(self.contextTemplate);
    }
}

- (void)createContextTemplateWithPanel:(id)sender {
    if (self.contextTemplate) {
        [[NFCreateCoordinator sharedCoordinator] createWithSavePanel:self.contextTemplate window:self.view.window];
    }
}

- (void)toggleContextFavorite:(id)sender {
    if (!self.contextTemplate) {
        return;
    }
    NSString *identifier = self.contextTemplate.identifier;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        NFTemplate *current = [config templateWithIdentifier:identifier];
        current.favorite = !current.favorite;
        return current != nil;
    } error:nil];
    [self reloadData];
}

- (void)revealContextTemplate:(id)sender {
    if (!self.contextTemplate) {
        return;
    }
    NSURL *url = [[NFConfigStore sharedStore] templateFileURLForTemplate:self.contextTemplate];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
}

- (void)renameContextTemplate:(id)sender {
    if (!self.contextTemplate) {
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NFLocalizedString(@"Rename Template");
    alert.informativeText = NFLocalizedString(@"The template file keeps its current name. This changes the display name only.");
    [alert addButtonWithTitle:NFLocalizedString(@"Rename")];
    [alert addButtonWithTitle:NFLocalizedString(@"Cancel")];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    field.stringValue = self.contextTemplate.resolvedDisplayName;
    alert.accessoryView = field;
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    NSString *name = [field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        return;
    }
    NSString *identifier = self.contextTemplate.identifier;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        NFTemplate *current = [config templateWithIdentifier:identifier];
        current.displayName = name;
        return current != nil;
    } error:nil];
    [self reloadData];
}

- (void)removeContextTemplate:(id)sender {
    if (!self.contextTemplate) {
        return;
    }
    NFTemplate *template = self.contextTemplate;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NFLocalizedString(@"Remove “%@”?"), template.resolvedDisplayName];
    alert.informativeText = NFLocalizedString(@"The template is removed from the library and its file is moved to Trash.");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NFLocalizedString(@"Remove")];
    [alert addButtonWithTitle:NFLocalizedString(@"Cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    NSURL *fileURL = [[NFConfigStore sharedStore] templateFileURLForTemplate:template];
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        NFTemplate *current = [config templateWithIdentifier:template.identifier];
        if (current) {
            [config.templates removeObject:current];
            if ([[config stringSettingForKey:@"defaultTemplateID" defaultValue:@""] isEqualToString:template.identifier]) {
                [config setSetting:config.templates.firstObject.identifier ?: @"" forKey:@"defaultTemplateID"];
            }
        }
        return YES;
    } error:nil];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        [[NSFileManager defaultManager] trashItemAtURL:fileURL resultingItemURL:nil error:nil];
    }
    [self reloadData];
}

- (void)addTemplatesAction:(id)sender {
    if (self.onAddTemplates) {
        self.onAddTemplates();
    }
}

@end

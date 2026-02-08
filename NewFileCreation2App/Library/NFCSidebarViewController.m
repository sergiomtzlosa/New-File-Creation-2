#import "NFCSidebarViewController.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFLocalization.h"

@interface NFCSidebarItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *symbolName;
@property (nonatomic, assign) NFCTemplateFilter filter;
@property (nonatomic, copy, nullable) NSString *category;
@property (nonatomic, assign) BOOL group;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, strong) NSMutableArray<NFCSidebarItem *> *children;
@end

@implementation NFCSidebarItem
- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [NSMutableArray array];
    }
    return self;
}
@end

@interface NFCSidebarViewController () <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, strong) NSArray<NFCSidebarItem *> *rootItems;
@property (nonatomic, strong) NFCSidebarItem *allItem;
@end

@implementation NFCSidebarViewController

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 220, 600)];
    self.view = root;

    self.outlineView = [[NSOutlineView alloc] initWithFrame:root.bounds];
    self.outlineView.identifier = @"TemplateSidebar";
    self.outlineView.accessibilityLabel = NFLocalizedString(@"Library");
    self.outlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.outlineView.headerView = nil;
    self.outlineView.style = NSTableViewStyleSourceList;
    self.outlineView.floatsGroupRows = NO;
    self.outlineView.indentationPerLevel = 12;
    self.outlineView.rowSizeStyle = NSTableViewRowSizeStyleMedium;
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"main"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.outlineView addTableColumn:column];
    self.outlineView.outlineTableColumn = column;

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = self.outlineView;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    [root addSubview:scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:root.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor]
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
    NSMutableArray<NFCSidebarItem *> *roots = [NSMutableArray array];

    NFCSidebarItem *libraryGroup = [[NFCSidebarItem alloc] init];
    libraryGroup.title = NFLocalizedString(@"Library");
    libraryGroup.group = YES;

    NFCSidebarItem *all = [[NFCSidebarItem alloc] init];
    all.title = NFLocalizedString(@"All Templates");
    all.symbolName = @"square.grid.2x2";
    all.filter = NFCTemplateFilterAll;
    all.count = config.templates.count;
    self.allItem = all;

    NFCSidebarItem *favorites = [[NFCSidebarItem alloc] init];
    favorites.title = NFLocalizedString(@"Favorites");
    favorites.symbolName = @"star";
    favorites.filter = NFCTemplateFilterFavorites;
    favorites.count = config.favoriteTemplates.count;

    NFCSidebarItem *recent = [[NFCSidebarItem alloc] init];
    recent.title = NFLocalizedString(@"Recent");
    recent.symbolName = @"clock";
    recent.filter = NFCTemplateFilterRecent;
    recent.count = config.recentTemplateIDs.count;

    [libraryGroup.children addObjectsFromArray:@[all, favorites, recent]];
    [roots addObject:libraryGroup];

    NFCSidebarItem *categoryGroup = [[NFCSidebarItem alloc] init];
    categoryGroup.title = NFLocalizedString(@"Categories");
    categoryGroup.group = YES;
    for (NSString *category in [config categories]) {
        NSInteger count = 0;
        for (NFTemplate *template in config.templates) {
            if ([template.category isEqualToString:category]) {
                count++;
            }
        }
        NFCSidebarItem *item = [[NFCSidebarItem alloc] init];
        item.title = NFLocalizedString(category);
        item.symbolName = @"folder";
        item.filter = NFCTemplateFilterCategory;
        item.category = category;
        item.count = count;
        [categoryGroup.children addObject:item];
    }
    [roots addObject:categoryGroup];

    self.rootItems = roots;
    [self.outlineView reloadData];
    for (NFCSidebarItem *item in roots) {
        [self.outlineView expandItem:item];
    }

    NSInteger selectedRow = self.outlineView.selectedRow;
    if (selectedRow < 0) {
        NSInteger row = [self.outlineView rowForItem:all];
        if (row >= 0) {
            [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
}

- (void)selectAllTemplates {
    NSInteger row = [self.outlineView rowForItem:self.allItem];
    if (row >= 0) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

#pragma mark - Outline data source

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (!item) {
        return self.rootItems.count;
    }
    return ((NFCSidebarItem *)item).children.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (!item) {
        return self.rootItems[index];
    }
    return ((NFCSidebarItem *)item).children[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ((NFCSidebarItem *)item).children.count > 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    return ((NFCSidebarItem *)item).group;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return !((NFCSidebarItem *)item).group;
}

- (NSTableCellView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NFCSidebarItem *sidebarItem = (NFCSidebarItem *)item;
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        cell.identifier = @"cell";
        NSImageView *imageView = [[NSImageView alloc] init];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:imageView];
        cell.imageView = imageView;
        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:textField];
        cell.textField = textField;
        NSTextField *countField = [NSTextField labelWithString:@""];
        countField.translatesAutoresizingMaskIntoConstraints = NO;
        countField.font = [NSFont systemFontOfSize:11];
        countField.textColor = NSColor.secondaryLabelColor;
        countField.alignment = NSTextAlignmentRight;
        countField.tag = 100;
        [cell addSubview:countField];
        [NSLayoutConstraint activateConstraints:@[
            [imageView.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4],
            [imageView.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [imageView.widthAnchor constraintEqualToConstant:16],
            [imageView.heightAnchor constraintEqualToConstant:16],
            [textField.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:7],
            [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [countField.leadingAnchor constraintGreaterThanOrEqualToAnchor:textField.trailingAnchor constant:6],
            [countField.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-6],
            [countField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
    }

    NSTextField *countField = [cell viewWithTag:100];
    if (sidebarItem.group) {
        cell.textField.stringValue = sidebarItem.title.uppercaseString;
        cell.textField.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        cell.textField.textColor = NSColor.secondaryLabelColor;
        cell.imageView.image = nil;
        countField.stringValue = @"";
        return cell;
    }

    cell.textField.stringValue = sidebarItem.title;
    cell.textField.font = [NSFont systemFontOfSize:13];
    cell.textField.textColor = NSColor.labelColor;
    cell.imageView.image = [NSImage imageWithSystemSymbolName:sidebarItem.symbolName accessibilityDescription:sidebarItem.title];
    cell.imageView.contentTintColor = NSColor.secondaryLabelColor;
    countField.stringValue = sidebarItem.count > 0 ? [NSString stringWithFormat:@"%ld", (long)sidebarItem.count] : @"";
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = self.outlineView.selectedRow;
    if (row < 0) {
        return;
    }
    NFCSidebarItem *item = [self.outlineView itemAtRow:row];
    if (item.group || !self.onFilterChanged) {
        return;
    }
    self.onFilterChanged(item.filter, item.category);
}

@end

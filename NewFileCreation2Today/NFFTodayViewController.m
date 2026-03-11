#import "NFFTodayViewController.h"
#import "NFTodayTemplateSource.h"
#import "NFTemplate.h"
#import "NFFilePromiseProvider.h"
#import "NFLocalization.h"
#import "NFConfig.h"
#import "NFConfigStore.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@interface NFFTodayViewController ()
@property (nonatomic, strong) NFTodayTemplateSource *source;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong, nullable) NSScrollView *scrollView;
@property (nonatomic, strong) NSTextField *emptyLabel;
@property (nonatomic, copy) NSArray<NFTemplate *> *templates;
@end

@implementation NFFTodayViewController

- (instancetype)init {
    return [self initWithSupportDirectory:[NFTodayTemplateSource defaultSupportDirectory]];
}

- (instancetype)initWithSupportDirectory:(NSURL *)supportDirectory {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _source = [[NFTodayTemplateSource alloc] initWithSupportDirectory:supportDirectory];
        _templates = @[];
        self.preferredContentSize = NSMakeSize(320, 300);
    }
    return self;
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 300)];
    root.wantsLayer = YES;
    self.view = root;

    NSImageView *icon = [[NSImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = NSApp.applicationIconImage;
    [root addSubview:icon];

    NSTextField *title = [NSTextField labelWithString:NFLocalizedString(@"New File Creation 2")];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [root addSubview:title];

    NSTextField *hint = [NSTextField labelWithString:NFLocalizedString(@"Drag a template to a folder or the Desktop.")];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.font = [NSFont systemFontOfSize:10];
    hint.textColor = NSColor.secondaryLabelColor;
    hint.lineBreakMode = NSLineBreakByTruncatingTail;
    [root addSubview:hint];

    self.tableView = [[NSTableView alloc] init];
    self.tableView.headerView = nil;
    self.tableView.backgroundColor = NSColor.clearColor;
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    self.tableView.intercellSpacing = NSMakeSize(0, 0);
    self.tableView.rowHeight = 32.0;
    self.tableView.style = NSTableViewStylePlain;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"TemplateColumn"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:column];

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    self.scrollView = scrollView;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = self.tableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    scrollView.borderType = NSNoBorder;
    [root addSubview:scrollView];

    self.emptyLabel = [NSTextField labelWithString:NFLocalizedString(@"No templates to show")];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.font = [NSFont systemFontOfSize:11];
    self.emptyLabel.textColor = NSColor.tertiaryLabelColor;
    self.emptyLabel.alignment = NSTextAlignmentCenter;
    [root addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:root.topAnchor constant:4],
        [icon.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:4],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:8],
        [title.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:root.trailingAnchor constant:-4],
        [hint.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:1],
        [hint.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [hint.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-4],
        [scrollView.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:8],
        [scrollView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:root.centerYAnchor constant:12]
    ]];

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(configDidChange:)
                                                            name:NFConfigDistributedChangeNotification
                                                          object:nil];
    [self reloadData];
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self reloadData];
}

- (void)configDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadData];
    });
}

- (void)reloadData {
    self.templates = [self.source reloadTemplates];
    self.emptyLabel.hidden = self.templates.count > 0;
    self.scrollView.hidden = self.templates.count == 0;
    [self.tableView reloadData];
}

#pragma mark - NCWidgetProviding

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    NSUInteger before = self.templates.count;
    [self reloadData];
    completionHandler(self.templates.count == before ? NCUpdateResultNoData : NCUpdateResultNewData);
}

- (NSEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(NSEdgeInsets)defaultMarginInsets {
    return NSEdgeInsetsMake(0, 0, 0, 0);
}

- (BOOL)widgetAllowsEditing {
    return NO;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.templates.count;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return nil;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NSURL *templateURL = [self.source templateURLForTemplate:template];
    NSString *fileName = [NFFilePromiseProvider promisedFileNameForTemplate:template
                                                            defaultBaseName:[self.source defaultBaseName]];
    NFFilePromiseProvider *provider = [[NFFilePromiseProvider alloc] initWithTemplate:template
                                                                          templateURL:templateURL
                                                                             fileName:fileName];
    return provider;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.templates.count) {
        return nil;
    }
    NFTemplate *template = self.templates[(NSUInteger)row];
    NSString *identifier = @"NFTodayTemplateCell";
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, 32)];
        cell.identifier = identifier;
        cell.wantsLayer = YES;

        NSImageView *image = [[NSImageView alloc] init];
        image.translatesAutoresizingMaskIntoConstraints = NO;
        image.imageScaling = NSImageScaleProportionallyUpOrDown;
        [cell addSubview:image];
        cell.imageView = image;

        NSTextField *name = [NSTextField labelWithString:@""];
        name.translatesAutoresizingMaskIntoConstraints = NO;
        name.font = [NSFont systemFontOfSize:12];
        name.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [cell addSubview:name];
        cell.textField = name;

        NSTextField *detail = [NSTextField labelWithString:@""];
        detail.translatesAutoresizingMaskIntoConstraints = NO;
        detail.font = [NSFont systemFontOfSize:10];
        detail.textColor = NSColor.secondaryLabelColor;
        detail.lineBreakMode = NSLineBreakByTruncatingTail;
        detail.tag = 1001;
        [cell addSubview:detail];

        [NSLayoutConstraint activateConstraints:@[
            [image.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:6],
            [image.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [image.widthAnchor constraintEqualToConstant:22],
            [image.heightAnchor constraintEqualToConstant:22],
            [name.leadingAnchor constraintEqualToAnchor:image.trailingAnchor constant:8],
            [name.topAnchor constraintEqualToAnchor:cell.topAnchor constant:4],
            [name.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-6],
            [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
            [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:0],
            [detail.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-6]
        ]];
    }

    NSURL *templateURL = [self.source templateURLForTemplate:template];
    cell.imageView.image = [NSWorkspace.sharedWorkspace iconForFile:templateURL.path];
    cell.textField.stringValue = template.resolvedDisplayName;
    NSTextField *detail = [cell viewWithTag:1001];
    NSString *extension = template.fileExtension.length > 0 ? template.fileExtension.uppercaseString : NFLocalizedString(@"no extension");
    detail.stringValue = extension;
    cell.toolTip = [NSString stringWithFormat:NFLocalizedString(@"%@ — drag to create %@"),
                    template.resolvedDisplayName,
                    [NFFilePromiseProvider promisedFileNameForTemplate:template
                                                       defaultBaseName:[self.source defaultBaseName]]];
    cell.accessibilityLabel = cell.toolTip;
    return cell;
}

@end

#pragma clang diagnostic pop

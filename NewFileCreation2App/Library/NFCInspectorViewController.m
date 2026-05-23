#import "NFCInspectorViewController.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFFinderMenuBuilder.h"
#import "NFSanitize.h"
#import "NFLocalization.h"

@interface NFCInspectorViewController ()
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *nameLabel;
@property (nonatomic, strong) NSTextField *fileLabel;
@property (nonatomic, strong) NSTextField *categoryLabel;
@property (nonatomic, strong) NSTextField *detailsLabel;
@property (nonatomic, strong) NSButton *createButton;
@property (nonatomic, strong) NSButton *createPanelButton;
@property (nonatomic, strong) NSButton *favoriteButton;
@property (nonatomic, strong) NSButton *enabledButton;
@property (nonatomic, strong) NSButton *revealButton;
@property (nonatomic, strong) NSButton *removeButton;
@property (nonatomic, strong) NSView *placeholderView;
@property (nonatomic, strong) NSView *contentView;
@end

@implementation NFCInspectorViewController

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 260, 600)];
    root.wantsLayer = YES;
    self.view = root;

    self.contentView = [[NSView alloc] initWithFrame:root.bounds];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.contentView];

    self.iconView = [[NSImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [self.contentView addSubview:self.iconView];

    self.nameLabel = [NSTextField wrappingLabelWithString:@""];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    self.nameLabel.alignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.nameLabel];

    self.fileLabel = [NSTextField wrappingLabelWithString:@""];
    self.fileLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fileLabel.font = [NSFont systemFontOfSize:11];
    self.fileLabel.textColor = NSColor.secondaryLabelColor;
    self.fileLabel.alignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.fileLabel];

    self.categoryLabel = [NSTextField labelWithString:@""];
    self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.categoryLabel.textColor = NSColor.secondaryLabelColor;
    self.categoryLabel.alignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.categoryLabel];

    self.createButton = [NSButton buttonWithTitle:NFLocalizedString(@"Create in Default Folder") target:self action:@selector(createAction:)];
    self.createButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.createButton.bezelStyle = NSBezelStyleRounded;
    self.createButton.controlSize = NSControlSizeLarge;
    self.createButton.keyEquivalent = @"\r";
    [self.contentView addSubview:self.createButton];

    self.createPanelButton = [NSButton buttonWithTitle:NFLocalizedString(@"Choose Name and Location…") target:self action:@selector(createPanelAction:)];
    self.createPanelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.createPanelButton.bezelStyle = NSBezelStyleRounded;
    self.createPanelButton.controlSize = NSControlSizeLarge;
    [self.contentView addSubview:self.createPanelButton];

    NSButton *favoriteButton = [NSButton checkboxWithTitle:NFLocalizedString(@"Favorite") target:self action:@selector(toggleFavorite:)];
    favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteButton = favoriteButton;
    [self.contentView addSubview:favoriteButton];

    NSButton *enabledButton = [NSButton checkboxWithTitle:NFLocalizedString(@"Enabled") target:self action:@selector(toggleEnabled:)];
    enabledButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.enabledButton = enabledButton;
    [self.contentView addSubview:enabledButton];

    self.detailsLabel = [NSTextField wrappingLabelWithString:@""];
    self.detailsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsLabel.font = [NSFont systemFontOfSize:11];
    self.detailsLabel.textColor = NSColor.secondaryLabelColor;
    [self.contentView addSubview:self.detailsLabel];

    self.revealButton = [NSButton buttonWithTitle:NFLocalizedString(@"Reveal Template") target:self action:@selector(revealAction:)];
    self.revealButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.revealButton.bezelStyle = NSBezelStyleInline;
    [self.contentView addSubview:self.revealButton];

    self.removeButton = [NSButton buttonWithTitle:NFLocalizedString(@"Remove Template…") target:self action:@selector(removeAction:)];
    self.removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.removeButton.bezelStyle = NSBezelStyleInline;
    self.removeButton.contentTintColor = NSColor.systemRedColor;
    [self.contentView addSubview:self.removeButton];

    self.placeholderView = [[NSView alloc] initWithFrame:root.bounds];
    self.placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.placeholderView];

    NSImageView *placeholderIcon = [[NSImageView alloc] init];
    placeholderIcon.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderIcon.image = [NSImage imageWithSystemSymbolName:@"sidebar.right" accessibilityDescription:NFLocalizedString(@"Inspector")];
    placeholderIcon.contentTintColor = NSColor.tertiaryLabelColor;
    placeholderIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:32 weight:NSFontWeightRegular];
    [self.placeholderView addSubview:placeholderIcon];

    NSTextField *placeholderLabel = [NSTextField labelWithString:NFLocalizedString(@"Select a template")];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    placeholderLabel.textColor = NSColor.secondaryLabelColor;
    [self.placeholderView addSubview:placeholderLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [self.placeholderView.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor],
        [self.placeholderView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.placeholderView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.placeholderView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [placeholderIcon.centerXAnchor constraintEqualToAnchor:self.placeholderView.centerXAnchor],
        [placeholderIcon.centerYAnchor constraintEqualToAnchor:self.placeholderView.centerYAnchor constant:-16],
        [placeholderIcon.widthAnchor constraintEqualToConstant:42],
        [placeholderIcon.heightAnchor constraintEqualToConstant:42],
        [placeholderLabel.topAnchor constraintEqualToAnchor:placeholderIcon.bottomAnchor constant:10],
        [placeholderLabel.centerXAnchor constraintEqualToAnchor:self.placeholderView.centerXAnchor],

        [self.iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:22],
        [self.iconView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:64],
        [self.iconView.heightAnchor constraintEqualToConstant:64],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:12],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.fileLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.fileLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.fileLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.categoryLabel.topAnchor constraintEqualToAnchor:self.fileLabel.bottomAnchor constant:6],
        [self.categoryLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.categoryLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.createButton.topAnchor constraintEqualToAnchor:self.categoryLabel.bottomAnchor constant:20],
        [self.createButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.createButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.createPanelButton.topAnchor constraintEqualToAnchor:self.createButton.bottomAnchor constant:8],
        [self.createPanelButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.createPanelButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.favoriteButton.topAnchor constraintEqualToAnchor:self.createPanelButton.bottomAnchor constant:18],
        [self.favoriteButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.enabledButton.topAnchor constraintEqualToAnchor:self.favoriteButton.bottomAnchor constant:6],
        [self.enabledButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.detailsLabel.topAnchor constraintEqualToAnchor:self.enabledButton.bottomAnchor constant:18],
        [self.detailsLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.detailsLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.revealButton.topAnchor constraintEqualToAnchor:self.detailsLabel.bottomAnchor constant:14],
        [self.revealButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.removeButton.topAnchor constraintEqualToAnchor:self.revealButton.bottomAnchor constant:8],
        [self.removeButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.removeButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-18]
    ]];

    [self reloadData];
}

- (void)setTemplate:(NFTemplate *)template {
    _template = template;
    [self reloadData];
}

- (void)reloadData {
    if (!self.viewLoaded) {
        return;
    }
    NFTemplate *template = self.template;
    BOOL hasTemplate = template != nil;
    self.contentView.hidden = !hasTemplate;
    self.placeholderView.hidden = hasTemplate;
    if (!hasTemplate) {
        return;
    }

    self.iconView.image = [NFFinderMenuBuilder iconForTemplate:template];
    self.nameLabel.stringValue = template.resolvedDisplayName;
    self.fileLabel.stringValue = template.fileName;
    self.categoryLabel.stringValue = NFLocalizedString(template.category).uppercaseString;
    self.favoriteButton.state = template.favorite ? NSControlStateValueOn : NSControlStateValueOff;
    self.enabledButton.state = template.enabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMutableArray<NSString *> *details = [NSMutableArray array];
    if (template.fileExtension.length > 0) {
        [details addObject:[NSString stringWithFormat:NFLocalizedString(@"Extension: %@"), template.fileExtension.uppercaseString]];
    }
    if (template.useCount == 1) {
        [details addObject:[NSString stringWithFormat:NFLocalizedString(@"Used %ld time"), (long)template.useCount]];
    } else {
        [details addObject:[NSString stringWithFormat:NFLocalizedString(@"Used %ld times"), (long)template.useCount]];
    }
    if (template.lastUsedAt) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        [details addObject:[NSString stringWithFormat:NFLocalizedString(@"Last used %@"), [formatter stringFromDate:template.lastUsedAt]]];
    }
    if (template.notes.length > 0) {
        [details addObject:template.notes];
    }
    self.detailsLabel.stringValue = [details componentsJoinedByString:@"\n"];
}

- (void)createAction:(id)sender {
    if (self.template && self.onCreate) {
        self.onCreate(self.template);
    }
}

- (void)createPanelAction:(id)sender {
    if (self.template && self.onCreateWithPanel) {
        self.onCreateWithPanel(self.template);
    }
}

- (void)toggleFavorite:(id)sender {
    if (!self.template) {
        return;
    }
    NSString *identifier = self.template.identifier;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        NFTemplate *current = [config templateWithIdentifier:identifier];
        if (!current) {
            return NO;
        }
        current.favorite = !current.favorite;
        return YES;
    } error:nil];
    [self reloadData];
    if (self.onChange) {
        self.onChange();
    }
}

- (void)toggleEnabled:(id)sender {
    if (!self.template) {
        return;
    }
    NSString *identifier = self.template.identifier;
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        NFTemplate *current = [config templateWithIdentifier:identifier];
        if (!current) {
            return NO;
        }
        current.enabled = !current.enabled;
        return YES;
    } error:nil];
    [self reloadData];
    if (self.onChange) {
        self.onChange();
    }
}

- (void)revealAction:(id)sender {
    if (!self.template) {
        return;
    }
    NSURL *url = [[NFConfigStore sharedStore] templateFileURLForTemplate:self.template];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
}

- (void)removeAction:(id)sender {
    if (!self.template) {
        return;
    }
    NFTemplate *template = self.template;
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
    self.template = nil;
    if (self.onChange) {
        self.onChange();
    }
}

@end

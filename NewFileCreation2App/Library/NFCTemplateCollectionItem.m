#import "NFCTemplateCollectionItem.h"
#import "NFFinderMenuBuilder.h"
#import "NFConfig.h"
#import "NFLocalization.h"

@interface NFCTemplateCollectionItem ()
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *nameLabel;
@property (nonatomic, strong) NSTextField *categoryLabel;
@property (nonatomic, strong) NSImageView *favoriteView;
@property (nonatomic, strong) NSView *cardView;
@end

@implementation NFCTemplateCollectionItem

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 168, 150)];
    container.wantsLayer = YES;
    container.layer.cornerRadius = 10;
    container.layer.borderWidth = 1;
    container.layer.borderColor = NSColor.separatorColor.CGColor;
    container.layer.backgroundColor = [NSColor.controlBackgroundColor colorWithAlphaComponent:0.45].CGColor;
    self.view = container;

    self.cardView = container;

    self.iconView = [[NSImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [container addSubview:self.iconView];

    self.favoriteView = [[NSImageView alloc] init];
    self.favoriteView.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteView.image = [NSImage imageWithSystemSymbolName:@"star.fill" accessibilityDescription:NFLocalizedString(@"Favorite")];
    self.favoriteView.contentTintColor = NSColor.systemYellowColor;
    self.favoriteView.hidden = YES;
    [container addSubview:self.favoriteView];

    self.nameLabel = [NSTextField labelWithString:@""];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    self.nameLabel.alignment = NSTextAlignmentCenter;
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.maximumNumberOfLines = 2;
    [container addSubview:self.nameLabel];

    self.categoryLabel = [NSTextField labelWithString:@""];
    self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryLabel.font = [NSFont systemFontOfSize:11];
    self.categoryLabel.textColor = NSColor.secondaryLabelColor;
    self.categoryLabel.alignment = NSTextAlignmentCenter;
    self.categoryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [container addSubview:self.categoryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:18],
        [self.iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:48],
        [self.iconView.heightAnchor constraintEqualToConstant:48],
        [self.favoriteView.topAnchor constraintEqualToAnchor:container.topAnchor constant:8],
        [self.favoriteView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [self.favoriteView.widthAnchor constraintEqualToConstant:11],
        [self.favoriteView.heightAnchor constraintEqualToConstant:11],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:10],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:10],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [self.categoryLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:3],
        [self.categoryLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:10],
        [self.categoryLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [self.categoryLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-10]
    ]];

    NSClickGestureRecognizer *doubleClick = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleClick:)];
    doubleClick.numberOfClicksRequired = 2;
    [container addGestureRecognizer:doubleClick];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.template = nil;
    self.onDoubleClick = nil;
    self.nameLabel.stringValue = @"";
    self.categoryLabel.stringValue = @"";
    self.favoriteView.hidden = YES;
}

- (void)setTemplate:(NFTemplate *)template {
    _template = template;
    if (!self.viewLoaded) {
        [self loadView];
    }
    if (!template) {
        self.nameLabel.stringValue = @"";
        self.categoryLabel.stringValue = @"";
        self.iconView.image = nil;
        self.favoriteView.hidden = YES;
        self.view.toolTip = nil;
        self.view.accessibilityLabel = nil;
        [self updateSelectionAppearance];
        return;
    }
    self.nameLabel.stringValue = template.resolvedDisplayName;
    self.categoryLabel.stringValue = template.category;
    self.iconView.image = [NFFinderMenuBuilder iconForTemplate:template];
    self.favoriteView.hidden = !template.favorite;
    self.view.toolTip = [NSString stringWithFormat:NFLocalizedString(@"%@ (%@)\nDouble-click to create a file."), template.resolvedDisplayName, template.fileName];
    self.view.accessibilityLabel = [NSString stringWithFormat:NFLocalizedString(@"%@ template"), template.resolvedDisplayName];
    self.view.accessibilityRole = NSAccessibilityButtonRole;
    [self updateSelectionAppearance];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self updateSelectionAppearance];
}

- (void)updateSelectionAppearance {
    if (!self.viewLoaded) {
        return;
    }
    BOOL selected = self.selected;
    self.cardView.layer.borderWidth = selected ? 2 : 1;
    self.cardView.layer.borderColor = (selected ? NSColor.controlAccentColor : NSColor.separatorColor).CGColor;
    self.cardView.layer.backgroundColor = (selected
        ? [NSColor.controlAccentColor colorWithAlphaComponent:0.14]
        : [NSColor.controlBackgroundColor colorWithAlphaComponent:0.45]).CGColor;
}

- (void)handleDoubleClick:(id)sender {
    if (self.template && self.onDoubleClick) {
        self.onDoubleClick(self.template);
    }
}

@end

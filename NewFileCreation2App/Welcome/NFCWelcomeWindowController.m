#import "NFCWelcomeWindowController.h"
#import "NFCFloatingPanel.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFLocalization.h"

@interface NFCWelcomeWindowController () <NSWindowDelegate>
@property (nonatomic, assign) BOOL didPositionWindow;
@property (nonatomic, assign) BOOL didSizeWindow;
@property (nonatomic, strong) NSView *mainView;
@property (nonatomic, strong) NSView *asideView;
@property (nonatomic, strong) NSLayoutConstraint *asideWidthConstraint;
@property (nonatomic, strong) NSButton *inspectorButton;
@end

@implementation NFCWelcomeWindowController

- (instancetype)init {
    NFCFloatingPanel *window = [NFCFloatingPanel floatingPanelWithContentRect:NSMakeRect(0, 0, 640, 460)
                                                                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                                            NSWindowStyleMaskResizable];
    window.title = NFLocalizedString(@"Get Started");
    window.contentMinSize = NSMakeSize(600, 440);

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        [self setupInterface];
    }
    return self;
}

- (void)showWindow:(id)sender {
    if (!self.didSizeWindow) {
        [self sizeWindowToFitContent];
        self.didSizeWindow = YES;
    }
    if (!self.didPositionWindow) {
        [(NFCFloatingPanel *)self.window centerOnActiveScreen];
        self.didPositionWindow = YES;
    }
    [super showWindow:sender];
}

- (void)setupInterface {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    self.mainView = [[NSView alloc] init];
    self.mainView.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.mainView];

    self.asideView = [[NSView alloc] init];
    self.asideView.translatesAutoresizingMaskIntoConstraints = NO;
    self.asideView.wantsLayer = YES;
    self.asideView.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    self.asideView.layer.cornerRadius = 10.0;
    self.asideView.hidden = YES;
    [content addSubview:self.asideView];

    self.asideWidthConstraint = [self.asideView.widthAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.mainView.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [self.mainView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:32],
        [self.mainView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
        [self.mainView.trailingAnchor constraintEqualToAnchor:self.asideView.leadingAnchor constant:-16],
        [self.asideView.topAnchor constraintEqualToAnchor:self.mainView.topAnchor],
        [self.asideView.bottomAnchor constraintEqualToAnchor:self.mainView.bottomAnchor],
        [self.asideView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],
        self.asideWidthConstraint
    ]];

    NSImageView *icon = [[NSImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = NSApp.applicationIconImage;
    [self.mainView addSubview:icon];

    NSTextField *title = [NSTextField labelWithString:NFLocalizedString(@"Welcome to New File Creation 2")];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [NSFont systemFontOfSize:24 weight:NSFontWeightBold];
    title.alignment = NSTextAlignmentCenter;
    [self.mainView addSubview:title];

    NSTextField *subtitle = [NSTextField wrappingLabelWithString:NFLocalizedString(@"Create a file from a template in Finder, from the menu bar, from the template library, or with the nfc command.")];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [NSFont systemFontOfSize:13];
    subtitle.textColor = NSColor.secondaryLabelColor;
    subtitle.alignment = NSTextAlignmentCenter;
    subtitle.maximumNumberOfLines = 3;
    [self.mainView addSubview:subtitle];

    NSStackView *features = [[NSStackView alloc] init];
    features.translatesAutoresizingMaskIntoConstraints = NO;
    features.orientation = NSUserInterfaceLayoutOrientationVertical;
    features.alignment = NSLayoutAttributeLeading;
    features.spacing = 12;
    [self.mainView addSubview:features];

    NSArray<NSArray<NSString *> *> *items = @[
        @[@"menubar.rectangle", NFLocalizedString(@"Use the menu bar icon or the global shortcut for the quick panel.")],
        @[@"folder.badge.plus", NFLocalizedString(@"Right-click in Finder and choose New File from the template list.")],
        @[@"terminal", NFLocalizedString(@"Run nfc create \"Text File\" to make a file anywhere.")],
        @[@"lock.shield", NFLocalizedString(@"Everything stays on your Mac. No network, analytics, or telemetry.")]
    ];
    for (NSArray<NSString *> *item in items) {
        NSImageView *image = [[NSImageView alloc] init];
        image.translatesAutoresizingMaskIntoConstraints = NO;
        image.image = [NSImage imageWithSystemSymbolName:item[0] accessibilityDescription:nil];
        image.contentTintColor = NSColor.controlAccentColor;
        image.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightMedium];
        NSTextField *label = [NSTextField wrappingLabelWithString:item[1]];
        label.font = [NSFont systemFontOfSize:12];
        NSStackView *row = [NSStackView stackViewWithViews:@[image, label]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.alignment = NSLayoutAttributeCenterY;
        row.spacing = 10;
        [image.widthAnchor constraintEqualToConstant:20].active = YES;
        [image.heightAnchor constraintEqualToConstant:20].active = YES;
        [features addArrangedSubview:row];
    }

    NSButton *getStarted = [NSButton buttonWithTitle:NFLocalizedString(@"Open Template Library") target:self action:@selector(getStarted:)];
    getStarted.identifier = @"WelcomeGetStartedButton";
    getStarted.translatesAutoresizingMaskIntoConstraints = NO;
    getStarted.bezelStyle = NSBezelStyleRounded;
    getStarted.controlSize = NSControlSizeLarge;
    getStarted.keyEquivalent = @"\r";
    [self.mainView addSubview:getStarted];

    NSButton *settings = [NSButton buttonWithTitle:NFLocalizedString(@"Open Settings") target:self action:@selector(openSettings:)];
    settings.identifier = @"WelcomeSettingsButton";
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    settings.bezelStyle = NSBezelStyleRounded;
    settings.controlSize = NSControlSizeLarge;
    [self.mainView addSubview:settings];

    NSTextField *note = [NSTextField labelWithString:NFLocalizedString(@"You can reopen this window from Settings › Help or from the menu bar.")];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.font = [NSFont systemFontOfSize:10];
    note.textColor = NSColor.tertiaryLabelColor;
    [self.mainView addSubview:note];

    self.inspectorButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"sidebar.right"
                                                                    accessibilityDescription:NFLocalizedString(@"Show Get Started details")]
                                              target:self
                                              action:@selector(toggleInspector:)];
    self.inspectorButton.identifier = @"WelcomeInspectorButton";
    self.inspectorButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorButton.bordered = NO;
    self.inspectorButton.toolTip = NFLocalizedString(@"Show Get Started details");
    self.inspectorButton.accessibilityLabel = NFLocalizedString(@"Show Get Started details");
    [self.mainView addSubview:self.inspectorButton];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:self.mainView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:self.mainView.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:76],
        [icon.heightAnchor constraintEqualToConstant:76],
        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor constant:30],
        [title.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor constant:-30],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [subtitle.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor constant:30],
        [subtitle.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor constant:-30],
        [features.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:24],
        [features.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor constant:34],
        [features.trailingAnchor constraintLessThanOrEqualToAnchor:self.mainView.trailingAnchor constant:-28],
        [getStarted.topAnchor constraintEqualToAnchor:features.bottomAnchor constant:26],
        [getStarted.centerXAnchor constraintEqualToAnchor:self.mainView.centerXAnchor constant:-80],
        [settings.centerYAnchor constraintEqualToAnchor:getStarted.centerYAnchor],
        [settings.leadingAnchor constraintEqualToAnchor:getStarted.trailingAnchor constant:10],
        [note.topAnchor constraintEqualToAnchor:getStarted.bottomAnchor constant:14],
        [note.centerXAnchor constraintEqualToAnchor:self.mainView.centerXAnchor],
        [note.bottomAnchor constraintLessThanOrEqualToAnchor:self.mainView.bottomAnchor constant:-24],
        [self.inspectorButton.topAnchor constraintEqualToAnchor:self.mainView.topAnchor],
        [self.inspectorButton.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor],
        [self.inspectorButton.widthAnchor constraintEqualToConstant:28],
        [self.inspectorButton.heightAnchor constraintEqualToConstant:28]
    ]];

    [self setupAsideView];
}

- (CGFloat)naturalContentHeightForWidth:(CGFloat)width {
    NSWindow *window = self.window;
    [window setContentSize:NSMakeSize(width, 640)];
    [self.mainView layoutSubtreeIfNeeded];

    CGFloat lowest = NSMaxY(self.mainView.bounds);
    for (NSView *subview in self.mainView.subviews) {
        if (subview.hidden || subview.alphaValue == 0.0) {
            continue;
        }
        lowest = MIN(lowest, NSMinY(subview.frame));
    }

    CGFloat mainHeight = NSMaxY(self.mainView.bounds) - lowest + 24.0;
    return ceil(mainHeight + 48.0);
}

- (void)sizeWindowToFitContent {
    CGFloat defaultWidth = 640.0;
    CGFloat minimumWidth = 600.0;
    CGFloat defaultHeight = [self naturalContentHeightForWidth:defaultWidth];
    CGFloat minimumHeight = [self naturalContentHeightForWidth:minimumWidth];

    self.window.contentMinSize = NSMakeSize(minimumWidth, minimumHeight);
    [self.window setContentSize:NSMakeSize(defaultWidth, defaultHeight)];
}

- (void)setupAsideView {
    NSTextField *heading = [NSTextField labelWithString:NFLocalizedString(@"At a glance")];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    [self.asideView addSubview:heading];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NFConfig *config = [[NFConfigStore sharedStore] readOnlySnapshot];
    [lines addObject:[NSString stringWithFormat:NFLocalizedString(@"%lu templates in the library"), (unsigned long)config.templates.count]];
    [lines addObject:NFLocalizedString(@"Left-click the menu bar icon for Quick New File.")];
    [lines addObject:NFLocalizedString(@"Drag a template row to Finder or the Desktop.")];
    [lines addObject:NFLocalizedString(@"Return creates the selected template.")];
    [lines addObject:NFLocalizedString(@"Settings › Templates manages categories and sorting.")];
    [lines addObject:NFLocalizedString(@"Settings › Finder enables Finder menus.")];
    [lines addObject:NFLocalizedString(@"Settings › Help explains every workflow.")];

    NSTextField *details = [NSTextField wrappingLabelWithString:[lines componentsJoinedByString:@"\n\n"]];
    details.translatesAutoresizingMaskIntoConstraints = NO;
    details.font = [NSFont systemFontOfSize:11];
    details.textColor = NSColor.secondaryLabelColor;
    details.maximumNumberOfLines = 12;
    [self.asideView addSubview:details];

    NSButton *templates = [NSButton buttonWithTitle:NFLocalizedString(@"Open Templates Folder") target:self action:@selector(openTemplates:)];
    templates.translatesAutoresizingMaskIntoConstraints = NO;
    templates.bezelStyle = NSBezelStyleInline;
    [self.asideView addSubview:templates];

    NSLayoutConstraint *headingTrailing = [heading.trailingAnchor constraintEqualToAnchor:self.asideView.trailingAnchor constant:-16];
    NSLayoutConstraint *detailsTrailing = [details.trailingAnchor constraintEqualToAnchor:heading.trailingAnchor];
    headingTrailing.priority = NSLayoutPriorityDefaultHigh;
    detailsTrailing.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [heading.topAnchor constraintEqualToAnchor:self.asideView.topAnchor constant:18],
        [heading.leadingAnchor constraintEqualToAnchor:self.asideView.leadingAnchor constant:16],
        headingTrailing,
        [details.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:12],
        [details.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        detailsTrailing,
        [templates.topAnchor constraintEqualToAnchor:details.bottomAnchor constant:14],
        [templates.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [templates.bottomAnchor constraintLessThanOrEqualToAnchor:self.asideView.bottomAnchor constant:-18]
    ]];
}

- (void)toggleInspector:(id)sender {
    BOOL showing = !self.asideView.hidden;
    CGFloat targetWidth = showing ? 0 : 260;
    CGFloat delta = showing ? -276 : 276;
    self.asideView.hidden = (targetWidth == 0);
    self.asideWidthConstraint.constant = targetWidth;
    NSRect frame = self.window.frame;
    frame.size.width += delta;
    frame.origin.y -= 0;
    [self.window setFrame:frame display:YES animate:NO];
}

- (void)markOnboardingComplete {
    [[NFConfigStore sharedStore] updateConfig:^BOOL(NFConfig *config, NSError **error) {
        [config setSetting:@YES forKey:@"onboardingCompleted"];
        return YES;
    } error:nil];
}

- (void)getStarted:(id)sender {
    [self markOnboardingComplete];
    [self close];
    if (self.onGetStarted) {
        self.onGetStarted();
    }
}

- (void)openSettings:(id)sender {
    [self markOnboardingComplete];
    [self close];
    if (self.onOpenSettings) {
        self.onOpenSettings();
    }
}

- (void)openTemplates:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NFConfigStore sharedStore].templatesURL];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self markOnboardingComplete];
}

@end

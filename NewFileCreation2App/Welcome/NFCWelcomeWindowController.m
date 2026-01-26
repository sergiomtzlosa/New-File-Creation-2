#import "NFCWelcomeWindowController.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFLocalization.h"

@interface NFCWelcomeWindowController () <NSWindowDelegate>
@end

@implementation NFCWelcomeWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 470)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = NFLocalizedString(@"Welcome");
    window.releasedWhenClosed = NO;
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        [self setupInterface];
    }
    return self;
}

- (void)setupInterface {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    NSImageView *icon = [[NSImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = NSApp.applicationIconImage;
    [content addSubview:icon];

    NSTextField *title = [NSTextField labelWithString:NFLocalizedString(@"Welcome to New File Creation 2")];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [NSFont systemFontOfSize:24 weight:NSFontWeightBold];
    title.alignment = NSTextAlignmentCenter;
    [content addSubview:title];

    NSTextField *subtitle = [NSTextField wrappingLabelWithString:NFLocalizedString(@"Create a file from a template in Finder, from the menu bar, from the template library, or with the nfc command.")];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [NSFont systemFontOfSize:13];
    subtitle.textColor = NSColor.secondaryLabelColor;
    subtitle.alignment = NSTextAlignmentCenter;
    subtitle.maximumNumberOfLines = 3;
    [content addSubview:subtitle];

    NSStackView *features = [[NSStackView alloc] init];
    features.translatesAutoresizingMaskIntoConstraints = NO;
    features.orientation = NSUserInterfaceLayoutOrientationVertical;
    features.alignment = NSLayoutAttributeLeading;
    features.spacing = 12;
    [content addSubview:features];

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

    NSButton *getStarted = [NSButton buttonWithTitle:NFLocalizedString(@"Get Started") target:self action:@selector(getStarted:)];
    getStarted.translatesAutoresizingMaskIntoConstraints = NO;
    getStarted.bezelStyle = NSBezelStyleRounded;
    getStarted.controlSize = NSControlSizeLarge;
    getStarted.keyEquivalent = @"\r";
    [content addSubview:getStarted];

    NSButton *settings = [NSButton buttonWithTitle:NFLocalizedString(@"Open Settings") target:self action:@selector(openSettings:)];
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    settings.bezelStyle = NSBezelStyleRounded;
    settings.controlSize = NSControlSizeLarge;
    [content addSubview:settings];

    NSTextField *note = [NSTextField labelWithString:NFLocalizedString(@"You can reopen this window from Settings › Advanced.")];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.font = [NSFont systemFontOfSize:10];
    note.textColor = NSColor.tertiaryLabelColor;
    [content addSubview:note];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:content.topAnchor constant:32],
        [icon.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:84],
        [icon.heightAnchor constraintEqualToConstant:84],
        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:14],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:30],
        [title.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-30],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [subtitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:60],
        [subtitle.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-60],
        [features.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:24],
        [features.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:64],
        [features.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-48],
        [getStarted.topAnchor constraintEqualToAnchor:features.bottomAnchor constant:26],
        [getStarted.centerXAnchor constraintEqualToAnchor:content.centerXAnchor constant:-80],
        [settings.centerYAnchor constraintEqualToAnchor:getStarted.centerYAnchor],
        [settings.leadingAnchor constraintEqualToAnchor:getStarted.trailingAnchor constant:10],
        [note.topAnchor constraintEqualToAnchor:getStarted.bottomAnchor constant:14],
        [note.centerXAnchor constraintEqualToAnchor:content.centerXAnchor]
    ]];
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

- (void)windowWillClose:(NSNotification *)notification {
    [self markOnboardingComplete];
}

@end

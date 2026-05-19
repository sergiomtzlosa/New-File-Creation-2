#import "NFCAppDelegate.h"
#import "NFCMainMenuBuilder.h"
#import "NFCMainWindowController.h"
#import "NFCQuickPanelController.h"
#import "NFCMenuBarController.h"
#import "NFCSettingsWindowController.h"
#import "NFCWelcomeWindowController.h"
#import "NFCreateCoordinator.h"
#import "NFShortcutCenter.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFRequest.h"
#import "NFErrors.h"
#import "NFPaths.h"
#import "NFLogger.h"
#import "NFLocalization.h"
#import <Carbon/Carbon.h>

@interface NFCAppDelegate () <NSMenuItemValidation>
@property (nonatomic, strong) NFCMainWindowController *mainWindowController;
@property (nonatomic, strong) NFCQuickPanelController *quickPanelController;
@property (nonatomic, strong) NFCMenuBarController *menuBarController;
@property (nonatomic, strong) NFCSettingsWindowController *settingsWindowController;
@property (nonatomic, strong) NFCWelcomeWindowController *welcomeWindowController;
@property (nonatomic, copy) NSString *appliedShortcut;
@end

@implementation NFCAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    NSApp.mainMenu = [NFCMainMenuBuilder buildMainMenu];
    // New File Creation 2 lives in the menu bar. It never owns a Dock window;
    // every window is a floating panel opened from the status item.
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if ([NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] length] > 0) {
        // Hosted unit tests do not need the app interface.
        return;
    }

    NSError *configError = nil;
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:&configError];
    if (!config) {
        [[NFLogger sharedLogger] error:@"Could not load configuration at launch: %@", configError.localizedDescription];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NFLocalizedString(@"New File Creation 2 could not load its configuration");
        alert.informativeText = configError.localizedDescription ?: NFLocalizedString(@"The configuration is damaged.");
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:NFLocalizedString(@"Continue")];
        [alert runModal];
        config = [NFConfig defaultConfig];
    }

    [self setupMainWindow];
    [self setupQuickPanel];
    [self setupMenuBar];
    [self setupSettings];
    [self setupNotifications];
    [self applyConfiguration:config];

    // Stay silent at launch. The menu bar icon is the entry point; library,
    // settings, welcome, and the quick panel are opened from it.

    // UI tests need a deterministic first window because they cannot click the
    // status item through the system accessibility hierarchy.
    if ([NSProcessInfo.processInfo.environment[@"NFC_UI_TEST_OPEN_QUICK_PANEL"] boolValue]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showQuickPanel:nil];
        });
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NFShortcutCenter sharedCenter] unregister];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        [self showLibrary];
    }
    return YES;
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        if ([url.scheme.lowercaseString isEqualToString:NFURLScheme]) {
            [self handleURL:url];
        }
    }
}

#pragma mark - Setup

- (void)setupMainWindow {
    self.mainWindowController = [[NFCMainWindowController alloc] init];
}

- (void)setupQuickPanel {
    self.quickPanelController = [[NFCQuickPanelController alloc] init];
    __weak typeof(self) weakSelf = self;
    self.quickPanelController.onCreateTemplate = ^(NFTemplate *template) {
        [weakSelf createTemplate:template];
    };
    self.quickPanelController.onOpenPreferences = ^{
        [weakSelf showSettings];
    };
    self.quickPanelController.onOpenGetStarted = ^{
        [weakSelf showWelcome];
    };
}

- (void)setupMenuBar {
    self.menuBarController = [[NFCMenuBarController alloc] init];
    __weak typeof(self) weakSelf = self;
    self.menuBarController.onQuickPanel = ^{
        [weakSelf showQuickPanel:nil];
    };
    self.menuBarController.onToggleQuickPanel = ^(NSRect anchorScreenRect) {
        if (weakSelf.quickPanelController.window.isVisible) {
            [weakSelf.quickPanelController hidePanel];
        } else if (!NSEqualRects(anchorScreenRect, NSZeroRect)) {
            [weakSelf.quickPanelController showPanelAnchoredToRect:anchorScreenRect];
        } else {
            [weakSelf.quickPanelController showPanel];
        }
    };
    self.menuBarController.onOpenLibrary = ^{
        [weakSelf showLibrary];
    };
    self.menuBarController.onSettings = ^{
        [weakSelf showSettings];
    };
    self.menuBarController.onWelcome = ^{
        [weakSelf showWelcome];
    };
    self.menuBarController.onCreateTemplate = ^(NFTemplate *template) {
        [weakSelf createTemplate:template];
    };
    self.menuBarController.onAddTemplate = ^{
        [weakSelf showLibrary];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.mainWindowController showAddTemplatesPanel];
        });
    };
}

- (void)setupSettings {
    self.settingsWindowController = [[NFCSettingsWindowController alloc] init];
    __weak typeof(self) weakSelf = self;
    self.settingsWindowController.onShowWelcome = ^{
        [weakSelf.settingsWindowController close];
        [weakSelf showWelcome];
    };
}

- (void)setupNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(configDidChange:) name:NFConfigDidChangeNotification object:nil];
    NSDistributedNotificationCenter *distributed = [NSDistributedNotificationCenter defaultCenter];
    [distributed addObserver:self selector:@selector(configDidChange:) name:NFConfigDistributedChangeNotification object:nil];
}

- (void)applyConfiguration:(NFConfig *)config {
    NSString *shortcut = [config stringSettingForKey:@"globalShortcut" defaultValue:@"control+option+n"];
    if (![shortcut isEqualToString:self.appliedShortcut ?: @""]) {
        __weak typeof(self) weakSelf = self;
        [NFShortcutCenter sharedCenter].handler = ^{
            [weakSelf showQuickPanel:nil];
        };
        NSError *error = nil;
        if ([[NFShortcutCenter sharedCenter] registerShortcut:shortcut error:&error]) {
            self.appliedShortcut = shortcut;
        } else {
            [[NFLogger sharedLogger] error:@"Could not register global shortcut %@: %@", shortcut, error.localizedDescription];
        }
    }

    // The menu bar icon is the app's permanent entry point. Keep it visible
    // even when a legacy configuration disables showMenuBarIcon.
    if (!self.menuBarController.isVisible) {
        self.menuBarController.visible = YES;
    } else {
        [self.menuBarController reloadMenu];
    }
}

- (void)configDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NFConfig *config = [[NFConfigStore sharedStore] readOnlySnapshot];
        [self applyConfiguration:config];
        // The WidgetKit extension caches its timeline in a separate process.
        // Refresh it for both local writes and CLI writes observed here.
        Class reloader = NSClassFromString(@"NFWidgetReloader");
        SEL selector = NSSelectorFromString(@"reloadWidgets");
        if (reloader && [reloader respondsToSelector:selector]) {
            IMP implementation = [reloader methodForSelector:selector];
            if (implementation) {
                ((void (*)(id, SEL))implementation)(reloader, selector);
            }
        }
    });
}

#pragma mark - Windows

- (void)showLibrary {
    [NSApp activateIgnoringOtherApps:YES];
    [self.mainWindowController showWindow:nil];
    [self.mainWindowController.window makeKeyAndOrderFront:nil];
    [self.mainWindowController reloadAll];
}

- (void)showQuickPanel:(id)sender {
    [self.quickPanelController showPanel];
}

- (void)showSettings {
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindowController showWindow:nil];
    [self.settingsWindowController.window makeKeyAndOrderFront:nil];
}

- (void)showWelcome {
    if (!self.welcomeWindowController) {
        self.welcomeWindowController = [[NFCWelcomeWindowController alloc] init];
        __weak typeof(self) weakSelf = self;
        self.welcomeWindowController.onGetStarted = ^{
            [weakSelf showLibrary];
        };
        self.welcomeWindowController.onOpenSettings = ^{
            [weakSelf showSettings];
        };
    }
    [NSApp activateIgnoringOtherApps:YES];
    [self.welcomeWindowController showWindow:nil];
    [self.welcomeWindowController.window makeKeyAndOrderFront:nil];
}

- (void)showWelcomeFromSettings:(id)sender {
    [self.settingsWindowController close];
    [self showWelcome];
}

- (void)createTemplate:(NFTemplate *)template {
    NSWindow *window = self.mainWindowController.window.isVisible ? self.mainWindowController.window : nil;
    [[NFCreateCoordinator sharedCoordinator] createInDefaultLocation:template window:window];
}

#pragma mark - Menu actions

- (void)newFileFromMenu:(id)sender {
    [self showLibrary];
    [self.mainWindowController createSelectedTemplate];
}

- (void)newFileWithPanelFromMenu:(id)sender {
    [self showLibrary];
    [self.mainWindowController createSelectedTemplateWithPanel];
}

- (void)addTemplatesFromMenu:(id)sender {
    [self showLibrary];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mainWindowController showAddTemplatesPanel];
    });
}

- (void)showQuickPanelFromMenu:(id)sender {
    [self showQuickPanel:sender];
}

- (void)showLibraryFromMenu:(id)sender {
    [self showLibrary];
}

- (void)showSettingsFromMenu:(id)sender {
    [self showSettings];
}

- (void)toggleSidebarFromMenu:(id)sender {
    [self showLibrary];
    NSSplitViewController *split = (NSSplitViewController *)self.mainWindowController.window.contentViewController;
    if ([split isKindOfClass:[NSSplitViewController class]] && split.splitViewItems.count > 0) {
        NSSplitViewItem *item = split.splitViewItems.firstObject;
        [item.animator setCollapsed:!item.isCollapsed];
    }
}

- (void)toggleInspectorFromMenu:(id)sender {
    [self showLibrary];
    NSSplitViewController *split = (NSSplitViewController *)self.mainWindowController.window.contentViewController;
    if ([split isKindOfClass:[NSSplitViewController class]] && split.splitViewItems.count >= 3) {
        NSSplitViewItem *item = split.splitViewItems.lastObject;
        [item.animator setCollapsed:!item.isCollapsed];
    }
}

- (void)focusSearchFromMenu:(id)sender {
    [self showLibrary];
    [self.mainWindowController focusSearch];
}

- (void)revealSelectedTemplateFromMenu:(id)sender {
    [self showLibrary];
    [self.mainWindowController revealSelectedTemplate];
}

- (void)revealTemplatesFromMenu:(id)sender {
    NSURL *templatesURL = [NFConfigStore sharedStore].templatesURL;
    [[NSFileManager defaultManager] createDirectoryAtURL:templatesURL withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSWorkspace sharedWorkspace] openURL:templatesURL];
}

- (void)showWelcomeFromMenu:(id)sender {
    [self showWelcome];
}

- (void)showHelpFromMenu:(id)sender {
    NSURL *readme = [[NSBundle mainBundle] URLForResource:@"README" withExtension:@"md"];
    if (readme) {
        [[NSWorkspace sharedWorkspace] openURL:readme];
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New File Creation 2";
    alert.informativeText = NFLocalizedString(@"Create files from templates in Finder, from the menu bar, from the library, or with the nfc command.\n\n• ⌘N creates a file from the selected template.\n• ⇧⌘N lets you choose a name and location.\n• The menu bar icon opens templates and the quick panel.\n• Right-click in Finder for Finder menu items.\n• Run “nfc help” in Terminal for command-line usage.");
    [alert addButtonWithTitle:NFLocalizedString(@"OK")];
    [alert runModal];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    if (action == @selector(newFileFromMenu:) || action == @selector(newFileWithPanelFromMenu:)) {
        NFConfig *config = [[NFConfigStore sharedStore] readOnlySnapshot];
        return config.enabledTemplates.count > 0;
    }
    if (action == @selector(toggleSidebarFromMenu:) || action == @selector(toggleInspectorFromMenu:)) {
        return self.mainWindowController.window.isVisible;
    }
    if (action == @selector(revealSelectedTemplateFromMenu:)) {
        return self.mainWindowController.window.isVisible && [self.mainWindowController hasSelectedTemplate];
    }
    return YES;
}

#pragma mark - URL handling

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (urlString.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [self handleURL:url];
    }
}

- (NFTemplate *)templateForRequest:(NFRequest *)request config:(NFConfig *)config {
    NSString *identifier = request.templateIdentifier;
    if (identifier.length == 0) {
        return nil;
    }
    NFTemplate *template = [config templateWithIdentifier:identifier];
    if (template) {
        return template;
    }
    for (NFTemplate *candidate in config.templates) {
        if ([candidate.fileName caseInsensitiveCompare:identifier] == NSOrderedSame ||
            [candidate.resolvedDisplayName caseInsensitiveCompare:identifier] == NSOrderedSame) {
            return candidate;
        }
    }
    return nil;
}

- (void)handleURL:(NSURL *)url {
    NSError *error = nil;
    NFRequest *request = [NFRequest requestWithURL:url error:&error];
    if (!request) {
        [[NFLogger sharedLogger] error:@"Ignoring URL %@: %@", url.absoluteString, error.localizedDescription];
        return;
    }

    switch (request.kind) {
        case NFRequestKindQuick: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showQuickPanel:nil];
            });
            break;
        }
        case NFRequestKindLibrary: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showLibrary];
            });
            break;
        }
        case NFRequestKindSettings: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSettings];
            });
            break;
        }
        case NFRequestKindAddTemplate: {
            NSMutableArray<NSURL *> *urls = [NSMutableArray array];
            for (NSString *path in request.filePaths) {
                if (path.isAbsolutePath) {
                    [urls addObject:[NSURL fileURLWithPath:path.stringByStandardizingPath]];
                }
            }
            if (urls.count > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showLibrary];
                    [[NFCreateCoordinator sharedCoordinator] addTemplatesFromURLs:urls window:self.mainWindowController.window];
                    [self.mainWindowController reloadAll];
                });
            }
            break;
        }
        case NFRequestKindCreate: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleCreateRequest:request];
            });
            break;
        }
        default:
            break;
    }
}

- (void)handleCreateRequest:(NFRequest *)request {
    NSError *error = nil;
    NFConfig *config = [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:&error];
    if (!config) {
        [self presentURLError:error];
        return;
    }
    NFTemplate *template = [self templateForRequest:request config:config];
    if (!template) {
        NSError *missing = [NSError nf_errorWithCode:NFErrorCLINotFound
                                        description:[NSString stringWithFormat:NFLocalizedString(@"The template “%@” was not found."), request.templateIdentifier]];
        [self presentURLError:missing];
        return;
    }

    NSURL *directory = nil;
    if (request.directoryPath.length > 0) {
        directory = [NSURL fileURLWithPath:request.directoryPath isDirectory:YES];
    } else {
        directory = [[NFCreateCoordinator sharedCoordinator] defaultCreationDirectory];
    }

    NSURL *created = nil;
    BOOL success = [[NFCreateCoordinator sharedCoordinator] createTemplate:template
                                                              inDirectory:directory
                                                                 baseName:request.baseName
                                                                   unique:request.unique
                                                                    error:&error
                                                               createdURL:&created];
    if (!success || !created) {
        [self presentURLError:error];
        return;
    }

    BOOL configReveal = [config boolSettingForKey:@"revealAfterCreate" defaultValue:YES];
    BOOL configOpen = [config boolSettingForKey:@"openAfterCreate" defaultValue:NO];
    if (request.revealAfterCreate && !configReveal) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[created]];
    }
    if (request.openAfterCreate && !configOpen) {
        [[NSWorkspace sharedWorkspace] openURL:created];
    }
    NSWindow *window = self.mainWindowController.window.isVisible ? self.mainWindowController.window : nil;
    [[NFCreateCoordinator sharedCoordinator] applyPostCreateActionsForURL:created window:window];
}

- (void)presentURLError:(NSError *)error {
    [[NFLogger sharedLogger] error:@"URL request failed: %@", error.localizedDescription];
    if (!NSApp.isActive) {
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NFLocalizedString(@"Could not create the file");
    alert.informativeText = error.localizedDescription ?: NFLocalizedString(@"An unexpected error occurred.");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NFLocalizedString(@"OK")];
    [alert runModal];
}

@end

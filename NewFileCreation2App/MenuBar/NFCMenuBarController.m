#import "NFCMenuBarController.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFFinderMenuBuilder.h"
#import "NFShortcutCenter.h"
#import "NFLocalization.h"

@interface NFCMenuBarController () <NSMenuDelegate>
@property (nonatomic, strong, nullable) NSStatusItem *statusItem;
@property (nonatomic, strong, nullable) id statusEventMonitor;
@end

@implementation NFCMenuBarController

- (instancetype)init {
    self = [super init];
    if (self) {
        _visible = NO;
    }
    return self;
}

- (void)dealloc {
    [self removeStatusEventMonitor];
}

- (void)setVisible:(BOOL)visible {
    _visible = visible;
    if (visible) {
        if (!self.statusItem) {
            self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
            NSStatusBarButton *button = self.statusItem.button;
            button.image = [NSImage imageWithSystemSymbolName:@"doc.badge.plus" accessibilityDescription:@"New File Creation 2"];
            button.image.template = YES;
            button.toolTip = NFLocalizedString(@"New File Creation 2");
            button.target = self;
            button.action = @selector(statusButtonClicked:);
            [button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
            [button setAccessibilityLabel:@"New File Creation 2"];
            [self installStatusEventMonitor];
        }
    } else if (self.statusItem) {
        [self removeStatusEventMonitor];
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
        self.statusItem = nil;
    }
}

#pragma mark - Status item interaction

- (NSRect)screenRectForStatusButton:(NSStatusBarButton *)button {
    if (!button.window) {
        return NSZeroRect;
    }
    NSRect windowRect = [button convertRect:button.bounds toView:nil];
    return [button.window convertRectToScreen:windowRect];
}

- (void)statusButtonClicked:(NSStatusBarButton *)sender {
    NSEvent *event = NSApp.currentEvent;
    BOOL secondary = event.type == NSEventTypeRightMouseUp ||
                     (event.modifierFlags & NSEventModifierFlagControl) != 0;
    if (secondary) {
        [self showStatusMenuFromButton:sender];
        return;
    }
    NSRect anchor = [self screenRectForStatusButton:sender];
    if (self.onToggleQuickPanel) {
        self.onToggleQuickPanel(anchor);
    } else if (self.onQuickPanel) {
        self.onQuickPanel();
    }
}

- (void)installStatusEventMonitor {
    if (self.statusEventMonitor) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    self.statusEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown
                                                                   handler:^NSEvent *(NSEvent *event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.statusItem || !strongSelf.statusItem.button.window) {
            return event;
        }
        if (event.window != strongSelf.statusItem.button.window) {
            return event;
        }
        BOOL secondary = event.type == NSEventTypeRightMouseDown ||
                         (event.type == NSEventTypeLeftMouseDown &&
                          (event.modifierFlags & NSEventModifierFlagControl) != 0);
        if (!secondary) {
            return event;
        }
        [strongSelf showStatusMenuFromButton:strongSelf.statusItem.button];
        return nil;
    }];
}

- (void)removeStatusEventMonitor {
    if (self.statusEventMonitor) {
        [NSEvent removeMonitor:self.statusEventMonitor];
        self.statusEventMonitor = nil;
    }
}

- (void)showStatusMenuFromButton:(NSStatusBarButton *)button {
    if (!button) {
        return;
    }
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"New File Creation 2"];
    [self menuNeedsUpdate:menu];
    [menu popUpMenuPositioningItem:nil
                        atLocation:NSMakePoint(NSMinX(button.bounds), NSMinY(button.bounds))
                            inView:button];
}

- (NFConfig *)config {
    return [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
}

- (void)reloadMenu {
    // The status menu is built on demand. The visual quick panel reloads when shown.
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    NFConfig *config = [self config];

    NSMenuItem *quick = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Quick New File…")
                                                   action:@selector(quickPanelAction:)
                                            keyEquivalent:@""];
    quick.target = self;
    NSString *shortcut = [config stringSettingForKey:@"globalShortcut" defaultValue:@""];
    if (shortcut.length > 0 && ![shortcut.lowercaseString isEqualToString:@"none"]) {
        quick.toolTip = [NSString stringWithFormat:NFLocalizedString(@"Global shortcut: %@"), [NFShortcutCenter displayNameForShortcut:shortcut]];
    } else {
        quick.toolTip = NFLocalizedString(@"Assign a global shortcut in Settings");
    }
    [menu addItem:quick];

    NSMenuItem *newFile = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"New File") action:nil keyEquivalent:@""];
    NSMenu *newFileMenu = [NFFinderMenuBuilder menuForConfig:config
                                                      target:self
                                                      action:@selector(createTemplateAction:)
                                                     options:NFFinderMenuOptionFavoritesFirst | NFFinderMenuOptionShowIcons];
    newFile.submenu = newFileMenu;
    [menu addItem:newFile];

    NSMenuItem *add = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Add Template…") action:@selector(addTemplateAction:) keyEquivalent:@""];
    add.target = self;
    [menu addItem:add];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *library = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Open Library") action:@selector(openLibraryAction:) keyEquivalent:@""];
    library.target = self;
    [menu addItem:library];

    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Settings…") action:@selector(settingsAction:) keyEquivalent:@","];
    settings.target = self;
    [menu addItem:settings];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *about = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"About New File Creation 2")
                                                   action:@selector(aboutAction:)
                                            keyEquivalent:@""];
    about.target = self;
    [menu addItem:about];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Quit New File Creation 2")
                                                  action:@selector(quitAction:)
                                           keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
}

- (void)quickPanelAction:(id)sender {
    if (self.onQuickPanel) {
        self.onQuickPanel();
    }
}

- (void)openLibraryAction:(id)sender {
    if (self.onOpenLibrary) {
        self.onOpenLibrary();
    }
}

- (void)settingsAction:(id)sender {
    if (self.onSettings) {
        self.onSettings();
    }
}

- (void)addTemplateAction:(id)sender {
    if (self.onAddTemplate) {
        self.onAddTemplate();
    }
}

- (void)createTemplateAction:(NSMenuItem *)sender {
    NSString *identifier = sender.representedObject;
    if (![identifier isKindOfClass:[NSString class]] || !self.onCreateTemplate) {
        return;
    }
    NFConfig *config = [self config];
    NFTemplate *template = [config templateWithIdentifier:identifier];
    if (template) {
        self.onCreateTemplate(template);
    }
}

- (void)aboutAction:(id)sender {
    [NSApp orderFrontStandardAboutPanel:nil];
}

- (void)quitAction:(id)sender {
    [NSApp terminate:nil];
}

@end

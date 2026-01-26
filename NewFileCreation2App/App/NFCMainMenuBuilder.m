#import "NFCMainMenuBuilder.h"
#import "NFLocalization.h"

@implementation NFCMainMenuBuilder

+ (NSMenuItem *)itemWithTitle:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key ?: @""];
    item.target = nil;
    return item;
}

+ (NSMenu *)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"New File Creation 2" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"New File Creation 2"];
    [appMenu addItem:[self itemWithTitle:NFLocalizedString(@"About New File Creation 2") action:@selector(orderFrontStandardAboutPanel:) key:@""]];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:[self itemWithTitle:NFLocalizedString(@"Settings…") action:@selector(showSettingsFromMenu:) key:@","]];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"Services")];
    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Services") action:nil keyEquivalent:@""];
    servicesItem.submenu = servicesMenu;
    [appMenu addItem:servicesItem];
    NSApp.servicesMenu = servicesMenu;
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:[self itemWithTitle:NFLocalizedString(@"Hide New File Creation 2") action:@selector(hide:) key:@"h"]];
    NSMenuItem *hideOthers = [self itemWithTitle:NFLocalizedString(@"Hide Others") action:@selector(hideOtherApplications:) key:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [appMenu addItem:hideOthers];
    [appMenu addItem:[self itemWithTitle:NFLocalizedString(@"Show All") action:@selector(unhideAllApplications:) key:@""]];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:[self itemWithTitle:NFLocalizedString(@"Quit New File Creation 2") action:@selector(terminate:) key:@"q"]];
    appItem.submenu = appMenu;
    [mainMenu addItem:appItem];

    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"File") action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"File")];
    [fileMenu addItem:[self itemWithTitle:NFLocalizedString(@"New File") action:@selector(newFileFromMenu:) key:@"n"]];
    NSMenuItem *newPanel = [self itemWithTitle:NFLocalizedString(@"New File…") action:@selector(newFileWithPanelFromMenu:) key:@"n"];
    newPanel.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [fileMenu addItem:newPanel];
    [fileMenu addItem:[self itemWithTitle:NFLocalizedString(@"Add Template…") action:@selector(addTemplatesFromMenu:) key:@"o"]];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItem:[self itemWithTitle:NFLocalizedString(@"Quick New File…") action:@selector(showQuickPanelFromMenu:) key:@"p"]];
    [fileMenu addItem:[self itemWithTitle:NFLocalizedString(@"Open Library") action:@selector(showLibraryFromMenu:) key:@"0"]];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItem:[self itemWithTitle:NFLocalizedString(@"Close") action:@selector(performClose:) key:@"w"]];
    fileItem.submenu = fileMenu;
    [mainMenu addItem:fileItem];

    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Edit") action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"Edit")];
    [editMenu addItem:[self itemWithTitle:NFLocalizedString(@"Undo") action:@selector(undo:) key:@"z"]];
    NSMenuItem *redo = [self itemWithTitle:NFLocalizedString(@"Redo") action:@selector(redo:) key:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:redo];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:[self itemWithTitle:NFLocalizedString(@"Cut") action:@selector(cut:) key:@"x"]];
    [editMenu addItem:[self itemWithTitle:NFLocalizedString(@"Copy") action:@selector(copy:) key:@"c"]];
    [editMenu addItem:[self itemWithTitle:NFLocalizedString(@"Paste") action:@selector(paste:) key:@"v"]];
    [editMenu addItem:[self itemWithTitle:NFLocalizedString(@"Select All") action:@selector(selectAll:) key:@"a"]];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:[self itemWithTitle:NFLocalizedString(@"Search Templates") action:@selector(focusSearchFromMenu:) key:@"f"]];
    editItem.submenu = editMenu;
    [mainMenu addItem:editItem];

    NSMenuItem *viewItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"View") action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"View")];
    NSMenuItem *sidebar = [self itemWithTitle:NFLocalizedString(@"Show or Hide Sidebar") action:@selector(toggleSidebarFromMenu:) key:@"s"];
    sidebar.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;
    [viewMenu addItem:sidebar];
    NSMenuItem *inspector = [self itemWithTitle:NFLocalizedString(@"Show or Hide Inspector") action:@selector(toggleInspectorFromMenu:) key:@"i"];
    inspector.keyEquivalentModifierMask = NSEventModifierFlagOption | NSEventModifierFlagCommand;
    [viewMenu addItem:inspector];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItem:[self itemWithTitle:NFLocalizedString(@"Reveal Selected Template") action:@selector(revealSelectedTemplateFromMenu:) key:@"r"]];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *fullScreen = [self itemWithTitle:NFLocalizedString(@"Enter Full Screen") action:@selector(toggleFullScreen:) key:@"f"];
    fullScreen.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;
    [viewMenu addItem:fullScreen];
    viewItem.submenu = viewMenu;
    [mainMenu addItem:viewItem];

    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Window") action:nil keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"Window")];
    [windowMenu addItem:[self itemWithTitle:NFLocalizedString(@"Minimize") action:@selector(performMiniaturize:) key:@"m"]];
    [windowMenu addItem:[self itemWithTitle:NFLocalizedString(@"Zoom") action:@selector(performZoom:) key:@""]];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItem:[self itemWithTitle:NFLocalizedString(@"Bring All to Front") action:@selector(arrangeInFront:) key:@""]];
    windowItem.submenu = windowMenu;
    [mainMenu addItem:windowItem];
    NSApp.windowsMenu = windowMenu;

    NSMenuItem *helpItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Help") action:nil keyEquivalent:@""];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"Help")];
    [helpMenu addItem:[self itemWithTitle:NFLocalizedString(@"New File Creation 2 Help") action:@selector(showHelpFromMenu:) key:@"?"]];
    [helpMenu addItem:[self itemWithTitle:NFLocalizedString(@"Open Templates Folder") action:@selector(revealTemplatesFromMenu:) key:@""]];
    [helpMenu addItem:[self itemWithTitle:NFLocalizedString(@"Show Welcome") action:@selector(showWelcomeFromMenu:) key:@""]];
    helpItem.submenu = helpMenu;
    [mainMenu addItem:helpItem];
    NSApp.helpMenu = helpMenu;

    return mainMenu;
}

@end

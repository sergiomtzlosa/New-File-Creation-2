#import "NFCFinderSync.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFFileCreator.h"
#import "NFFinderMenuBuilder.h"
#import "NFFinderDestination.h"
#import "NFLocalization.h"
#import "NFRequest.h"
#import "NFVersion.h"
#import "NFErrors.h"
#import <pwd.h>
#import <unistd.h>

static NSString * const NFCFinderBundleIdentifier = @"com.sid.newfilecreation2";

@interface NFCFinderSync ()
@property (nonatomic, copy, nullable) NSString *supportDirectoryPath;
@property (nonatomic, assign) FIMenuKind lastMenuKind;
@property (nonatomic, copy, nullable) NSDictionary<NSNumber *, NSString *> *templateIdentifiersByTag;
@property (nonatomic, strong, nullable) NSURL *menuDestinationURL;
@end

@implementation NFCFinderSync

+ (NSString *)realHomeDirectory {
    struct passwd *pw = getpwuid(getuid());
    if (pw && pw->pw_dir) {
        return [NSString stringWithUTF8String:pw->pw_dir];
    }
    return NSHomeDirectory();
}

- (NSString *)supportDirectoryPath {
    if (!_supportDirectoryPath) {
        _supportDirectoryPath = [[[self class] realHomeDirectory]
                                 stringByAppendingPathComponent:@"Library/Application Support/New File Creation 2"];
    }
    return _supportDirectoryPath;
}

- (NSString *)templatesDirectoryPath {
    return [self.supportDirectoryPath stringByAppendingPathComponent:@"Templates"];
}

- (NSString *)configPath {
    return [self.supportDirectoryPath stringByAppendingPathComponent:@"config.json"];
}

- (nullable NFConfig *)readConfig {
    NSData *data = [NSData dataWithContentsOfFile:[self configPath] options:NSDataReadingMappedIfSafe error:nil];
    if (!data) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *dictionary = object;
    NSInteger schema = [dictionary[@"schemaVersion"] respondsToSelector:@selector(integerValue)]
        ? [dictionary[@"schemaVersion"] integerValue] : 1;
    if (schema > NFCSchemaVersion) {
        return nil;
    }
    return [[NFConfig alloc] initWithDictionary:dictionary];
}

- (NSURL *)templateURLForTemplate:(NFTemplate *)template {
    NSString *name = template.fileName;
    if (name.length == 0) {
        return [NSURL fileURLWithPath:[self templatesDirectoryPath] isDirectory:YES];
    }
    return [NSURL fileURLWithPath:[[self templatesDirectoryPath] stringByAppendingPathComponent:name]];
}

- (void)configureDirectoryURLs {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    controller.directoryURLs = [NSSet setWithObject:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configureDirectoryURLs];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(configDidChange:)
                                                                name:@"com.sid.newfilecreation2.configchanged"
                                                              object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configDidChange:(NSNotification *)notification {
    // Menus are rebuilt by Finder on demand; nothing to cache.
}

#pragma mark - Finder Sync

- (NSString *)toolbarItemName {
    return NFLocalizedString(@"New File");
}

- (NSString *)toolbarItemToolTip {
    return NFLocalizedString(@"Create a new file from a template");
}

- (NSImage *)toolbarItemImage {
    NSImage *image = [NSImage imageWithSystemSymbolName:@"doc.badge.plus" accessibilityDescription:NFLocalizedString(@"New File")];
    image.size = NSMakeSize(16, 16);
    return image;
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)menuKind {
    self.lastMenuKind = menuKind;
    self.templateIdentifiersByTag = nil;
    self.menuDestinationURL = nil;
    NFConfig *config = [self readConfig];
    if (!config) {
        return nil;
    }

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    BOOL includeNewFile = [config boolSettingForKey:@"includeNewFileInFinderMenu" defaultValue:YES];
    BOOL includeAdd = [config boolSettingForKey:@"includeAddAsTemplate" defaultValue:YES];

    if (includeNewFile && config.enabledTemplates.count > 0) {
        NFFinderMenuOptions options = NFFinderMenuOptionNone;
        if ([config boolSettingForKey:@"favoritesFirst" defaultValue:YES]) {
            options |= NFFinderMenuOptionFavoritesFirst;
        }
        if ([config boolSettingForKey:@"groupByCategory" defaultValue:NO]) {
            options |= NFFinderMenuOptionGroupByCategory;
        }
        if ([config boolSettingForKey:@"showFileIcons" defaultValue:YES]) {
            options |= NFFinderMenuOptionShowIcons;
        }
        NSMenu *templateMenu = [NFFinderMenuBuilder menuForConfig:config
                                                          target:self
                                                          action:@selector(createFileFromTemplate:)
                                                         options:options];
        // The action's sender is recreated across the Finder Sync XPC boundary,
        // so captured representedObject values do not survive. Keep an
        // identifier snapshot keyed by the integer tags on the local menu.
        NSMutableDictionary<NSNumber *, NSString *> *identifiers = [NSMutableDictionary dictionary];
        [self collectTemplateIdentifiersFromMenu:templateMenu intoDictionary:identifiers];
        self.templateIdentifiersByTag = identifiers;
        self.menuDestinationURL = [self destinationDirectoryForMenuKind:menuKind];

        NSMenuItem *newFileItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"New File") action:nil keyEquivalent:@""];
        newFileItem.image = [NSImage imageWithSystemSymbolName:@"doc.badge.plus" accessibilityDescription:NFLocalizedString(@"New File")];
        newFileItem.submenu = templateMenu;
        [menu addItem:newFileItem];
    }

    if (includeAdd && (menuKind == FIMenuKindContextualMenuForItems || menuKind == FIMenuKindToolbarItemMenu)) {
        if (menu.numberOfItems > 0) {
            [menu addItem:[NSMenuItem separatorItem]];
        }
        NSMenuItem *addItem = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"Add as Template")
                                                         action:@selector(addSelectedItemsAsTemplates:)
                                                  keyEquivalent:@""];
        addItem.target = self;
        addItem.image = [NSImage imageWithSystemSymbolName:@"plus.rectangle.on.folder" accessibilityDescription:NFLocalizedString(@"Add as Template")];
        [menu addItem:addItem];
    }

    return menu.numberOfItems > 0 ? menu : nil;
}

- (void)collectTemplateIdentifiersFromMenu:(NSMenu *)menu
                          intoDictionary:(NSMutableDictionary<NSNumber *, NSString *> *)identifiers {
    for (NSMenuItem *item in menu.itemArray) {
        id represented = item.representedObject;
        if (item.tag > 0 && [represented isKindOfClass:[NSString class]]) {
            identifiers[@(item.tag)] = represented;
        }
        if (item.submenu) {
            [self collectTemplateIdentifiersFromMenu:item.submenu intoDictionary:identifiers];
        }
    }
}

- (nullable NSString *)templateIdentifierForMenuItem:(NSMenuItem *)item {
    NSString *identifier = self.templateIdentifiersByTag[@(item.tag)];
    if (identifier) {
        return identifier;
    }
    // In-process menus (and tests) still carry representedObject.
    id represented = item.representedObject;
    return [represented isKindOfClass:[NSString class]] ? represented : nil;
}

- (nullable NSURL *)destinationDirectoryForMenuKind:(FIMenuKind)menuKind {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    NSURL *desktop = [NSURL fileURLWithPath:[[[self class] realHomeDirectory] stringByAppendingPathComponent:@"Desktop"]
                                isDirectory:YES];
    return [NFFinderDestination directoryURLForTargetedURL:controller.targetedURL
                                             selectedURLs:controller.selectedItemURLs
                                        useSelectedItems:(menuKind == FIMenuKindContextualMenuForItems)
                                              fallbackURL:desktop];
}

- (void)createFileFromTemplate:(NSMenuItem *)sender {
    NSString *identifier = [self templateIdentifierForMenuItem:sender];
    if (!identifier) {
        NSBeep();
        return;
    }
    NFConfig *config = [self readConfig];
    NFTemplate *template = [config templateWithIdentifier:identifier];
    if (!template) {
        NSBeep();
        return;
    }
    NSURL *directory = self.menuDestinationURL ?: [self destinationDirectoryForMenuKind:self.lastMenuKind];
    if (!directory) {
        NSBeep();
        return;
    }

    NSString *baseName = [config stringSettingForKey:@"defaultBaseName" defaultValue:NFDefaultBaseName];
    NSString *behavior = [config stringSettingForKey:@"finderCreationBehavior" defaultValue:@"instant"];
    if ([behavior isEqualToString:@"ask"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = [NSString stringWithFormat:NFLocalizedString(@"New %@"), template.resolvedDisplayName];
        alert.informativeText = [NSString stringWithFormat:NFLocalizedString(@"Create the file in “%@”."), directory.lastPathComponent];
        [alert addButtonWithTitle:NFLocalizedString(@"Create")];
        [alert addButtonWithTitle:NFLocalizedString(@"Cancel")];
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
        field.stringValue = baseName;
        field.placeholderString = NFDefaultBaseName;
        alert.accessoryView = field;
        if ([alert runModal] != NSAlertFirstButtonReturn) {
            return;
        }
        NSString *entered = [field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (entered.length > 0) {
            baseName = entered;
        }
    }

    // Finder extensions are sandboxed and cannot write to arbitrary folders or
    // the Desktop. Hand the request to the non-sandboxed app, which performs the
    // copy, applies post-create actions, and updates recents.
    NFRequest *request = [[NFRequest alloc] init];
    request.kind = NFRequestKindCreate;
    request.templateIdentifier = template.identifier;
    request.directoryPath = directory.path;
    request.baseName = baseName;
    request.unique = YES;
    request.revealAfterCreate = YES;
    [self openCreateRequestInApp:request];
}

- (void)openCreateRequestInApp:(NFRequest *)request {
    NSURL *url = [request URLRepresentation];
    if (!url) {
        NSBeep();
        return;
    }

    void (^showFailure)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NFLocalizedString(@"Could not create the file");
            alert.informativeText = NFLocalizedString(@"Open New File Creation 2 once, then try the Finder menu again.");
            [alert addButtonWithTitle:NFLocalizedString(@"OK")];
            [alert runModal];
        });
    };

    // NSWorkspace launches the containing app through its URL scheme. Finder
    // extensions do not always invoke NSExtensionContext completion handlers,
    // so only use that route as a fallback.
    if ([[NSWorkspace sharedWorkspace] openURL:url]) {
        return;
    }

    NSExtensionContext *context = (NSExtensionContext *)[FIFinderSyncController defaultController];
    if ([context respondsToSelector:@selector(openURL:completionHandler:)]) {
        [context openURL:url completionHandler:^(BOOL success) {
            if (!success) {
                showFailure();
            }
        }];
        return;
    }
    showFailure();
}

- (void)addSelectedItemsAsTemplates:(id)sender {
    NSArray<NSURL *> *selected = [FIFinderSyncController defaultController].selectedItemURLs;
    if (selected.count == 0) {
        NSBeep();
        return;
    }
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSURL *url in selected) {
        if (url.path.length > 0) {
            [paths addObject:url.path];
        }
    }
    NSURL *url = [NFRequest addTemplateRequestURLWithPaths:paths];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

@end

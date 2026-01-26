#import "NFCFinderSync.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFFileCreator.h"
#import "NFFinderMenuBuilder.h"
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

- (nullable NSURL *)destinationDirectoryForMenuKind:(FIMenuKind)menuKind {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    NSURL *target = controller.targetedURL;
    NSArray<NSURL *> *selected = controller.selectedItemURLs;

    if (menuKind == FIMenuKindContextualMenuForItems && selected.count > 0) {
        if (selected.count == 1) {
            NSNumber *isDirectory = nil;
            [selected[0] getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            target = isDirectory.boolValue ? selected[0] : selected[0].URLByDeletingLastPathComponent;
        } else {
            target = selected.firstObject.URLByDeletingLastPathComponent;
        }
    }

    if (!target) {
        return nil;
    }
    NSNumber *isDirectory = nil;
    if ([target getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil] && !isDirectory.boolValue) {
        target = target.URLByDeletingLastPathComponent;
    }
    return target;
}

- (void)createFileFromTemplate:(NSMenuItem *)sender {
    NSString *identifier = sender.representedObject;
    if (![identifier isKindOfClass:[NSString class]]) {
        return;
    }
    NFConfig *config = [self readConfig];
    NFTemplate *template = [config templateWithIdentifier:identifier];
    if (!template) {
        return;
    }
    NSURL *directory = [self destinationDirectoryForMenuKind:self.lastMenuKind];
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

    NSError *error = nil;
    NSURL *templateURL = [self templateURLForTemplate:template];
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:templateURL
                                                       template:template
                                                      directory:directory
                                                       baseName:baseName
                                                         unique:YES
                                                          error:&error];
    if (!created) {
        // The extension is sandboxed. If the direct copy is denied, ask the
        // non-sandboxed app to perform the same request through its URL scheme.
        if (error.code == NFErrorDestinationNotWritable || error.code == NFErrorTemplateUnreadable) {
            NFRequest *request = [[NFRequest alloc] init];
            request.kind = NFRequestKindCreate;
            request.templateIdentifier = template.identifier;
            request.directoryPath = directory.path;
            request.baseName = baseName;
            request.unique = YES;
            request.revealAfterCreate = YES;
            [[NSWorkspace sharedWorkspace] openURL:[request URLRepresentation]];
            return;
        }
        NSLog(@"Finder extension could not create a file: %@", error.localizedDescription);
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NFLocalizedString(@"Could not create the file");
        alert.informativeText = error.localizedDescription ?: NFLocalizedString(@"An unexpected error occurred.");
        [alert runModal];
        return;
    }

    NSLog(@"Finder extension created %@", created.path);
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[created]];
    if ([config boolSettingForKey:@"openAfterCreate" defaultValue:NO]) {
        [[NSWorkspace sharedWorkspace] openURL:created];
    }
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

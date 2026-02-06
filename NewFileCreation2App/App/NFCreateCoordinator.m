#import "NFCreateCoordinator.h"
#import "NFFileCreator.h"
#import "NFSanitize.h"
#import "NFTemplate.h"
#import "NFConfig.h"
#import "NFErrors.h"
#import "NFPaths.h"
#import "NFCToastPresenter.h"
#import "NFLocalization.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation NFCreateCoordinator

+ (instancetype)sharedCoordinator {
    static NFCreateCoordinator *coordinator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinator = [[self alloc] init];
    });
    return coordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (NFConfigStore *)store {
    return [NFConfigStore sharedStore];
}

- (NFConfig *)config {
    return [self.store loadConfigCreatingIfNeeded:YES error:nil] ?: [NFConfig defaultConfig];
}

- (NSURL *)defaultCreationDirectory {
    NFConfig *config = [self config];
    NSString *last = [config stringSettingForKey:@"lastUsedDirectory" defaultValue:@""];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (last.length > 0 && [fm fileExistsAtPath:last isDirectory:&isDir] && isDir) {
        return [NSURL fileURLWithPath:last isDirectory:YES];
    }
    NSURL *desktop = [fm URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask].firstObject;
    if (desktop) {
        return desktop;
    }
    return [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
}

- (BOOL)createTemplate:(NFTemplate *)template
           inDirectory:(NSURL *)directory
              baseName:(NSString *)baseName
                unique:(BOOL)unique
                 error:(NSError **)error
            createdURL:(NSURL **)createdURL {
    NFConfig *config = [self config];
    if (baseName.length == 0) {
        baseName = [config stringSettingForKey:@"defaultBaseName" defaultValue:@"Untitled"];
    }
    NSURL *templateURL = [self.store templateFileURLForTemplate:template];
    NSError *createError = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:templateURL
                                                       template:template
                                                      directory:directory
                                                       baseName:baseName
                                                         unique:unique
                                                          error:&createError];
    if (!created) {
        if (error) {
            *error = createError;
        }
        return NO;
    }

    NSError *updateError = nil;
    [self.store updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
        NFTemplate *current = [latest templateWithIdentifier:template.identifier] ?: template;
        [latest recordUsageOfTemplate:current];
        [latest addRecentFile:created.path];
        [latest setSetting:directory.path forKey:@"lastUsedDirectory"];
        return YES;
    } error:&updateError];
    if (updateError) {
        NSLog(@"New File Creation 2: could not save creation metadata: %@", updateError);
    }
    if (createdURL) {
        *createdURL = created;
    }
    return YES;
}

- (void)applyPostCreateActionsForURL:(NSURL *)url window:(NSWindow *)window {
    NFConfig *config = [self config];
    if ([config boolSettingForKey:@"revealAfterCreate" defaultValue:YES]) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
    }
    if ([config boolSettingForKey:@"openAfterCreate" defaultValue:NO]) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
    [self playConfiguredSound];
    if ([config boolSettingForKey:@"showToast" defaultValue:YES]) {
        NSString *message = [NSString stringWithFormat:NFLocalizedString(@"Created %@"), url.lastPathComponent];
        [NFCToastPresenter showMessage:message inWindow:window actionTitle:NFLocalizedString(@"Show") action:^{
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
        }];
    }
}

- (void)playConfiguredSound {
    NFConfig *config = [self config];
    if (![config boolSettingForKey:@"playSound" defaultValue:NO]) {
        return;
    }
    NSString *soundName = [config stringSettingForKey:@"soundName" defaultValue:@"Glass"];
    soundName = [soundName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (soundName.length == 0) {
        return;
    }
    if (self.soundPlayer) {
        self.soundPlayer(soundName);
        return;
    }
    [[NSSound soundNamed:soundName] play];
}


- (void)createInDefaultLocation:(NFTemplate *)template window:(NSWindow *)window {
    NSError *error = nil;
    NSURL *created = nil;
    if (![self createTemplate:template
                  inDirectory:[self defaultCreationDirectory]
                     baseName:nil
                       unique:YES
                        error:&error
                   createdURL:&created]) {
        [self presentError:error window:window];
        return;
    }
    [self applyPostCreateActionsForURL:created window:window];
}

- (void)createWithSavePanel:(NFTemplate *)template window:(NSWindow *)window {
    NFConfig *config = [self config];
    NSSavePanel *panel = [NSSavePanel savePanel];
    NSString *baseName = [config stringSettingForKey:@"defaultBaseName" defaultValue:@"Untitled"];
    NSString *extension = template.fileExtension;
    panel.title = NFLocalizedString(@"New File…");
    panel.prompt = NFLocalizedString(@"Create");
    panel.nameFieldStringValue = extension.length > 0 ? [NSString stringWithFormat:@"%@.%@", baseName, extension] : baseName;
    panel.directoryURL = [self defaultCreationDirectory];
    panel.canCreateDirectories = YES;
    panel.showsTagField = NO;
    if (extension.length > 0) {
        UTType *type = [UTType typeWithFilenameExtension:extension];
        if (type) {
            panel.allowedContentTypes = @[type];
        }
    }

    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, 36)];
    NSTextField *label = [NSTextField labelWithString:[NSString stringWithFormat:NFLocalizedString(@"Template: %@"), template.resolvedDisplayName]];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textColor = NSColor.secondaryLabelColor;
    label.font = [NSFont systemFontOfSize:11];
    [accessory addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:accessory.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor]
    ]];
    panel.accessoryView = accessory;

    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        NSError *error = nil;
        NSURL *created = [NFFileCreator createFileFromTemplateAtURL:[self.store templateFileURLForTemplate:template]
                                                       destination:panel.URL
                                                            unique:NO
                                                             error:&error];
        if (!created) {
            [self presentError:error window:window];
            return;
        }
        NSError *updateError = nil;
        [self.store updateConfig:^BOOL(NFConfig *latest, NSError **blockError) {
            NFTemplate *current = [latest templateWithIdentifier:template.identifier] ?: template;
            [latest recordUsageOfTemplate:current];
            [latest addRecentFile:created.path];
            [latest setSetting:created.URLByDeletingLastPathComponent.path forKey:@"lastUsedDirectory"];
            return YES;
        } error:&updateError];
        [self applyPostCreateActionsForURL:created window:window];
    }];
}

- (void)presentError:(NSError *)error window:(NSWindow *)window {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NFLocalizedString(@"Could not create the file");
    alert.informativeText = error.localizedDescription ?: NFLocalizedString(@"An unexpected error occurred.");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NFLocalizedString(@"OK")];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

- (void)addTemplatesFromURLs:(NSArray<NSURL *> *)urls window:(NSWindow *)window {
    if (urls.count == 0) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *dirError = nil;
    [NFPaths ensureDirectory:self.store.templatesURL error:&dirError];
    NSMutableArray<NSDictionary *> *added = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSURL *destination = [self.store.templatesURL URLByAppendingPathComponent:url.lastPathComponent];
        if ([fm fileExistsAtPath:destination.path]) {
            destination = [NFSanitize uniqueDestinationURLForURL:destination];
        }
        NSError *copyError = nil;
        if (![fm copyItemAtURL:url toURL:destination error:&copyError]) {
            [self presentError:copyError window:window];
            continue;
        }
        [added addObject:@{@"fileName": destination.lastPathComponent}];
    }
    if (added.count == 0) {
        return;
    }
    NSError *updateError = nil;
    [self.store updateConfig:^BOOL(NFConfig *config, NSError **blockError) {
        NSInteger index = (NSInteger)config.templates.count;
        for (NSDictionary *entry in added) {
            NSString *fileName = entry[@"fileName"];
            NFTemplate *template = [NFTemplate templateWithFileName:fileName];
            template.displayName = [NFTemplate displayNameForFileName:fileName];
            template.category = [NFTemplate inferCategoryForFileExtension:fileName.pathExtension];
            template.sortIndex = index++;
            template.source = @"user";
            [config.templates addObject:template];
        }
        return YES;
    } error:&updateError];
    if (updateError) {
        [self presentError:updateError window:window];
        return;
    }
    NSString *message = added.count == 1
        ? [NSString stringWithFormat:NFLocalizedString(@"Added %lu template"), (unsigned long)added.count]
        : [NSString stringWithFormat:NFLocalizedString(@"Added %lu templates"), (unsigned long)added.count];
    [NFCToastPresenter showMessage:message inWindow:window];
}

@end

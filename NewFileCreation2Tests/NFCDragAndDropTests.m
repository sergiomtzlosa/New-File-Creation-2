#import "NFTestSupport.h"
#import "NFCQuickPanelController.h"
#import "NFCTemplateGridViewController.h"
#import "NFFilePromiseProvider.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFSanitize.h"
#import "NFLocalization.h"

static NSString * const NFCTestExternalVolumeEnvironmentKey = @"NFC_TEST_EXTERNAL_VOLUME";
static NSString * const NFCTestRealDesktopEnvironmentKey = @"NFC_TEST_REAL_DESKTOP";

#pragma mark - Test drag destinations

/// A minimal file-URL drop target that behaves like Finder or another window:
/// it reads file URLs from the pasteboard and copies them into its destination.
@interface NFCTestFileDropView : NSView <NSDraggingDestination>
@property (nonatomic, strong) NSURL *destinationDirectory;
@property (nonatomic, copy, nullable) NSArray<NSURL *> *lastReceivedURLs;
@end

@implementation NFCTestFileDropView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    }
    return self;
}

- (NSArray<NSURL *> *)fileURLsFromPasteboard:(NSPasteboard *)pasteboard {
    NSArray<NSURL *> *urls = [pasteboard readObjectsForClasses:@[NSURL.class] options:@{}];
    if (urls.count > 0) {
        return urls;
    }
    NSString *string = [pasteboard stringForType:NSPasteboardTypeFileURL];
    if (string.length > 0) {
        NSURL *url = [NSURL URLWithString:string];
        return url ? @[url] : @[];
    }
    return @[];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [self fileURLsFromPasteboard:sender.draggingPasteboard].count > 0 ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    return [self fileURLsFromPasteboard:sender.draggingPasteboard].count > 0;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSArray<NSURL *> *urls = [self fileURLsFromPasteboard:sender.draggingPasteboard];
    if (urls.count == 0 || !self.destinationDirectory) {
        return NO;
    }
    NSMutableArray<NSURL *> *copied = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSURL *source in urls) {
        NSURL *proposed = [self.destinationDirectory URLByAppendingPathComponent:source.lastPathComponent];
        NSURL *destination = [NFSanitize uniqueDestinationURLForURL:proposed];
        NSError *error = nil;
        if ([fm copyItemAtURL:source toURL:destination error:&error]) {
            [copied addObject:destination];
        }
    }
    self.lastReceivedURLs = copied;
    return copied.count == urls.count;
}

@end

/// A minimal custom window that advertises file-promise support and resolves a
/// promise into its destination directory. AppKit only permits
/// NSFilePromiseReceiver to be invoked from inside a real drag operation, so the
/// test resolves the provider through the same delegate callback that a real
/// promise-aware window ultimately invokes.
@interface NFCTestPromiseDropWindow : NSObject
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NFCTestFileDropView *dropView;
@property (nonatomic, strong) NSURL *destinationDirectory;
- (BOOL)isRegisteredForFilePromises;
- (BOOL)acceptPromiseProvider:(NFFilePromiseProvider *)provider error:(NSError **)error;
@end

@implementation NFCTestPromiseDropWindow

- (instancetype)initWithDestinationDirectory:(NSURL *)destinationDirectory {
    self = [super init];
    if (self) {
        _destinationDirectory = destinationDirectory;
        _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 300)
                                             styleMask:NSWindowStyleMaskBorderless
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        _dropView = [[NFCTestFileDropView alloc] initWithFrame:NSMakeRect(0, 0, 420, 300)];
        [_dropView registerForDraggedTypes:[NSFilePromiseReceiver readableDraggedTypes]];
        _window.contentView = _dropView;
    }
    return self;
}

- (BOOL)isRegisteredForFilePromises {
    NSSet<NSString *> *promiseTypes = [NSSet setWithArray:[NSFilePromiseReceiver readableDraggedTypes]];
    for (NSString *type in self.dropView.registeredDraggedTypes) {
        if ([promiseTypes containsObject:type]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)acceptPromiseProvider:(NFFilePromiseProvider *)provider error:(NSError **)error {
    NSURL *destination = [self.destinationDirectory URLByAppendingPathComponent:provider.promisedFileName];
    __block NSError *writeError = nil;
    [provider filePromiseProvider:provider writePromiseToURL:destination completionHandler:^(NSError * _Nullable completionError) {
        writeError = completionError;
    }];
    if (writeError && error) {
        *error = writeError;
    }
    return writeError == nil;
}

@end

/// A dragging-info stand-in for the file-URL drop target tests. The properties
/// required by NSDraggingInfo are sufficient for the destination methods above.
@interface NFCTestDraggingInfo : NSObject <NSDraggingInfo>
@property (nonatomic, strong, nullable) NSWindow *draggingDestinationWindow;
@property (nonatomic, assign) NSDragOperation draggingSourceOperationMask;
@property (nonatomic, assign) NSPoint draggingLocation;
@property (nonatomic, assign) NSPoint draggedImageLocation;
@property (nonatomic, strong) NSPasteboard *draggingPasteboard;
@property (nonatomic, weak, nullable) id draggingSource;
@property (nonatomic, assign) NSInteger draggingSequenceNumber;
@property (nonatomic, assign) NSDraggingFormation draggingFormation;
@property (nonatomic, assign) BOOL animatesToDestination;
@property (nonatomic, assign) NSInteger numberOfValidItemsForDrop;
@property (nonatomic, assign) NSSpringLoadingHighlight springLoadingHighlight;
@end

@implementation NFCTestDraggingInfo

- (NSImage *)draggedImage {
    return nil;
}

- (void)slideDraggedImageTo:(NSPoint)screenPoint {
}

- (NSArray<NSString *> *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
    return nil;
}

- (void)enumerateDraggingItemsWithOptions:(NSDraggingItemEnumerationOptions)enumOpts
                                  forView:(NSView *)view
                                  classes:(NSArray<Class> *)classArray
                            searchOptions:(NSDictionary<NSPasteboardReadingOptionKey, id> *)searchOptions
                               usingBlock:(void (^)(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop))block {
}

- (void)resetSpringLoading {
}

@end

@interface NFCTemplateGridViewController (NFCDragTesting)
- (NSPasteboardItem *)collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface NFCDragAndDropTests : NFTestCase
@end

#pragma mark - Tests

@implementation NFCDragAndDropTests

- (NFConfig *)config {
    return [[NFConfigStore sharedStore] loadConfigCreatingIfNeeded:YES error:nil];
}

- (NFFilePromiseProvider *)firstPromiseFromQuickPanel:(NFCQuickPanelController **)outPanel {
    NFCQuickPanelController *panel = [[NFCQuickPanelController alloc] init];
    [panel reloadData];
    NSTableView *tableView = [panel valueForKey:@"tableView"];
    XCTAssertGreaterThan(tableView.numberOfRows, 0);
    id<NSPasteboardWriting> writer = [(id<NSTableViewDataSource>)panel tableView:tableView pasteboardWriterForRow:0];
    XCTAssertTrue([writer isKindOfClass:[NFFilePromiseProvider class]]);
    if (outPanel) {
        *outPanel = panel;
    }
    return (NFFilePromiseProvider *)writer;
}

- (NSURL *)externalVolumeRootOrSkip {
    NSString *override = NSProcessInfo.processInfo.environment[NFCTestExternalVolumeEnvironmentKey];
    if (override.length > 0) {
        NSURL *url = [NSURL fileURLWithPath:override.stringByExpandingTildeInPath isDirectory:YES];
        if ([[NSFileManager defaultManager] isWritableFileAtPath:url.path]) {
            return url;
        }
        XCTSkip(@"NFC_TEST_EXTERNAL_VOLUME is not a writable directory: %@", url.path);
    }

    NSArray<NSURL *> *volumes = [[NSFileManager defaultManager]
        mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsInternalKey, NSURLVolumeIsReadOnlyKey]
                                                options:NSVolumeEnumerationSkipHiddenVolumes];
    for (NSURL *volume in volumes) {
        if ([volume.path isEqualToString:@"/"]) {
            continue;
        }
        NSNumber *internal = nil;
        NSNumber *readOnly = nil;
        [volume getResourceValue:&internal forKey:NSURLVolumeIsInternalKey error:nil];
        [volume getResourceValue:&readOnly forKey:NSURLVolumeIsReadOnlyKey error:nil];
        if (internal.boolValue || readOnly.boolValue) {
            continue;
        }
        if ([[NSFileManager defaultManager] isWritableFileAtPath:volume.path]) {
            return volume;
        }
    }
    return nil;
}

- (NSURL *)temporaryDirectoryOnExternalVolumeOrSkip {
    NSURL *root = [self externalVolumeRootOrSkip];
    if (!root) {
        XCTSkip(@"Mount a writable external volume or set %@ to run this test.", NFCTestExternalVolumeEnvironmentKey);
    }
    NSURL *directory = [root URLByAppendingPathComponent:[NSString stringWithFormat:@"nfc-test-%@", NSUUID.UUID.UUIDString]
                                             isDirectory:YES];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory
                                   withIntermediateDirectories:NO
                                                    attributes:nil
                                                         error:&error]) {
        XCTSkip(@"The external volume is not writable at %@: %@", root.path, error.localizedDescription);
    }
    return directory;
}

- (void)testQuickPanelPromiseDropsIntoFinderStyleFolderAndRecordsMetadata {
    NFCQuickPanelController *panel = nil;
    NFFilePromiseProvider *provider = [self firstPromiseFromQuickPanel:&panel];
    NFTemplate *template = provider.template;
    NSURL *templateURL = [[NFConfigStore sharedStore] templateFileURLForTemplate:template];
    NSData *templateContents = [NSData dataWithContentsOfURL:templateURL];
    XCTAssertNotNil(templateContents);

    NSString *expectedName = [NFFilePromiseProvider promisedFileNameForTemplate:template defaultBaseName:@"Untitled"];
    XCTAssertEqualObjects(provider.promisedFileName, expectedName);
    XCTAssertTrue([provider.fileType length] > 0);
    XCTAssertNotNil(provider.didWriteFile);

    NSURL *destinationDirectory = [self makeDirectoryNamed:@"Finder Window"];
    NSURL *destination = [destinationDirectory URLByAppendingPathComponent:provider.promisedFileName];
    __block NSError *writeError = [NSError errorWithDomain:@"unset" code:1 userInfo:nil];
    [provider filePromiseProvider:provider writePromiseToURL:destination completionHandler:^(NSError * _Nullable error) {
        writeError = error;
    }];
    XCTAssertNil(writeError);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:destination.path]);
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:destination], templateContents);

    NSPredicate *metadataPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NFConfig *config = [[NFConfigStore sharedStore] readOnlySnapshot];
        return [config.recentFiles containsObject:destination.path];
    }];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:metadataPredicate
                                                                                           object:nil];
    [self waitForExpectations:@[expectation] timeout:2.0];

    NFConfig *updated = self.config;
    XCTAssertTrue([updated.recentFiles containsObject:destination.path]);
    XCTAssertEqualObjects([updated stringSettingForKey:@"lastUsedDirectory" defaultValue:@""], destinationDirectory.path);
    XCTAssertEqual([updated templateWithIdentifier:template.identifier].useCount, template.useCount + 1);

    NSData *before = [NSData dataWithContentsOfURL:destination];
    __block NSError *overwriteError = nil;
    [provider filePromiseProvider:provider writePromiseToURL:destination completionHandler:^(NSError * _Nullable error) {
        overwriteError = error;
    }];
    XCTAssertNotNil(overwriteError);
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:destination], before);
    [panel.window orderOut:nil];
}

- (void)testQuickPanelPromiseDropsIntoCustomFilePromiseWindow {
    NFCQuickPanelController *panel = nil;
    NFFilePromiseProvider *provider = [self firstPromiseFromQuickPanel:&panel];
    NSURL *destinationDirectory = [self makeDirectoryNamed:@"Custom Window"];
    NFCTestPromiseDropWindow *dropWindow = [[NFCTestPromiseDropWindow alloc] initWithDestinationDirectory:destinationDirectory];
    XCTAssertTrue([dropWindow isRegisteredForFilePromises]);

    NSError *error = nil;
    XCTAssertTrue([dropWindow acceptPromiseProvider:provider error:&error]);
    XCTAssertNil(error);
    NSURL *created = [destinationDirectory URLByAppendingPathComponent:provider.promisedFileName];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:created.path]);
    XCTAssertEqualObjects(created.pathExtension, provider.template.fileExtension);
    [panel.window orderOut:nil];
}

- (void)testGridFileURLDropsIntoCustomWindow {
    NFCTemplateGridViewController *grid = [[NFCTemplateGridViewController alloc] init];
    [grid view];
    NSCollectionView *collectionView = [grid valueForKey:@"collectionView"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    NSPasteboardItem *item = [grid collectionView:collectionView pasteboardWriterForItemAtIndexPath:indexPath];
    XCTAssertNotNil(item);
    XCTAssertNotNil([item stringForType:NSPasteboardTypeFileURL]);

    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    [pasteboard clearContents];
    XCTAssertTrue([pasteboard writeObjects:@[item]]);

    NSURL *destinationDirectory = [self makeDirectoryNamed:@"Custom File Window"];
    NFCTestFileDropView *dropView = [[NFCTestFileDropView alloc] initWithFrame:NSMakeRect(0, 0, 420, 300)];
    dropView.destinationDirectory = destinationDirectory;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 300)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.contentView = dropView;

    NFCTestDraggingInfo *draggingInfo = [[NFCTestDraggingInfo alloc] init];
    draggingInfo.draggingPasteboard = pasteboard;
    draggingInfo.draggingDestinationWindow = window;
    draggingInfo.draggingSourceOperationMask = NSDragOperationCopy;
    XCTAssertEqual([dropView draggingEntered:draggingInfo], NSDragOperationCopy);
    XCTAssertTrue([dropView prepareForDragOperation:draggingInfo]);
    XCTAssertTrue([dropView performDragOperation:draggingInfo]);
    XCTAssertEqual(dropView.lastReceivedURLs.count, 1u);
    NSURL *created = dropView.lastReceivedURLs.firstObject;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:created.path]);
    NSURL *templateURL = [NSURL URLWithString:[item stringForType:NSPasteboardTypeFileURL]];
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:created], [NSData dataWithContentsOfURL:templateURL]);
    [window orderOut:nil];
}

- (void)testQuickPanelPromiseDropsIntoDesktopStyleFolder {
    NFCQuickPanelController *panel = nil;
    NFFilePromiseProvider *provider = [self firstPromiseFromQuickPanel:&panel];
    NSURL *desktopStyleFolder = [self makeDirectoryNamed:@"Desktop"];
    NSURL *destination = [desktopStyleFolder URLByAppendingPathComponent:provider.promisedFileName];
    __block NSError *writeError = nil;
    [provider filePromiseProvider:provider writePromiseToURL:destination completionHandler:^(NSError * _Nullable error) {
        writeError = error;
    }];
    XCTAssertNil(writeError);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:destination.path]);
    XCTAssertEqualObjects(destination.pathExtension, provider.template.fileExtension);
    [panel.window orderOut:nil];
}

- (void)testRealDesktopDestinationWhenExplicitlyEnabled {
    if (![NSProcessInfo.processInfo.environment[NFCTestRealDesktopEnvironmentKey] isEqualToString:@"1"]) {
        XCTSkip(@"Set %@=1 to exercise the real Desktop folder.", NFCTestRealDesktopEnvironmentKey);
    }
    NSURL *desktop = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject]
                                isDirectory:YES];
    if (![[NSFileManager defaultManager] isWritableFileAtPath:desktop.path]) {
        XCTSkip(@"The Desktop folder is not writable for this test process.");
    }
    NSURL *directory = [desktop URLByAppendingPathComponent:[NSString stringWithFormat:@".nfc-test-%@", NSUUID.UUID.UUIDString]
                                                isDirectory:YES];
    NSError *error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:directory
                                            withIntermediateDirectories:NO
                                                             attributes:nil
                                                                  error:&error], @"%@", error);
    @try {
        NFCQuickPanelController *panel = nil;
        NFFilePromiseProvider *provider = [self firstPromiseFromQuickPanel:&panel];
        NSURL *destination = [directory URLByAppendingPathComponent:provider.promisedFileName];
        __block NSError *writeError = nil;
        [provider filePromiseProvider:provider writePromiseToURL:destination completionHandler:^(NSError * _Nullable completionError) {
            writeError = completionError;
        }];
        XCTAssertNil(writeError);
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:destination.path]);
        [panel.window orderOut:nil];
    } @finally {
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
    }
}

- (void)testExternalVolumeDestinationWhenAvailable {
    NSURL *directory = [self temporaryDirectoryOnExternalVolumeOrSkip];
    @try {
        NFCQuickPanelController *panel = nil;
        NFFilePromiseProvider *provider = [self firstPromiseFromQuickPanel:&panel];
        NSURL *destination = [directory URLByAppendingPathComponent:provider.promisedFileName];
        __block NSError *writeError = nil;
        [provider filePromiseProvider:provider writePromiseToURL:destination completionHandler:^(NSError * _Nullable error) {
            writeError = error;
        }];
        XCTAssertNil(writeError);
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:destination.path]);
        XCTAssertEqualObjects(destination.pathExtension, provider.template.fileExtension);
        [panel.window orderOut:nil];
    } @finally {
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
    }
}

- (void)testQuickPanelDoesNotOfferAMissingTemplateForDragging {
    NFCQuickPanelController *panel = nil;
    NFFilePromiseProvider *provider = [self firstPromiseFromQuickPanel:&panel];
    NSURL *templateURL = [[NFConfigStore sharedStore] templateFileURLForTemplate:provider.template];
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:templateURL error:nil]);

    [panel reloadData];
    NSTableView *tableView = [panel valueForKey:@"tableView"];
    NSArray<NFTemplate *> *templates = [panel valueForKey:@"templates"];
    NSUInteger row = [templates indexOfObjectPassingTest:^BOOL(NFTemplate *candidate, NSUInteger idx, BOOL *stop) {
        return [candidate.identifier isEqualToString:provider.template.identifier];
    }];
    XCTAssertNotEqual(row, NSNotFound);
    id writer = [(id<NSTableViewDataSource>)panel tableView:tableView pasteboardWriterForRow:(NSInteger)row];
    XCTAssertNil(writer);
    [panel.window orderOut:nil];
}

@end

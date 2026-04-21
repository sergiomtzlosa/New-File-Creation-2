#import "NFTestSupport.h"
#import "NFFinderDestination.h"

@interface NFFinderDestinationTests : NFTestCase
@end

@implementation NFFinderDestinationTests

- (void)testTargetedFolderIsUsedForBackgroundMenu {
    NSURL *folder = [self makeDirectoryNamed:@"Current Folder"];
    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:folder
                                                        selectedURLs:nil
                                                   useSelectedItems:NO
                                                         fallbackURL:nil];
    XCTAssertEqualObjects(resolved, folder);
}

- (void)testContextualMenuOnFileUsesContainingFolder {
    NSURL *folder = [self makeDirectoryNamed:@"Project"];
    NSURL *file = [self writeFileNamed:@"notes.txt" contents:@"hello" inDirectory:folder];

    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:file
                                                        selectedURLs:@[file]
                                                   useSelectedItems:YES
                                                         fallbackURL:nil];
    XCTAssertEqualObjects(resolved, folder);
}

- (void)testContextualMenuOnFolderUsesThatFolder {
    NSURL *folder = [self makeDirectoryNamed:@"Selected Folder"];
    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:self.temporaryDirectory
                                                        selectedURLs:@[folder]
                                                   useSelectedItems:YES
                                                         fallbackURL:nil];
    XCTAssertEqualObjects(resolved, folder);
}

- (void)testContextualMenuWithMultipleItemsUsesFirstContainingFolder {
    NSURL *firstFolder = [self makeDirectoryNamed:@"First"];
    NSURL *secondFolder = [self makeDirectoryNamed:@"Second"];
    NSURL *first = [self writeFileNamed:@"one.txt" contents:@"1" inDirectory:firstFolder];
    NSURL *second = [self writeFileNamed:@"two.txt" contents:@"2" inDirectory:secondFolder];

    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:secondFolder
                                                        selectedURLs:@[first, second]
                                                   useSelectedItems:YES
                                                         fallbackURL:nil];
    XCTAssertEqualObjects(resolved, firstFolder);
}

- (void)testToolbarMenuIgnoresSelection {
    NSURL *target = [self makeDirectoryNamed:@"Browsing"];
    NSURL *selectedFolder = [self makeDirectoryNamed:@"Selected"];
    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:target
                                                        selectedURLs:@[selectedFolder]
                                                   useSelectedItems:NO
                                                         fallbackURL:nil];
    XCTAssertEqualObjects(resolved, target);
}

- (void)testMissingTargetFallsBackToDesktop {
    NSURL *desktop = [self makeDirectoryNamed:@"Desktop"];
    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:nil
                                                        selectedURLs:nil
                                                   useSelectedItems:NO
                                                         fallbackURL:desktop];
    XCTAssertEqualObjects(resolved, desktop);
}

- (void)testTargetedFileResolvesToContainingFolder {
    NSURL *folder = [self makeDirectoryNamed:@"Documents"];
    NSURL *file = [self writeFileNamed:@"draft.md" contents:@"draft" inDirectory:folder];

    NSURL *resolved = [NFFinderDestination directoryURLForTargetedURL:file
                                                        selectedURLs:nil
                                                   useSelectedItems:NO
                                                         fallbackURL:nil];
    XCTAssertEqualObjects(resolved, folder);
}

@end

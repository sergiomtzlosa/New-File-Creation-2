#import "NFTestSupport.h"
#import "NFFilePromiseProvider.h"
#import "NFTemplate.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface NFFilePromiseProviderTests : NFTestCase
@end

@implementation NFFilePromiseProviderTests

- (void)testPromisedFileNameUsesDefaultBaseNameAndTemplateExtension {
    NFTemplate *text = [NFTemplate templateWithFileName:@"TextFile.txt"];
    XCTAssertEqualObjects([NFFilePromiseProvider promisedFileNameForTemplate:text defaultBaseName:@"Untitled"], @"Untitled.txt");
    XCTAssertEqualObjects([NFFilePromiseProvider promisedFileNameForTemplate:text defaultBaseName:@"Notes.txt"], @"Notes.txt");
    XCTAssertEqualObjects([NFFilePromiseProvider promisedFileNameForTemplate:text defaultBaseName:@"  My/Note  "], @"My-Note.txt");

    NFTemplate *makefile = [NFTemplate templateWithFileName:@"Makefile"];
    XCTAssertEqualObjects([NFFilePromiseProvider promisedFileNameForTemplate:makefile defaultBaseName:@"Untitled"], @"Untitled");
}

- (void)testProviderUsesTemplateFileTypeAndSelfAsDelegate {
    NSURL *templateURL = [self writeFileNamed:@"TextFile.txt" contents:@"hello" inDirectory:self.temporaryDirectory];
    NFTemplate *template = [NFTemplate templateWithFileName:@"TextFile.txt"];
    NFFilePromiseProvider *provider = [[NFFilePromiseProvider alloc] initWithTemplate:template
                                                                          templateURL:templateURL
                                                                             fileName:@"Untitled.txt"];

    UTType *type = [UTType typeWithIdentifier:provider.fileType];
    XCTAssertNotNil(type);
    XCTAssertTrue([type conformsToType:UTTypeData]);
    XCTAssertEqual(provider.delegate, provider);
    XCTAssertEqualObjects([provider filePromiseProvider:provider fileNameForType:provider.fileType], @"Untitled.txt");
}

- (void)testProviderWritesACopyAndNeverOverwrites {
    NSURL *templateURL = [self writeFileNamed:@"TextFile.txt" contents:@"template contents" inDirectory:self.temporaryDirectory];
    NSURL *destinationDirectory = [self makeDirectoryNamed:@"Drop"];
    NSURL *destination = [destinationDirectory URLByAppendingPathComponent:@"Untitled.txt"];
    NFTemplate *template = [NFTemplate templateWithFileName:@"TextFile.txt"];
    NFFilePromiseProvider *provider = [[NFFilePromiseProvider alloc] initWithTemplate:template
                                                                          templateURL:templateURL
                                                                             fileName:@"Untitled.txt"];

    NSError *error = nil;
    XCTAssertTrue([provider writeToURL:destination error:&error]);
    XCTAssertNil(error);
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:destination encoding:NSUTF8StringEncoding error:nil],
                          @"template contents");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil],
                          @"template contents");

    XCTAssertFalse([provider writeToURL:destination error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:destination encoding:NSUTF8StringEncoding error:nil],
                          @"template contents");
}

- (void)testDirectoryTemplatePromisesAFolder {
    NSURL *templateURL = [self makeDirectoryNamed:@"Package"];
    NFTemplate *template = [NFTemplate templateWithFileName:@"Package"];
    NFFilePromiseProvider *provider = [[NFFilePromiseProvider alloc] initWithTemplate:template
                                                                          templateURL:templateURL
                                                                             fileName:@"Untitled"];
    XCTAssertEqualObjects(provider.fileType, UTTypeFolder.identifier);
}

- (void)testWriteDelegateReportsSuccessAndDestination {
    NSURL *templateURL = [self writeFileNamed:@"TextFile.txt" contents:@"delegate" inDirectory:self.temporaryDirectory];
    NSURL *destinationDirectory = [self makeDirectoryNamed:@"Drop"];
    NSURL *destination = [destinationDirectory URLByAppendingPathComponent:@"Untitled.txt"];
    NFTemplate *template = [NFTemplate templateWithFileName:@"TextFile.txt"];
    NFFilePromiseProvider *provider = [[NFFilePromiseProvider alloc] initWithTemplate:template
                                                                          templateURL:templateURL
                                                                             fileName:@"Untitled.txt"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"didWriteFile"];
    provider.didWriteFile = ^(NSURL *url) {
        XCTAssertEqualObjects(url, destination);
        [expectation fulfill];
    };
    __block NSError *writeError = [NSError errorWithDomain:@"unset" code:1 userInfo:nil];
    [provider filePromiseProvider:provider
                writePromiseToURL:destination
                completionHandler:^(NSError * _Nullable error) {
        writeError = error;
    }];
    XCTAssertNil(writeError);
    [self waitForExpectations:@[expectation] timeout:1.0];
}

@end

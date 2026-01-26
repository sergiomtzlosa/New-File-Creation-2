#import "NFTestSupport.h"
#import "NFRequest.h"
#import "NFErrors.h"

@interface NFRequestTests : NFTestCase
@end

@implementation NFRequestTests

- (void)testCreateRequestRoundTrip {
    NSURL *url = [NFRequest createRequestURLWithTemplateIdentifier:@"template-1"
                                                    directoryPath:@"/tmp/My Folder"
                                                         baseName:@"Draft"
                                                           unique:NO];
    NSError *error = nil;
    NFRequest *request = [NFRequest requestWithURL:url error:&error];
    XCTAssertNotNil(request, @"%@", error);
    XCTAssertEqual(request.kind, NFRequestKindCreate);
    XCTAssertEqualObjects(request.templateIdentifier, @"template-1");
    XCTAssertEqualObjects(request.directoryPath, @"/tmp/My Folder");
    XCTAssertEqualObjects(request.baseName, @"Draft");
    XCTAssertFalse(request.unique);
    XCTAssertTrue(request.revealAfterCreate);
}

- (void)testQuickAndLibraryRequests {
    NSError *error = nil;
    NFRequest *quick = [NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://quick"] error:&error];
    XCTAssertEqual(quick.kind, NFRequestKindQuick);
    XCTAssertTrue([quick.URLRepresentation.absoluteString hasPrefix:@"newfilecreation2://quick"]);

    NFRequest *library = [NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://templates"] error:&error];
    XCTAssertEqual(library.kind, NFRequestKindLibrary);

    NFRequest *settings = [NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://settings"] error:&error];
    XCTAssertEqual(settings.kind, NFRequestKindSettings);
}

- (void)testAddTemplateRequestRoundTrip {
    NSURL *url = [NFRequest addTemplateRequestURLWithPaths:@[@"/tmp/one.txt", @"/tmp/Two Words.swift"]];
    NSError *error = nil;
    NFRequest *request = [NFRequest requestWithURL:url error:&error];
    XCTAssertNotNil(request, @"%@", error);
    XCTAssertEqual(request.kind, NFRequestKindAddTemplate);
    XCTAssertEqualObjects(request.filePaths, (@[@"/tmp/one.txt", @"/tmp/Two Words.swift"]));
}

- (void)testRejectsWrongSchemeAndUnknownHost {
    NSError *error = nil;
    XCTAssertNil([NFRequest requestWithURL:[NSURL URLWithString:@"https://example.com/create?template=x"] error:&error]);
    XCTAssertEqual(error.code, NFErrorRequestInvalid);

    error = nil;
    XCTAssertNil([NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://unknown"] error:&error]);
    XCTAssertEqual(error.code, NFErrorRequestInvalid);
}

- (void)testRejectsCreateWithoutTemplate {
    NSError *error = nil;
    XCTAssertNil([NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://create?name=Untitled"] error:&error]);
    XCTAssertEqual(error.code, NFErrorRequestInvalid);
}

- (void)testRejectsRelativeAndTraversalDirectories {
    NSError *error = nil;
    XCTAssertNil([NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://create?template=x&dir=relative/path"] error:&error]);
    XCTAssertEqual(error.code, NFErrorRequestInvalid);

    error = nil;
    XCTAssertNil([NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://create?template=x&dir=/tmp/../etc"] error:&error]);
    XCTAssertEqual(error.code, NFErrorRequestInvalid);
}

- (void)testDefaultUniqueIsYes {
    NSError *error = nil;
    NFRequest *request = [NFRequest requestWithURL:[NSURL URLWithString:@"newfilecreation2://create?template=x"] error:&error];
    XCTAssertNotNil(request, @"%@", error);
    XCTAssertTrue(request.unique);
}

@end

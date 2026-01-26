#import "NFTestSupport.h"
#import "NFFileCreator.h"
#import "NFTemplate.h"
#import "NFErrors.h"

@interface NFFileCreatorTests : NFTestCase
@property (nonatomic, strong) NSURL *templateURL;
@property (nonatomic, strong) NFTemplate *template;
@property (nonatomic, strong) NSURL *outputDirectory;
@end

@implementation NFFileCreatorTests

- (void)setUp {
    [super setUp];
    NSURL *templates = [self makeDirectoryNamed:@"Templates"];
    self.templateURL = [self writeFileNamed:@"TextFile.txt" contents:@"template contents" inDirectory:templates];
    self.template = [NFTemplate templateWithFileName:@"TextFile.txt"];
    self.outputDirectory = [self makeDirectoryNamed:@"Output"];
}

- (void)testCreatesFileWithDefaultNameAndExtension {
    NSError *error = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                       template:self.template
                                                      directory:self.outputDirectory
                                                       baseName:nil
                                                         unique:YES
                                                          error:&error];
    XCTAssertNotNil(created, @"%@", error);
    XCTAssertEqualObjects(created.lastPathComponent, @"Untitled.txt");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:created encoding:NSUTF8StringEncoding error:nil],
                          @"template contents");
}

- (void)testNeverOverwritesAndAddsNumericSuffix {
    NSError *error = nil;
    NSURL *first = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                     template:self.template
                                                    directory:self.outputDirectory
                                                     baseName:@"Notes"
                                                       unique:YES
                                                        error:&error];
    XCTAssertNotNil(first, @"%@", error);

    NSURL *second = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                      template:self.template
                                                     directory:self.outputDirectory
                                                      baseName:@"Notes"
                                                        unique:YES
                                                         error:&error];
    XCTAssertNotNil(second, @"%@", error);
    XCTAssertEqualObjects(second.lastPathComponent, @"Notes 2.txt");

    XCTAssertEqualObjects([NSString stringWithContentsOfURL:first encoding:NSUTF8StringEncoding error:nil],
                          @"template contents");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:second encoding:NSUTF8StringEncoding error:nil],
                          @"template contents");
}

- (void)testBaseNameWithMatchingExtensionIsNotDoubled {
    NSError *error = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                       template:self.template
                                                      directory:self.outputDirectory
                                                       baseName:@"Already.txt"
                                                         unique:YES
                                                          error:&error];
    XCTAssertNotNil(created, @"%@", error);
    XCTAssertEqualObjects(created.lastPathComponent, @"Already.txt");
}

- (void)testNonUniqueExactDestinationFailsWhenFileExists {
    NSURL *destination = [self.outputDirectory URLByAppendingPathComponent:@"Exact.txt"];
    [@"existing" writeToURL:destination atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSError *error = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                    destination:destination
                                                         unique:NO
                                                          error:&error];
    XCTAssertNil(created);
    XCTAssertEqual(error.code, NFErrorFileExists);
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:destination encoding:NSUTF8StringEncoding error:nil],
                          @"existing");
}

- (void)testUniqueExactDestinationUsesSuffix {
    NSURL *destination = [self.outputDirectory URLByAppendingPathComponent:@"Exact.txt"];
    [@"existing" writeToURL:destination atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSError *error = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                    destination:destination
                                                         unique:YES
                                                          error:&error];
    XCTAssertNotNil(created, @"%@", error);
    XCTAssertEqualObjects(created.lastPathComponent, @"Exact 2.txt");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:destination encoding:NSUTF8StringEncoding error:nil],
                          @"existing");
}

- (void)testMissingTemplateReportsError {
    NSError *error = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:[self.templateURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Missing.txt"]
                                                       template:self.template
                                                      directory:self.outputDirectory
                                                       baseName:@"Notes"
                                                         unique:YES
                                                          error:&error];
    XCTAssertNil(created);
    XCTAssertEqual(error.code, NFErrorTemplateMissing);
}

- (void)testMissingDestinationReportsError {
    NSError *error = nil;
    NSURL *created = [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                                       template:self.template
                                                      directory:[self.temporaryDirectory URLByAppendingPathComponent:@"NoSuchFolder" isDirectory:YES]
                                                       baseName:@"Notes"
                                                         unique:YES
                                                          error:&error];
    XCTAssertNil(created);
    XCTAssertEqual(error.code, NFErrorDestinationInvalid);
}

@end

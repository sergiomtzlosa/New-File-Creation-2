#import "NFTestSupport.h"
#import "NFCCLIOptions.h"
#import "NFCCLIResolver.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFErrors.h"

@interface NFCLITests : NFTestCase
@property (nonatomic, strong) NFConfig *config;
@property (nonatomic, strong) NFTemplate *textTemplate;
@property (nonatomic, strong) NFTemplate *swiftTemplate;
@property (nonatomic, strong) NFTemplate *shellTemplate;
@end

@implementation NFCLITests

- (void)setUp {
    [super setUp];
    self.config = [NFConfig defaultConfig];

    self.textTemplate = [NFTemplate templateWithFileName:@"TextFile.txt"];
    self.textTemplate.identifier = @"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA";
    self.textTemplate.displayName = @"Text File";
    self.textTemplate.sortIndex = 0;

    self.swiftTemplate = [NFTemplate templateWithFileName:@"Snippet.swift"];
    self.swiftTemplate.identifier = @"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB";
    self.swiftTemplate.displayName = @"Swift Snippet";
    self.swiftTemplate.sortIndex = 1;

    self.shellTemplate = [NFTemplate templateWithFileName:@"ShellScript.sh"];
    self.shellTemplate.identifier = @"CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC";
    self.shellTemplate.displayName = @"Shell Script";
    self.shellTemplate.sortIndex = 2;

    [self.config.templates addObjectsFromArray:@[self.textTemplate, self.swiftTemplate, self.shellTemplate]];
}

- (void)testOptionsParseValuesAndFlags {
    NSError *error = nil;
    NFCCLIOptions *options = [NFCCLIOptions parseArguments:@[@"create", @"Text File", @"--dir=/tmp/out", @"--name", @"Draft", @"-jq", @"--json"]
                                               valueOptions:[NSSet setWithObjects:@"dir", @"name", nil]
                                                flagOptions:[NSSet setWithObjects:@"j", @"q", @"json", nil]
                                                      error:&error];
    XCTAssertNotNil(options, @"%@", error);
    XCTAssertEqualObjects(options.positionals, (@[@"create", @"Text File"]));
    XCTAssertEqualObjects([options valueFor:@"dir"], @"/tmp/out");
    XCTAssertEqualObjects([options valueFor:@"name"], @"Draft");
    XCTAssertTrue([options hasFlag:@"j"]);
    XCTAssertTrue([options hasFlag:@"q"]);
    XCTAssertTrue([options hasFlag:@"json"]);
}

- (void)testOptionsDoubleDashStopsParsing {
    NSError *error = nil;
    NFCCLIOptions *options = [NFCCLIOptions parseArguments:@[@"create", @"--", @"--not-an-option"]
                                               valueOptions:[NSSet set]
                                                flagOptions:[NSSet set]
                                                      error:&error];
    XCTAssertNotNil(options, @"%@", error);
    XCTAssertEqualObjects(options.positionals, (@[@"create", @"--not-an-option"]));
}

- (void)testOptionsRejectUnknownAndMissingValues {
    NSError *error = nil;
    XCTAssertNil([NFCCLIOptions parseArguments:@[@"--bogus"] valueOptions:[NSSet set] flagOptions:[NSSet set] error:&error]);
    XCTAssertEqual(error.code, NFErrorCLIUsage);

    error = nil;
    XCTAssertNil([NFCCLIOptions parseArguments:@[@"--dir"] valueOptions:[NSSet setWithObject:@"dir"] flagOptions:[NSSet set] error:&error]);
    XCTAssertEqual(error.code, NFErrorCLIUsage);

    error = nil;
    XCTAssertNil([NFCCLIOptions parseArguments:@[@"--json=1"] valueOptions:[NSSet set] flagOptions:[NSSet setWithObject:@"json"] error:&error]);
    XCTAssertEqual(error.code, NFErrorCLIUsage);
}

- (void)testResolverByIdentifierNameAndNormalizedName {
    NSError *error = nil;
    XCTAssertEqualObjects([NFCCLIResolver resolveReference:self.swiftTemplate.identifier inConfig:self.config error:&error],
                          self.swiftTemplate);
    XCTAssertEqualObjects([NFCCLIResolver resolveReference:@"Text File" inConfig:self.config error:&error],
                          self.textTemplate);
    XCTAssertEqualObjects([NFCCLIResolver resolveReference:@"text-file" inConfig:self.config error:&error],
                          self.textTemplate);
    XCTAssertEqualObjects([NFCCLIResolver resolveReference:@"snippet.swift" inConfig:self.config error:&error],
                          self.swiftTemplate);
}

- (void)testResolverByUniquePrefix {
    NSError *error = nil;
    XCTAssertEqualObjects([NFCCLIResolver resolveReference:@"Shell" inConfig:self.config error:&error],
                          self.shellTemplate);
}

- (void)testResolverRejectsAmbiguousPrefixAndMissingReference {
    NSError *error = nil;
    XCTAssertNil([NFCCLIResolver resolveReference:@"S" inConfig:self.config error:&error]);
    XCTAssertEqual(error.code, NFErrorCLIAmbiguous);

    error = nil;
    XCTAssertNil([NFCCLIResolver resolveReference:@"Nonexistent" inConfig:self.config error:&error]);
    XCTAssertEqual(error.code, NFErrorCLINotFound);
}

- (void)testResolverUsesDefaultTemplateForNilReference {
    [self.config setSetting:self.swiftTemplate.identifier forKey:@"defaultTemplateID"];
    NSError *error = nil;
    XCTAssertEqualObjects([NFCCLIResolver resolveReference:nil inConfig:self.config error:&error], self.swiftTemplate);
}

- (void)testResolverNilReferenceWithoutDefaultIsAmbiguous {
    NSError *error = nil;
    XCTAssertNil([NFCCLIResolver resolveReference:nil inConfig:self.config error:&error]);
    XCTAssertEqual(error.code, NFErrorCLIAmbiguous);
}

@end

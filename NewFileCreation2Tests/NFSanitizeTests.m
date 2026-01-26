#import "NFTestSupport.h"
#import "NFSanitize.h"

@interface NFSanitizeTests : NFTestCase
@end

@implementation NFSanitizeTests

- (void)testSanitizesPathSeparatorsAndControlCharacters {
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:@"  a/b:c\\d  " fallback:@"Untitled"], @"a-b-c-d");
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:@"Line\nBreak" fallback:@"Untitled"], @"LineBreak");
}

- (void)testFallbackAndLeadingCharacters {
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:nil fallback:@"Untitled"], @"Untitled");
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:@"   " fallback:@"Untitled"], @"Untitled");
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:@"..." fallback:@"Untitled"], @"Untitled");
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:@".hidden" fallback:@"Untitled"], @"hidden");
    XCTAssertEqualObjects([NFSanitize sanitizedBaseName:@"-dash" fallback:@"Untitled"], @"File -dash");
}

- (void)testTruncatesLongNames {
    NSString *longName = [@"" stringByPaddingToLength:250 withString:@"a" startingAtIndex:0];
    NSString *sanitized = [NFSanitize sanitizedBaseName:longName fallback:@"Untitled"];
    XCTAssertEqual(sanitized.length, 200);
}

- (void)testFileNameExtensionHandling {
    XCTAssertEqualObjects([NFSanitize fileNameForBaseName:@"Notes" templateFileName:@"TextFile.txt"], @"Notes.txt");
    XCTAssertEqualObjects([NFSanitize fileNameForBaseName:@"Notes.txt" templateFileName:@"TextFile.txt"], @"Notes.txt");
    XCTAssertEqualObjects([NFSanitize fileNameForBaseName:@"Notes.TXT" templateFileName:@"TextFile.txt"], @"Notes.TXT");
    XCTAssertEqualObjects([NFSanitize fileNameForBaseName:@"Notes" templateFileName:@"Makefile"], @"Notes");
}

- (void)testValidFileNames {
    XCTAssertTrue([NFSanitize isValidFileName:@"Untitled.txt"]);
    XCTAssertTrue([NFSanitize isValidFileName:@"a b-c_d.txt"]);
    XCTAssertFalse([NFSanitize isValidFileName:@""]);
    XCTAssertFalse([NFSanitize isValidFileName:@"."]);
    XCTAssertFalse([NFSanitize isValidFileName:@".."]);
    XCTAssertFalse([NFSanitize isValidFileName:@"a/b.txt"]);
    XCTAssertFalse([NFSanitize isValidFileName:@"a:b.txt"]);
    XCTAssertFalse([NFSanitize isValidFileName:@"a\tb.txt"]);

    NSString *tooLong = [@"" stringByPaddingToLength:256 withString:@"a" startingAtIndex:0];
    XCTAssertFalse([NFSanitize isValidFileName:tooLong]);
}

- (void)testUniqueDestinationURL {
    NSURL *directory = [self makeDirectoryNamed:@"out"];
    NSURL *first = [directory URLByAppendingPathComponent:@"Untitled.txt"];
    XCTAssertEqualObjects([NFSanitize uniqueDestinationURLForURL:first].path, first.path);

    [@"a" writeToURL:first atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *second = [NFSanitize uniqueDestinationURLForURL:first];
    XCTAssertEqualObjects(second.lastPathComponent, @"Untitled 2.txt");

    [@"b" writeToURL:second atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *third = [NFSanitize uniqueDestinationURLForURL:first];
    XCTAssertEqualObjects(third.lastPathComponent, @"Untitled 3.txt");
}

- (void)testUniqueDestinationURLWithoutExtension {
    NSURL *directory = [self makeDirectoryNamed:@"out"];
    NSURL *first = [directory URLByAppendingPathComponent:@"Makefile"];
    [@"a" writeToURL:first atomically:YES encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([NFSanitize uniqueDestinationURLForURL:first].lastPathComponent, @"Makefile 2");
}

@end

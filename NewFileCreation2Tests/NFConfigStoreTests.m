#import "NFTestSupport.h"
#import "NFConfigStore.h"
#import "NFConfig.h"
#import "NFTemplate.h"
#import "NFErrors.h"

@interface NFConfigStoreTests : NFTestCase
@property (nonatomic, strong) NSURL *supportDirectory;
@property (nonatomic, strong) NFConfigStore *store;
@end

@implementation NFConfigStoreTests

- (void)setUp {
    [super setUp];
    self.supportDirectory = [self makeDirectoryNamed:@"Support"];
    self.store = [[NFConfigStore alloc] initWithSupportDirectory:self.supportDirectory];
}

- (void)testFirstLoadCreatesAndSeedsConfig {
    NSError *error = nil;
    NFConfig *config = [self.store loadConfigCreatingIfNeeded:YES error:&error];
    XCTAssertNotNil(config, @"%@", error);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.store.configURL.path]);
    XCTAssertGreaterThanOrEqual(config.templates.count, 30);
    XCTAssertTrue([config boolSettingForKey:@"didSeedBundledTemplates" defaultValue:NO]);
    XCTAssertFalse([config stringSettingForKey:@"defaultTemplateID" defaultValue:@""].length == 0);
    XCTAssertEqualObjects([config stringSettingForKey:@"defaultBaseName" defaultValue:@""], NFDefaultBaseName);

    for (NFTemplate *template in config.templates) {
        NSURL *fileURL = [self.store templateFileURLForTemplate:template];
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path], @"Missing seed file %@", fileURL.path);
    }
}

- (void)testUpdatePersistsAndIncrementsRevision {
    NFConfig *initial = [self.store loadConfigCreatingIfNeeded:YES error:nil];
    NSInteger initialRevision = initial.revision;

    NSError *error = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *config, NSError **blockError) {
        [config setSetting:@"Draft" forKey:@"defaultBaseName"];
        return YES;
    } error:&error];
    XCTAssertTrue(updated, @"%@", error);

    NFConfig *reloaded = [self.store loadConfigCreatingIfNeeded:NO error:nil];
    XCTAssertEqual(reloaded.revision, initialRevision + 1);
    XCTAssertEqualObjects([reloaded stringSettingForKey:@"defaultBaseName" defaultValue:@""], @"Draft");
}

- (void)testCancelledUpdateDoesNotWrite {
    NFConfig *initial = [self.store loadConfigCreatingIfNeeded:YES error:nil];
    NSInteger initialRevision = initial.revision;

    NSError *error = nil;
    BOOL updated = [self.store updateConfig:^BOOL(NFConfig *config, NSError **blockError) {
        [config setSetting:@"ShouldNotPersist" forKey:@"defaultBaseName"];
        if (blockError) {
            *blockError = [NSError nf_errorWithCode:NFErrorNameInvalid description:@"cancelled"];
        }
        return NO;
    } error:&error];
    XCTAssertFalse(updated);
    XCTAssertEqual(error.code, NFErrorNameInvalid);

    NFConfig *reloaded = [self.store loadConfigCreatingIfNeeded:NO error:nil];
    XCTAssertEqual(reloaded.revision, initialRevision);
    XCTAssertEqualObjects([reloaded stringSettingForKey:@"defaultBaseName" defaultValue:@""], NFDefaultBaseName);
}

- (void)testReadOnlySnapshotDoesNotCreateConfig {
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.store.configURL.path]);
    NFConfig *snapshot = [self.store readOnlySnapshot];
    XCTAssertNotNil(snapshot);
    XCTAssertEqualObjects([snapshot stringSettingForKey:@"defaultBaseName" defaultValue:@""], NFDefaultBaseName);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.store.configURL.path]);
}

- (void)testCorruptConfigIsQuarantined {
    [@"not json at all" writeToURL:self.store.configURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSError *error = nil;
    NFConfig *config = [self.store loadConfigCreatingIfNeeded:YES error:&error];
    XCTAssertNotNil(config, @"%@", error);
    XCTAssertGreaterThan(config.templates.count, 0);

    NSArray<NSString *> *backups = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:
                                    [self.supportDirectory URLByAppendingPathComponent:@"Backups"].path
                                                                                 error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'config-corrupt-'"];
    XCTAssertEqual([backups filteredArrayUsingPredicate:predicate].count, 1);
}

- (void)testReplaceConfigPreservesSingleTemplate {
    [self.store loadConfigCreatingIfNeeded:YES error:nil];

    NFConfig *replacement = [NFConfig defaultConfig];
    [replacement setSetting:@"Replaced" forKey:@"defaultBaseName"];
    NFTemplate *template = [NFTemplate templateWithFileName:@"Only.swift"];
    template.identifier = @"33333333-3333-3333-3333-333333333333";
    [replacement.templates addObject:template];

    NSError *error = nil;
    XCTAssertTrue([self.store replaceConfig:replacement error:&error], @"%@", error);

    NFConfig *reloaded = [self.store loadConfigCreatingIfNeeded:NO error:nil];
    XCTAssertEqual(reloaded.templates.count, 1);
    XCTAssertEqualObjects(reloaded.templates.firstObject.fileName, @"Only.swift");
    XCTAssertEqualObjects([reloaded stringSettingForKey:@"defaultBaseName" defaultValue:@""], @"Replaced");
}

- (void)testConcurrentUpdatesAreSerialized {
    [self.store loadConfigCreatingIfNeeded:YES error:nil];

    const NSInteger updateCount = 8;
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    for (NSInteger index = 0; index < updateCount; index++) {
        dispatch_group_async(group, queue, ^{
            NFConfigStore *store = [[NFConfigStore alloc] initWithSupportDirectory:self.supportDirectory];
            [store updateConfig:^BOOL(NFConfig *config, NSError **blockError) {
                NSInteger counter = [config integerSettingForKey:@"testCounter" defaultValue:0];
                [config setSetting:@(counter + 1) forKey:@"testCounter"];
                return YES;
            } error:nil];
        });
    }
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

    NFConfig *reloaded = [self.store loadConfigCreatingIfNeeded:NO error:nil];
    XCTAssertEqual([reloaded integerSettingForKey:@"testCounter" defaultValue:0], updateCount);
}

@end

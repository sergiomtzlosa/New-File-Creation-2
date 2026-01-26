#import "NFTestSupport.h"
#import "NFPaths.h"
#import "NFConfigStore.h"

@interface NFTestCase ()
@property (nonatomic, strong, readwrite) NSURL *temporaryDirectory;
@end

@implementation NFTestCase

- (void)setUp {
    [super setUp];
    self.temporaryDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                                        [NSString stringWithFormat:@"nfc-tests-%@", NSUUID.UUID.UUIDString]]
                                          isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.temporaryDirectory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    [NFPaths setSupportDirectoryOverride:self.temporaryDirectory];
    [NFConfigStore resetSharedStore];
}

- (void)tearDown {
    [NFConfigStore resetSharedStore];
    [NFPaths setSupportDirectoryOverride:nil];
    [[NSFileManager defaultManager] removeItemAtURL:self.temporaryDirectory error:nil];
    self.temporaryDirectory = nil;
    [super tearDown];
}

- (NSURL *)makeDirectoryNamed:(NSString *)name {
    NSURL *url = [self.temporaryDirectory URLByAppendingPathComponent:name isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:url
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    return url;
}

- (NSURL *)writeFileNamed:(NSString *)name
                 contents:(NSString *)contents
              inDirectory:(NSURL *)directory {
    NSURL *url = [directory URLByAppendingPathComponent:name isDirectory:NO];
    [contents writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return url;
}

- (NSArray<NSView *> *)allSubviewsOfView:(NSView *)view {
    NSMutableArray<NSView *> *views = [NSMutableArray array];
    if (!view) {
        return views;
    }
    [views addObject:view];
    for (NSView *subview in view.subviews) {
        [views addObjectsFromArray:[self allSubviewsOfView:subview]];
    }
    return views;
}

- (NSView *)firstSubviewOfClass:(Class)viewClass inView:(NSView *)view {
    for (NSView *candidate in [self allSubviewsOfView:view]) {
        if ([candidate isKindOfClass:viewClass]) {
            return candidate;
        }
    }
    return nil;
}

- (NSButton *)buttonWithTitle:(NSString *)title inView:(NSView *)view {
    for (NSView *candidate in [self allSubviewsOfView:view]) {
        if ([candidate isKindOfClass:[NSButton class]] && [((NSButton *)candidate).title isEqualToString:title]) {
            return (NSButton *)candidate;
        }
    }
    return nil;
}

- (NSTextField *)labelWithString:(NSString *)string inView:(NSView *)view {
    for (NSView *candidate in [self allSubviewsOfView:view]) {
        if ([candidate isKindOfClass:[NSTextField class]] && [((NSTextField *)candidate).stringValue isEqualToString:string]) {
            return (NSTextField *)candidate;
        }
    }
    return nil;
}

- (void)spinMainRunLoopForInterval:(NSTimeInterval)interval {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:interval];
    while (deadline.timeIntervalSinceNow > 0) {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

@end

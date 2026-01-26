#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFTestCase : XCTestCase

@property (nonatomic, strong, readonly) NSURL *temporaryDirectory;

- (NSURL *)makeDirectoryNamed:(NSString *)name;
- (NSURL *)writeFileNamed:(NSString *)name
                 contents:(NSString *)contents
              inDirectory:(NSURL *)directory;

/// Recursively collects subviews, including the starting view.
- (NSArray<NSView *> *)allSubviewsOfView:(NSView *)view;
- (nullable NSView *)firstSubviewOfClass:(Class)viewClass inView:(NSView *)view;
- (nullable NSButton *)buttonWithTitle:(NSString *)title inView:(NSView *)view;
- (nullable NSTextField *)labelWithString:(NSString *)string inView:(NSView *)view;

/// Spins the main run loop briefly for AppKit dispatch_async and animation work.
- (void)spinMainRunLoopForInterval:(NSTimeInterval)interval;

@end

NS_ASSUME_NONNULL_END

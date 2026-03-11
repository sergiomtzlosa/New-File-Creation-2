#import <Cocoa/Cocoa.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <NotificationCenter/NotificationCenter.h>

NS_ASSUME_NONNULL_BEGIN

/// Today widget that lists enabled templates and provides file promises, so a
/// row can be dragged to the Desktop or any Finder folder.
@interface NFFTodayViewController : NSViewController <NCWidgetProviding, NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithSupportDirectory:(NSURL *)supportDirectory;

@end

NS_ASSUME_NONNULL_END
#pragma clang diagnostic pop

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCAppDelegate : NSObject <NSApplicationDelegate>

- (void)showQuickPanel:(nullable id)sender;
- (void)showWelcomeFromSettings:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

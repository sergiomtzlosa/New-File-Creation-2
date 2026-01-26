#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCSettingsWindowController : NSWindowController

@property (nonatomic, copy, nullable) void (^onShowWelcome)(void);

- (instancetype)init;
- (void)reloadPanes;

@end

NS_ASSUME_NONNULL_END

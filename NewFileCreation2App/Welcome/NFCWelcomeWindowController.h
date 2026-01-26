#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCWelcomeWindowController : NSWindowController

@property (nonatomic, copy, nullable) void (^onGetStarted)(void);
@property (nonatomic, copy, nullable) void (^onOpenSettings)(void);

@end

NS_ASSUME_NONNULL_END

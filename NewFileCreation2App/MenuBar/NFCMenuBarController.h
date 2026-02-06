#import <Cocoa/Cocoa.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCMenuBarController : NSObject

@property (nonatomic, copy, nullable) void (^onQuickPanel)(void);
/// Toggles the visual quick panel below the status item. The rectangle is in screen coordinates.
@property (nonatomic, copy, nullable) void (^onToggleQuickPanel)(NSRect anchorScreenRect);
@property (nonatomic, copy, nullable) void (^onOpenLibrary)(void);
@property (nonatomic, copy, nullable) void (^onSettings)(void);
@property (nonatomic, copy, nullable) void (^onWelcome)(void);
@property (nonatomic, copy, nullable) void (^onCreateTemplate)(NFTemplate *template);
@property (nonatomic, copy, nullable) void (^onAddTemplate)(void);

@property (nonatomic, assign, getter=isVisible) BOOL visible;

- (void)reloadMenu;

@end

NS_ASSUME_NONNULL_END

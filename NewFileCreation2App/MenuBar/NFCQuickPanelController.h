#import <Cocoa/Cocoa.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCQuickPanelController : NSWindowController

@property (nonatomic, copy, nullable) void (^onCreateTemplate)(NFTemplate *template);

- (void)showPanel;
/// Shows the panel below a rectangle in screen coordinates, such as the status item.
- (void)showPanelAnchoredToRect:(NSRect)screenRect;
- (void)hidePanel;
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END

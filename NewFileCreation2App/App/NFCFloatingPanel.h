#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A panel that floats above normal windows and never becomes the app's main
/// window. New File Creation 2 runs as a menu bar accessory, so every window it
/// presents uses this type instead of a Dock-owned document window.
@interface NFCFloatingPanel : NSPanel

+ (instancetype)floatingPanelWithContentRect:(NSRect)contentRect
                                  styleMask:(NSWindowStyleMask)styleMask;

@end

NS_ASSUME_NONNULL_END

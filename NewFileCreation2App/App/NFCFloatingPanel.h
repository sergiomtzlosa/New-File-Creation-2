#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A panel that floats above normal windows and never becomes the app's main
/// window. New File Creation 2 runs as a menu bar accessory, so every window it
/// presents uses this type instead of a Dock-owned document window.
@interface NFCFloatingPanel : NSPanel

+ (instancetype)floatingPanelWithContentRect:(NSRect)contentRect
                                  styleMask:(NSWindowStyleMask)styleMask;

/// The screen under the pointer. Menu bar panels should open where the user is
/// looking, not necessarily on the screen that owns the key window.
+ (nullable NSScreen *)screenContainingMouse;

/// Centers the panel on the screen under the pointer, keeping it inside the
/// visible frame.
- (void)centerOnActiveScreen;

@end

NS_ASSUME_NONNULL_END

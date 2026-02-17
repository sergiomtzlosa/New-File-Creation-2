#import "NFCFloatingPanel.h"

@implementation NFCFloatingPanel

+ (instancetype)floatingPanelWithContentRect:(NSRect)contentRect
                                   styleMask:(NSWindowStyleMask)styleMask {
    NFCFloatingPanel *panel = [[self alloc] initWithContentRect:contentRect
                                                     styleMask:styleMask
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
    panel.level = NSFloatingWindowLevel;
    panel.floatingPanel = YES;
    panel.hidesOnDeactivate = NO;
    panel.releasedWhenClosed = NO;
    panel.becomesKeyOnlyIfNeeded = NO;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                               NSWindowCollectionBehaviorFullScreenAuxiliary;
    return panel;
}

+ (nullable NSScreen *)screenContainingMouse {
    NSPoint mouse = NSEvent.mouseLocation;
    for (NSScreen *screen in NSScreen.screens) {
        if (NSMouseInRect(mouse, screen.frame, NO)) {
            return screen;
        }
    }
    return NSScreen.screens.firstObject ?: NSScreen.mainScreen;
}

- (void)centerOnActiveScreen {
    NSScreen *screen = [NFCFloatingPanel screenContainingMouse];
    if (!screen) {
        return;
    }
    NSRect visible = screen.visibleFrame;
    NSRect frame = self.frame;
    CGFloat x = NSMidX(visible) - NSWidth(frame) / 2.0;
    CGFloat y = NSMidY(visible) - NSHeight(frame) / 2.0;
    x = MIN(MAX(x, NSMinX(visible)), NSMaxX(visible) - NSWidth(frame));
    y = MIN(MAX(y, NSMinY(visible)), NSMaxY(visible) - NSHeight(frame));
    [self setFrameOrigin:NSMakePoint(x, y)];
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

@end

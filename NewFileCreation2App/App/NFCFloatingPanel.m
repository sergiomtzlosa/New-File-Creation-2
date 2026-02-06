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

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

@end

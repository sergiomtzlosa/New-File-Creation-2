#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCAppDelegate : NSObject <NSApplicationDelegate>

- (void)showQuickPanel:(nullable id)sender;
- (void)showWelcomeFromSettings:(nullable id)sender;

- (void)newFileFromMenu:(nullable id)sender;
- (void)newFileWithPanelFromMenu:(nullable id)sender;
- (void)addTemplatesFromMenu:(nullable id)sender;
- (void)showQuickPanelFromMenu:(nullable id)sender;
- (void)showLibraryFromMenu:(nullable id)sender;
- (void)showSettingsFromMenu:(nullable id)sender;
- (void)toggleSidebarFromMenu:(nullable id)sender;
- (void)toggleInspectorFromMenu:(nullable id)sender;
- (void)focusSearchFromMenu:(nullable id)sender;
- (void)revealSelectedTemplateFromMenu:(nullable id)sender;
- (void)revealTemplatesFromMenu:(nullable id)sender;
- (void)showWelcomeFromMenu:(nullable id)sender;
- (void)showHelpFromMenu:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

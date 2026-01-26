#import <Cocoa/Cocoa.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCMainWindowController : NSWindowController

- (void)reloadAll;
- (void)selectTemplateWithIdentifier:(nullable NSString *)identifier;
- (void)createSelectedTemplate;
- (void)createSelectedTemplateWithPanel;
- (void)showAddTemplatesPanel;
- (void)focusSearch;
- (void)revealSelectedTemplate;
- (BOOL)hasSelectedTemplate;

@end

NS_ASSUME_NONNULL_END

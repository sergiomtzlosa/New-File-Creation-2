#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCToastPresenter : NSObject

+ (void)showMessage:(NSString *)message inWindow:(nullable NSWindow *)window;
+ (void)showMessage:(NSString *)message
           inWindow:(nullable NSWindow *)window
        actionTitle:(nullable NSString *)actionTitle
             action:(nullable void (^)(void))action;

@end

NS_ASSUME_NONNULL_END

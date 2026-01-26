#import <Cocoa/Cocoa.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCInspectorViewController : NSViewController

@property (nonatomic, strong, nullable) NFTemplate *template;

@property (nonatomic, copy, nullable) void (^onCreate)(NFTemplate *template);
@property (nonatomic, copy, nullable) void (^onCreateWithPanel)(NFTemplate *template);
@property (nonatomic, copy, nullable) void (^onChange)(void);

- (void)reloadData;

@end

NS_ASSUME_NONNULL_END

#import <Cocoa/Cocoa.h>
#import "NFCTemplateGridViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCSidebarViewController : NSViewController

@property (nonatomic, copy, nullable) void (^onFilterChanged)(NFCTemplateFilter filter, NSString * _Nullable category);

- (void)reloadData;
- (void)selectAllTemplates;

@end

NS_ASSUME_NONNULL_END

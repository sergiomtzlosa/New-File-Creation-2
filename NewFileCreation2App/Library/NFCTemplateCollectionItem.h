#import <Cocoa/Cocoa.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCTemplateCollectionItem : NSCollectionViewItem

@property (nonatomic, strong, nullable) NFTemplate *template;
@property (nonatomic, copy, nullable) void (^onDoubleClick)(NFTemplate *template);

@end

NS_ASSUME_NONNULL_END

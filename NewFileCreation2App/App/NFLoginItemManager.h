#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFLoginItemManager : NSObject

+ (BOOL)isEnabled;
+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;
+ (NSInteger)status;
+ (NSString *)statusDescription;
+ (void)openLoginItemsSettings;

@end

NS_ASSUME_NONNULL_END

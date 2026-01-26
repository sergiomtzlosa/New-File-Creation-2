#import <Foundation/Foundation.h>
#import "NFConfigStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFLegacyMigration : NSObject

+ (NSArray<NSURL *> *)legacyDirectories;
+ (BOOL)hasLegacyData;
+ (NSDictionary<NSString *, id> *)migrateIntoStore:(NFConfigStore *)store error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

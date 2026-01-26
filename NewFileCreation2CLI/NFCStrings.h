#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCStrings : NSObject

+ (NSString *)generalHelp;
+ (NSString *)helpForCommand:(NSString *)command;
+ (NSString *)usageForCommand:(NSString *)command;
+ (NSString *)versionLine;
+ (NSString *)errorCodeNameForCode:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END

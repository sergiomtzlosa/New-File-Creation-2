#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFSanitize : NSObject

+ (NSString *)sanitizedBaseName:(nullable NSString *)name fallback:(NSString *)fallback;
+ (BOOL)isValidFileName:(NSString *)name;
+ (NSURL *)uniqueDestinationURLForURL:(NSURL *)proposedURL;
+ (NSString *)fileNameForBaseName:(NSString *)baseName templateFileName:(NSString *)templateFileName;

@end

NS_ASSUME_NONNULL_END

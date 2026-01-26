#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCLIInstallController : NSObject

+ (NSString *)helperPath;
+ (NSString *)installPath;
+ (BOOL)isInstalled;
+ (BOOL)install:(NSError **)error;
+ (BOOL)uninstall:(NSError **)error;
+ (BOOL)isInstallDirectoryOnPATH;

@end

NS_ASSUME_NONNULL_END

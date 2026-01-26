#import <Foundation/Foundation.h>
#import "NFConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCCLIResolver : NSObject

/// Resolves a template reference (UUID, name, file name, or unique prefix).
+ (nullable NFTemplate *)resolveReference:(nullable NSString *)reference
                                 inConfig:(NFConfig *)config
                                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

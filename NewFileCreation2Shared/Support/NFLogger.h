#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NFLogLevel) {
    NFLogLevelError = 0,
    NFLogLevelInfo = 1,
    NFLogLevelDebug = 2
};

@interface NFLogger : NSObject

+ (instancetype)sharedLogger;

@property (nonatomic, assign) NFLogLevel level;

- (void)log:(NFLogLevel)level format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
- (void)error:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)info:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)debug:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

- (NSString *)recentLogContentsWithLimit:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END

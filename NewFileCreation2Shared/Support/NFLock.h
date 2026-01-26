#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A small flock(2)-based interprocess lock.
@interface NFLock : NSObject

- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)lockWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (void)unlock;

@property (nonatomic, readonly, getter=isLocked) BOOL locked;

@end

NS_ASSUME_NONNULL_END

#import "NFLock.h"
#import "NFErrors.h"
#import "NFPaths.h"
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>

@interface NFLock () {
    int _fd;
    NSURL *_url;
}
@end

@implementation NFLock

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = [url copy];
        _fd = -1;
    }
    return self;
}

- (void)dealloc {
    [self unlock];
}

- (BOOL)isLocked {
    return _fd >= 0;
}

- (BOOL)lockWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (_fd >= 0) {
        return YES;
    }
    NSError *dirError = nil;
    if (![NFPaths ensureDirectory:_url.URLByDeletingLastPathComponent error:&dirError]) {
        if (error) {
            *error = dirError;
        }
        return NO;
    }

    int fd = open(_url.path.fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC, 0644);
    if (fd < 0) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                   description:[NSString stringWithFormat:@"Could not open the lock file: %s", strerror(errno)]];
        }
        return NO;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(timeout, 0.05)];
    while (YES) {
        if (flock(fd, LOCK_EX | LOCK_NB) == 0) {
            _fd = fd;
            return YES;
        }
        if (errno != EWOULDBLOCK && errno != EAGAIN) {
            close(fd);
            if (error) {
                *error = [NSError nf_errorWithCode:NFErrorConfigWriteFailed
                                       description:[NSString stringWithFormat:@"Could not lock the configuration: %s", strerror(errno)]];
            }
            return NO;
        }
        if ([deadline timeIntervalSinceNow] <= 0) {
            close(fd);
            if (error) {
                *error = [NSError nf_errorWithCode:NFErrorLockTimeout];
            }
            return NO;
        }
        usleep(20 * 1000);
    }
}

- (void)unlock {
    if (_fd >= 0) {
        flock(_fd, LOCK_UN);
        close(_fd);
        _fd = -1;
    }
}

@end

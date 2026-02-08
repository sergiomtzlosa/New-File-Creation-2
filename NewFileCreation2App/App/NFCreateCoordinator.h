#import <Cocoa/Cocoa.h>
#import "NFConfigStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCreateCoordinator : NSObject

+ (instancetype)sharedCoordinator;

@property (nonatomic, readonly) NFConfigStore *store;
/// Override to observe or replace system-sound playback in tests.
@property (nonatomic, copy, nullable) void (^soundPlayer)(NSString *soundName);

- (NSURL *)defaultCreationDirectory;

- (BOOL)createTemplate:(NFTemplate *)template
           inDirectory:(NSURL *)directory
              baseName:(nullable NSString *)baseName
                unique:(BOOL)unique
                 error:(NSError **)error
            createdURL:(NSURL * _Nullable * _Nullable)createdURL;

- (void)createInDefaultLocation:(NFTemplate *)template window:(nullable NSWindow *)window;
- (void)createWithSavePanel:(NFTemplate *)template window:(nullable NSWindow *)window;
- (void)addTemplatesFromURLs:(NSArray<NSURL *> *)urls window:(nullable NSWindow *)window;
- (void)applyPostCreateActionsForURL:(NSURL *)url window:(nullable NSWindow *)window;
- (void)playConfiguredSound;

@end

NS_ASSUME_NONNULL_END

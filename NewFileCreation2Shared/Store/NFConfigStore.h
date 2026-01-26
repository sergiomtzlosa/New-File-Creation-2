#import <Foundation/Foundation.h>
#import "NFConfig.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const NFConfigDidChangeNotification;
FOUNDATION_EXPORT NSString * const NFConfigDistributedChangeNotification;

@interface NFConfigStore : NSObject

@property (nonatomic, readonly) NSURL *supportURL;
@property (nonatomic, readonly) NSURL *configURL;
@property (nonatomic, readonly) NSURL *templatesURL;

+ (instancetype)sharedStore;

/// Test support: releases the shared singleton so the next access follows the
/// current NFPaths support-directory override. Do not call this in app code.
+ (void)resetSharedStore;

- (instancetype)init;
- (instancetype)initWithConfigURL:(NSURL *)configURL;
- (instancetype)initWithSupportDirectory:(NSURL *)supportDirectory NS_DESIGNATED_INITIALIZER;

/// Loads the config. When create is YES, a missing config is created, seeded with
/// bundled templates, and written atomically. Corrupt configs are quarantined.
- (nullable NFConfig *)loadConfigCreatingIfNeeded:(BOOL)create error:(NSError **)error;

/// Never writes. Returns an in-memory default config when the file is missing or corrupt.
- (NFConfig *)readOnlySnapshot;

/// Serialized read-modify-write. The block receives the latest config while the
/// interprocess lock is held. Return NO from the block to abort.
- (BOOL)updateConfig:(BOOL (^)(NFConfig *config, NSError **error))block error:(NSError **)error;

/// Replaces the whole config (import/migration). Increments the revision.
- (BOOL)replaceConfig:(NFConfig *)config error:(NSError **)error;

- (NSURL *)templateFileURLForTemplate:(NFTemplate *)template;

@end

NS_ASSUME_NONNULL_END

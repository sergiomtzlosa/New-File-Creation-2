#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFPaths : NSObject

/// ~/Library/Application Support/New File Creation 2, or the NFC_SUPPORT_DIR override.
+ (NSURL *)supportDirectoryURL;
+ (void)setSupportDirectoryOverride:(nullable NSURL *)url;

+ (NSURL *)configFileURL;
+ (NSURL *)templatesDirectoryURL;
+ (NSURL *)backupsDirectoryURL;
+ (NSURL *)logsDirectoryURL;
+ (NSURL *)lockFileURL;
+ (NSURL *)logFileURL;

/// Templates shipped inside the app bundle or next to the CLI helper.
+ (nullable NSURL *)bundledTemplatesDirectoryURL;

+ (BOOL)ensureSupportDirectories:(NSError **)error;
+ (BOOL)ensureDirectory:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

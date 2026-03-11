#import <Foundation/Foundation.h>
#import "NFConfig.h"
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

/// Reads the shared configuration for the Today widget.
///
/// The widget runs in its own sandbox and cannot use NFConfigStore because the
/// store creates directories and locks files. This source performs read-only
/// parsing of the real user configuration and returns enabled templates in the
/// persisted display order.
@interface NFTodayTemplateSource : NSObject

@property (nonatomic, strong, readonly) NSURL *supportDirectory;

/// Resolves ~/Library/Application Support/New File Creation 2 for the current
/// user even when called from a sandboxed extension.
+ (NSURL *)defaultSupportDirectory;

- (instancetype)init;
- (instancetype)initWithSupportDirectory:(NSURL *)supportDirectory NS_DESIGNATED_INITIALIZER;

/// Reads the configuration from disk. Returns an empty array when the config is
/// missing or damaged; the widget shows its empty state instead of writing.
- (NSArray<NFTemplate *> *)reloadTemplates;

/// Last loaded enabled templates, in display order.
@property (nonatomic, copy, readonly) NSArray<NFTemplate *> *templates;

- (NSString *)defaultBaseName;
- (NSURL *)templateURLForTemplate:(NFTemplate *)template;

@end

NS_ASSUME_NONNULL_END

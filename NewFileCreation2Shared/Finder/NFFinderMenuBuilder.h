#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "NFConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NFFinderMenuOptions) {
    NFFinderMenuOptionNone = 0,
    NFFinderMenuOptionFavoritesFirst = 1 << 0,
    NFFinderMenuOptionGroupByCategory = 1 << 1,
    NFFinderMenuOptionShowIcons = 1 << 2
};

@interface NFFinderMenuBuilder : NSObject

/// Builds the New File menu. Template items carry a 1-based tag in addition to
/// their representedObject so Finder Sync can resolve the template after the
/// action crosses the extension's XPC boundary, where representedObject is
/// discarded but integer menu-item properties survive.
+ (NSMenu *)menuForConfig:(NFConfig *)config
                   target:(nullable id)target
                   action:(SEL)action
                  options:(NFFinderMenuOptions)options;

+ (NSArray<NFTemplate *> *)orderedTemplatesForConfig:(NFConfig *)config
                                      favoritesFirst:(BOOL)favoritesFirst;

+ (NSArray<NFTemplate *> *)orderedTemplatesForConfig:(NFConfig *)config
                                      favoritesFirst:(BOOL)favoritesFirst
                                            sortMode:(NFTemplateSortMode)sortMode;

/// Reads the persisted `sortMode` setting (manual by default).
+ (NFTemplateSortMode)sortModeForConfig:(NFConfig *)config;

+ (NSComparisonResult)compareTemplate:(NFTemplate *)a
                             toTemplate:(NFTemplate *)b
                               sortMode:(NFTemplateSortMode)sortMode;

+ (NSImage *)iconForTemplate:(NFTemplate *)template;

@end

NS_ASSUME_NONNULL_END

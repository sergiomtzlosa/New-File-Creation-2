#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolves the folder where a Finder extension request should create a file.
/// Kept free of FinderSync types so the same rules can be tested in the app's
/// unit-test bundle.
@interface NFFinderDestination : NSObject

/// @param targetedURL The folder (or item) Finder reports for the menu.
/// @param selectedURLs The current Finder selection.
/// @param useSelectedItems YES for contextual menus on items, NO for background
///        and toolbar menus.
/// @param fallbackURL Used when Finder reports no target, typically Desktop.
+ (nullable NSURL *)directoryURLForTargetedURL:(nullable NSURL *)targetedURL
                                  selectedURLs:(nullable NSArray<NSURL *> *)selectedURLs
                             useSelectedItems:(BOOL)useSelectedItems
                                   fallbackURL:(nullable NSURL *)fallbackURL;

+ (BOOL)isDirectoryURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END

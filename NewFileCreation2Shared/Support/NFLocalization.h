#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Looks up an English string key in the main bundle's Localizable table.
/// Spanish resources map English keys to Spanish values, which keeps call sites readable.
FOUNDATION_EXPORT NSString * NFLocalizedString(NSString *key);
FOUNDATION_EXPORT NSString * NFLocalizedStringDefault(NSString *key, NSString *fallback);

NS_ASSUME_NONNULL_END

#import "NFLocalization.h"

NSString * NFLocalizedString(NSString *key) {
    return NFLocalizedStringDefault(key, key);
}

NSString * NFLocalizedStringDefault(NSString *key, NSString *fallback) {
    NSString *localized = [[NSBundle mainBundle] localizedStringForKey:key value:nil table:@"Localizable"];
    if (localized.length == 0 || [localized isEqualToString:key]) {
        return fallback;
    }
    return localized;
}

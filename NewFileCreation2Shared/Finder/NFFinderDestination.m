#import "NFFinderDestination.h"

@implementation NFFinderDestination

+ (BOOL)isDirectoryURL:(NSURL *)url {
    NSNumber *isDirectory = nil;
    if ([url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil]) {
        return isDirectory.boolValue;
    }
    return url.hasDirectoryPath;
}

+ (nullable NSURL *)directoryURLForTargetedURL:(nullable NSURL *)targetedURL
                                  selectedURLs:(nullable NSArray<NSURL *> *)selectedURLs
                             useSelectedItems:(BOOL)useSelectedItems
                                   fallbackURL:(nullable NSURL *)fallbackURL {
    NSURL *candidate = targetedURL;
    NSArray<NSURL *> *selected = selectedURLs ?: @[];

    if (useSelectedItems && selected.count > 0) {
        if (selected.count == 1) {
            NSURL *item = selected.firstObject;
            candidate = [self isDirectoryURL:item] ? item : item.URLByDeletingLastPathComponent;
        } else {
            candidate = selected.firstObject.URLByDeletingLastPathComponent;
        }
    }

    if (!candidate) {
        candidate = fallbackURL;
    }
    if (!candidate) {
        return nil;
    }
    if (![self isDirectoryURL:candidate]) {
        candidate = candidate.URLByDeletingLastPathComponent;
    }
    return candidate;
}

@end

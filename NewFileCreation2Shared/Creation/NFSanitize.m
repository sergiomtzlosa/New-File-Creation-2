#import "NFSanitize.h"

static const NSUInteger NFMaxBaseNameLength = 200;

@implementation NFSanitize

+ (NSString *)sanitizedBaseName:(NSString *)name fallback:(NSString *)fallback {
    NSString *value = name ?: @"";
    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    value = [value stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    value = [value stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    value = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"-"];

    NSMutableString *cleaned = [NSMutableString stringWithCapacity:value.length];
    [value enumerateSubstringsInRange:NSMakeRange(0, value.length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        unichar character = [substring characterAtIndex:0];
        if ([substring rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location == NSNotFound &&
            character != 0) {
            [cleaned appendString:substring];
        }
    }];

    while ([cleaned hasPrefix:@"."]) {
        [cleaned deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    [cleaned replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, cleaned.length)];
    [cleaned replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, cleaned.length)];
    [cleaned replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, cleaned.length)];

    NSString *result = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (result.length > NFMaxBaseNameLength) {
        result = [result substringToIndex:NFMaxBaseNameLength];
        result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    if (result.length == 0) {
        result = fallback.length > 0 ? fallback : @"Untitled";
    }
    if (result.length > 0) {
        unichar first = [result characterAtIndex:0];
        if (first == '.' || first == '-') {
            result = [@"File " stringByAppendingString:result];
        }
    }
    return result;
}

+ (BOOL)isValidFileName:(NSString *)name {
    if (name.length == 0 || name.length > 255) {
        return NO;
    }
    if ([name isEqualToString:@"."] || [name isEqualToString:@".."]) {
        return NO;
    }
    if ([name containsString:@"/"] || [name containsString:@":"]) {
        return NO;
    }
    if ([name rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
        return NO;
    }
    return YES;
}

+ (NSURL *)uniqueDestinationURLForURL:(NSURL *)proposedURL {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:proposedURL.path]) {
        return proposedURL;
    }
    NSString *extension = proposedURL.pathExtension;
    NSURL *directory = proposedURL.URLByDeletingLastPathComponent;
    NSString *base = proposedURL.lastPathComponent.stringByDeletingPathExtension;
    if (base.length == 0) {
        base = proposedURL.lastPathComponent;
    }
    for (NSUInteger index = 2; index < 10000; index++) {
        NSString *candidateName = extension.length > 0
            ? [NSString stringWithFormat:@"%@ %lu.%@", base, (unsigned long)index, extension]
            : [NSString stringWithFormat:@"%@ %lu", base, (unsigned long)index];
        NSURL *candidate = [directory URLByAppendingPathComponent:candidateName];
        if (![fm fileExistsAtPath:candidate.path]) {
            return candidate;
        }
    }
    return proposedURL;
}

+ (NSString *)fileNameForBaseName:(NSString *)baseName templateFileName:(NSString *)templateFileName {
    NSString *extension = templateFileName.pathExtension ?: @"";
    NSString *name = baseName ?: @"";
    if (extension.length == 0) {
        return name;
    }
    if ([name.lowercaseString hasSuffix:[@"." stringByAppendingString:extension.lowercaseString]]) {
        return name;
    }
    return [NSString stringWithFormat:@"%@.%@", name, extension];
}

@end

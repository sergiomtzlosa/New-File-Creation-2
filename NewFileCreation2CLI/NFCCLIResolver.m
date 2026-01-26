#import "NFCCLIResolver.h"
#import "NFErrors.h"

static NSString *NFNormalizedReference(NSString *value) {
    NSMutableString *normalized = [NSMutableString string];
    NSString *lower = value.lowercaseString;
    for (NSUInteger index = 0; index < lower.length; index++) {
        unichar character = [lower characterAtIndex:index];
        if ((character >= 'a' && character <= 'z') || (character >= '0' && character <= '9')) {
            [normalized appendFormat:@"%C", character];
        }
    }
    return normalized;
}

@implementation NFCCLIResolver

+ (NSArray<NSString *> *)namesForTemplate:(NFTemplate *)template {
    NSMutableArray *names = [NSMutableArray array];
    if (template.resolvedDisplayName.length > 0) {
        [names addObject:template.resolvedDisplayName];
    }
    if (template.fileName.length > 0) {
        [names addObject:template.fileName];
        NSString *withoutExtension = template.fileName.stringByDeletingPathExtension;
        if (withoutExtension.length > 0 && ![withoutExtension isEqualToString:template.fileName]) {
            [names addObject:withoutExtension];
        }
    }
    return names;
}

+ (NFTemplate *)resolveReference:(NSString *)reference inConfig:(NFConfig *)config error:(NSError **)error {
    if (reference.length == 0) {
        NSString *defaultID = [config stringSettingForKey:@"defaultTemplateID" defaultValue:@""];
        if (defaultID.length > 0) {
            NFTemplate *template = [config templateWithIdentifier:defaultID];
            if (template) {
                return template;
            }
        }
        if (config.templates.count == 1) {
            return config.templates.firstObject;
        }
        if (config.templates.count == 0) {
            if (error) {
                *error = [NSError nf_errorWithCode:NFErrorCLINotFound
                                       description:@"There are no templates. Use “nfc add <file>” to create one."];
            }
            return nil;
        }
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorCLIAmbiguous
                                   description:@"Multiple templates exist. Specify a template ID, name, or file name."];
        }
        return nil;
    }

    NFTemplate *exactID = [config templateWithIdentifier:reference];
    if (exactID) {
        return exactID;
    }

    NSMutableArray<NFTemplate *> *exactNameMatches = [NSMutableArray array];
    NSMutableArray<NFTemplate *> *prefixMatches = [NSMutableArray array];
    NSString *lowercaseReference = reference.lowercaseString;
    NSString *normalizedReference = NFNormalizedReference(reference);
    for (NFTemplate *template in config.templates) {
        BOOL exact = NO;
        for (NSString *name in [self namesForTemplate:template]) {
            if ([name.lowercaseString isEqualToString:lowercaseReference] ||
                (normalizedReference.length > 0 && [NFNormalizedReference(name) isEqualToString:normalizedReference])) {
                exact = YES;
                break;
            }
        }
        if (exact) {
            [exactNameMatches addObject:template];
            continue;
        }
        for (NSString *name in [self namesForTemplate:template]) {
            if ([name.lowercaseString hasPrefix:lowercaseReference]) {
                [prefixMatches addObject:template];
                break;
            }
        }
    }

    if (exactNameMatches.count == 1) {
        return exactNameMatches.firstObject;
    }
    if (exactNameMatches.count > 1) {
        if (error) {
            NSArray *names = [exactNameMatches valueForKey:@"resolvedDisplayName"];
            *error = [NSError nf_errorWithCode:NFErrorCLIAmbiguous
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Multiple templates match “%@”: %@.", reference, [names componentsJoinedByString:@", "]],
                                              @"suggestions": names}];
        }
        return nil;
    }
    if (prefixMatches.count == 1) {
        return prefixMatches.firstObject;
    }
    if (prefixMatches.count > 1) {
        if (error) {
            NSArray *names = [prefixMatches valueForKey:@"resolvedDisplayName"];
            *error = [NSError nf_errorWithCode:NFErrorCLIAmbiguous
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Multiple templates match “%@”: %@.", reference, [names componentsJoinedByString:@", "]],
                                              @"suggestions": names}];
        }
        return nil;
    }

    NSMutableArray<NSString *> *allNames = [NSMutableArray array];
    for (NFTemplate *template in config.templates) {
        [allNames addObject:template.resolvedDisplayName];
    }
    if (error) {
        *error = [NSError nf_errorWithCode:NFErrorCLINotFound
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No template matches “%@”.", reference],
                                          @"suggestions": allNames}];
    }
    return nil;
}

@end

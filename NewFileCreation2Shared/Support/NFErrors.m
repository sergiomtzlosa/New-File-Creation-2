#import "NFErrors.h"

NSString * const NFErrorDomain = @"com.sid.newfilecreation2.error";

static NSString *NFDefaultDescriptionForCode(NFErrorCode code) {
    switch (code) {
        case NFErrorTemplateMissing:
            return @"The template could not be found.";
        case NFErrorTemplateUnreadable:
            return @"The template could not be read.";
        case NFErrorDestinationInvalid:
            return @"The destination folder is invalid.";
        case NFErrorDestinationNotWritable:
            return @"The destination folder is not writable.";
        case NFErrorNameInvalid:
            return @"The file name is not valid.";
        case NFErrorFileExists:
            return @"A file with that name already exists.";
        case NFErrorConfigCorrupt:
            return @"The configuration file is damaged.";
        case NFErrorConfigWriteFailed:
            return @"The configuration could not be saved.";
        case NFErrorRequestInvalid:
            return @"The request is not valid.";
        case NFErrorLockTimeout:
            return @"Another process is using the configuration. Try again.";
        case NFErrorMigrationFailed:
            return @"The legacy data could not be imported.";
        case NFErrorCLIUsage:
            return @"Invalid command-line usage.";
        case NFErrorCLINotFound:
            return @"The requested template was not found.";
        case NFErrorCLIAmbiguous:
            return @"The template reference is ambiguous.";
        case NFErrorUnsupportedSchema:
            return @"The configuration was created by a newer version.";
        case NFErrorUnknown:
        default:
            return @"An unexpected error occurred.";
    }
}

@implementation NSError (NFErrors)

+ (instancetype)nf_errorWithCode:(NFErrorCode)code {
    return [self nf_errorWithCode:code userInfo:nil];
}

+ (instancetype)nf_errorWithCode:(NFErrorCode)code
                        userInfo:(NSDictionary<NSErrorUserInfoKey, id> *)userInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = NFDefaultDescriptionForCode(code);
    if (userInfo.count > 0) {
        [info addEntriesFromDictionary:userInfo];
    }
    return [NSError errorWithDomain:NFErrorDomain code:code userInfo:info];
}

+ (instancetype)nf_errorWithCode:(NFErrorCode)code
                     description:(NSString *)description {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = description.length > 0 ? description : NFDefaultDescriptionForCode(code);
    return [NSError errorWithDomain:NFErrorDomain code:code userInfo:info];
}

@end

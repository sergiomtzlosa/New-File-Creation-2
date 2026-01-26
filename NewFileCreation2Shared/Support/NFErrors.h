#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const NFErrorDomain;

typedef NS_ENUM(NSInteger, NFErrorCode) {
    NFErrorUnknown = 0,
    NFErrorTemplateMissing = 1,
    NFErrorTemplateUnreadable = 2,
    NFErrorDestinationInvalid = 3,
    NFErrorDestinationNotWritable = 4,
    NFErrorNameInvalid = 5,
    NFErrorFileExists = 6,
    NFErrorConfigCorrupt = 7,
    NFErrorConfigWriteFailed = 8,
    NFErrorRequestInvalid = 9,
    NFErrorLockTimeout = 10,
    NFErrorMigrationFailed = 11,
    NFErrorCLIUsage = 12,
    NFErrorCLINotFound = 13,
    NFErrorCLIAmbiguous = 14,
    NFErrorUnsupportedSchema = 15
};

@interface NSError (NFErrors)

+ (instancetype)nf_errorWithCode:(NFErrorCode)code;
+ (instancetype)nf_errorWithCode:(NFErrorCode)code
                        userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
+ (instancetype)nf_errorWithCode:(NFErrorCode)code
                     description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END

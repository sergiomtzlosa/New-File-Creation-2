#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NFRequestKind) {
    NFRequestKindUnknown = 0,
    NFRequestKindCreate,
    NFRequestKindQuick,
    NFRequestKindLibrary,
    NFRequestKindSettings,
    NFRequestKindAddTemplate
};

FOUNDATION_EXPORT NSString * const NFURLScheme;

@interface NFRequest : NSObject

@property (nonatomic, assign) NFRequestKind kind;
@property (nonatomic, copy, nullable) NSString *templateIdentifier;
@property (nonatomic, copy, nullable) NSString *directoryPath;
@property (nonatomic, copy, nullable) NSString *baseName;
@property (nonatomic, assign) BOOL unique;
@property (nonatomic, assign) BOOL openAfterCreate;
@property (nonatomic, assign) BOOL revealAfterCreate;
@property (nonatomic, copy) NSArray<NSString *> *filePaths;

+ (nullable instancetype)requestWithURL:(NSURL *)url error:(NSError **)error;
- (NSURL *)URLRepresentation;

+ (NSURL *)createRequestURLWithTemplateIdentifier:(NSString *)identifier
                                    directoryPath:(nullable NSString *)directoryPath
                                         baseName:(nullable NSString *)baseName
                                           unique:(BOOL)unique;
+ (NSURL *)addTemplateRequestURLWithPaths:(NSArray<NSString *> *)paths;

@end

NS_ASSUME_NONNULL_END

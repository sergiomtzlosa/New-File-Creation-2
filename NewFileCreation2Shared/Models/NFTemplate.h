#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const NFDefaultBaseName;
FOUNDATION_EXPORT NSString * const NFDefaultCategoryOther;

@interface NFTemplate : NSObject <NSCopying>

@property (nonatomic, copy) NSString *identifier;
/// File name relative to the Templates directory.
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, getter=isFavorite) BOOL favorite;
@property (nonatomic, assign) NSInteger sortIndex;
@property (nonatomic, copy, nullable) NSDate *createdAt;
@property (nonatomic, copy, nullable) NSDate *lastUsedAt;
@property (nonatomic, assign) NSInteger useCount;
/// "included" or "user".
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy, nullable) NSString *notes;

@property (nonatomic, readonly) NSString *fileExtension;
@property (nonatomic, readonly) NSString *resolvedDisplayName;

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

+ (instancetype)templateWithFileName:(NSString *)fileName;
+ (NSString *)inferCategoryForFileExtension:(NSString *)fileExtension;
+ (NSString *)displayNameForFileName:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END

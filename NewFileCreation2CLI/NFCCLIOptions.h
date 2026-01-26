#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCCLIOptions : NSObject

@property (nonatomic, copy, readonly) NSArray<NSString *> *positionals;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *values;
@property (nonatomic, copy, readonly) NSSet<NSString *> *flags;

+ (instancetype)parseArguments:(NSArray<NSString *> *)arguments
                  valueOptions:(NSSet<NSString *> *)valueOptions
                   flagOptions:(NSSet<NSString *> *)flagOptions
                         error:(NSError **)error;

- (BOOL)hasFlag:(NSString *)name;
- (nullable NSString *)valueFor:(NSString *)name;

@end

NS_ASSUME_NONNULL_END

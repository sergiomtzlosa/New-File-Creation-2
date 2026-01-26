#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCCLIOutput : NSObject

@property (nonatomic, assign) BOOL json;
@property (nonatomic, assign) BOOL quiet;
@property (nonatomic, assign) BOOL plain;

- (void)line:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)errorLine:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)tableWithHeaders:(NSArray<NSString *> *)headers rows:(NSArray<NSArray<NSString *> *> *)rows;

- (void)jsonSuccessWithCommand:(NSString *)command data:(id)data;
- (void)jsonFailureWithCommand:(NSString *)command error:(NSError *)error exitCode:(int)exitCode;

@end

NS_ASSUME_NONNULL_END

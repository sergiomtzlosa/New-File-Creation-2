#import "NFCCLIOptions.h"
#import "NFErrors.h"

@interface NFCCLIOptions ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *positionals;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *values;
@property (nonatomic, copy, readwrite) NSSet<NSString *> *flags;
@end

@implementation NFCCLIOptions

+ (instancetype)parseArguments:(NSArray<NSString *> *)arguments
                  valueOptions:(NSSet<NSString *> *)valueOptions
                   flagOptions:(NSSet<NSString *> *)flagOptions
                         error:(NSError **)error {
    NSMutableArray<NSString *> *positionals = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *flags = [NSMutableSet set];
    BOOL literal = NO;

    for (NSUInteger index = 0; index < arguments.count; index++) {
        NSString *argument = arguments[index];
        if (literal) {
            [positionals addObject:argument];
            continue;
        }
        if ([argument isEqualToString:@"--"]) {
            literal = YES;
            continue;
        }
        if (![argument hasPrefix:@"-"]) {
            [positionals addObject:argument];
            continue;
        }

        if ([argument hasPrefix:@"--"]) {
            NSString *body = [argument substringFromIndex:2];
            NSString *key = body;
            NSString *inlineValue = nil;
            NSRange equals = [body rangeOfString:@"="];
            if (equals.location != NSNotFound) {
                key = [body substringToIndex:equals.location];
                inlineValue = [body substringFromIndex:equals.location + 1];
            }
            if ([valueOptions containsObject:key]) {
                if (inlineValue != nil) {
                    values[key] = inlineValue;
                    continue;
                }
                if (index + 1 >= arguments.count) {
                    if (error) {
                        *error = [NSError nf_errorWithCode:NFErrorCLIUsage
                                               description:[NSString stringWithFormat:@"--%@ requires a value.", key]];
                    }
                    return nil;
                }
                values[key] = arguments[++index];
                continue;
            }
            if ([flagOptions containsObject:key]) {
                if (inlineValue != nil) {
                    if (error) {
                        *error = [NSError nf_errorWithCode:NFErrorCLIUsage
                                               description:[NSString stringWithFormat:@"--%@ does not take a value.", key]];
                    }
                    return nil;
                }
                [flags addObject:key];
                continue;
            }
            if (error) {
                *error = [NSError nf_errorWithCode:NFErrorCLIUsage
                                       description:[NSString stringWithFormat:@"Unknown option --%@.", key]];
            }
            return nil;
        }

        NSString *body = [argument substringFromIndex:1];
        if ([valueOptions containsObject:body]) {
            if (index + 1 >= arguments.count) {
                if (error) {
                    *error = [NSError nf_errorWithCode:NFErrorCLIUsage
                                           description:[NSString stringWithFormat:@"-%@ requires a value.", body]];
                }
                return nil;
            }
            values[body] = arguments[++index];
            continue;
        }
        if ([flagOptions containsObject:body]) {
            [flags addObject:body];
            continue;
        }

        if (body.length > 1) {
            BOOL validCombined = YES;
            for (NSUInteger charIndex = 0; charIndex < body.length; charIndex++) {
                NSString *shortFlag = [body substringWithRange:NSMakeRange(charIndex, 1)];
                if (![flagOptions containsObject:shortFlag]) {
                    validCombined = NO;
                    break;
                }
            }
            if (validCombined) {
                for (NSUInteger charIndex = 0; charIndex < body.length; charIndex++) {
                    [flags addObject:[body substringWithRange:NSMakeRange(charIndex, 1)]];
                }
                continue;
            }
        }

        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorCLIUsage
                                   description:[NSString stringWithFormat:@"Unknown option -%@.", body]];
        }
        return nil;
    }

    NFCCLIOptions *options = [[self alloc] init];
    options.positionals = positionals;
    options.values = values;
    options.flags = flags;
    return options;
}

- (BOOL)hasFlag:(NSString *)name {
    return [self.flags containsObject:name];
}

- (NSString *)valueFor:(NSString *)name {
    return self.values[name];
}

@end

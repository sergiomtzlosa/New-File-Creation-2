#import "NFCCLIOutput.h"
#import "NFCStrings.h"

@implementation NFCCLIOutput

- (void)line:(NSString *)format, ... {
    if (self.json) {
        return;
    }
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fputs(message.UTF8String, stdout);
    fputc('\n', stdout);
}

- (void)errorLine:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fputs(message.UTF8String, stderr);
    fputc('\n', stderr);
}

- (void)tableWithHeaders:(NSArray<NSString *> *)headers rows:(NSArray<NSArray<NSString *> *> *)rows {
    if (self.json) {
        return;
    }
    NSMutableArray<NSArray<NSString *> *> *allRows = [NSMutableArray arrayWithObject:headers];
    [allRows addObjectsFromArray:rows];
    NSUInteger columnCount = headers.count;
    NSMutableArray<NSNumber *> *widths = [NSMutableArray arrayWithCapacity:columnCount];
    for (NSUInteger column = 0; column < columnCount; column++) {
        NSUInteger width = 0;
        for (NSArray<NSString *> *row in allRows) {
            if (column < row.count) {
                width = MAX(width, row[column].length);
            }
        }
        [widths addObject:@(width)];
    }

    for (NSUInteger rowIndex = 0; rowIndex < allRows.count; rowIndex++) {
        NSArray<NSString *> *row = allRows[rowIndex];
        NSMutableString *line = [NSMutableString string];
        for (NSUInteger column = 0; column < columnCount; column++) {
            NSString *value = column < row.count ? row[column] : @"";
            [line appendString:value];
            if (column + 1 < columnCount) {
                NSUInteger padding = widths[column].unsignedIntegerValue - value.length + 2;
                [line appendString:[@"" stringByPaddingToLength:padding withString:@" " startingAtIndex:0]];
            }
        }
        if (!self.plain) {
            [line appendString:rowIndex == 0 ? @"" : @""];
        }
        fputs(line.UTF8String, stdout);
        fputc('\n', stdout);
        if (rowIndex == 0) {
            NSMutableString *separator = [NSMutableString string];
            for (NSUInteger column = 0; column < columnCount; column++) {
                [separator appendString:[@"" stringByPaddingToLength:widths[column].unsignedIntegerValue withString:@"-" startingAtIndex:0]];
                if (column + 1 < columnCount) {
                    [separator appendString:@"  "];
                }
            }
            fputs(separator.UTF8String, stdout);
            fputc('\n', stdout);
        }
    }
}

- (void)jsonSuccessWithCommand:(NSString *)command data:(id)data {
    NSDictionary *envelope = @{@"ok": @YES, @"command": command ?: @"", @"data": data ?: [NSNull null]};
    [self writeJSONObject:envelope];
}

- (void)jsonFailureWithCommand:(NSString *)command error:(NSError *)error exitCode:(int)exitCode {
    NSMutableArray *suggestions = [NSMutableArray array];
    id rawSuggestions = error.userInfo[@"suggestions"];
    if ([rawSuggestions isKindOfClass:[NSArray class]]) {
        for (id value in rawSuggestions) {
            if ([value isKindOfClass:[NSString class]]) {
                [suggestions addObject:value];
            }
        }
    }
    NSMutableDictionary *errorDict = [NSMutableDictionary dictionary];
    errorDict[@"code"] = [NFCStrings errorCodeNameForCode:error.code];
    errorDict[@"message"] = error.localizedDescription ?: @"An error occurred.";
    errorDict[@"exitCode"] = @(exitCode);
    if (suggestions.count > 0) {
        errorDict[@"suggestions"] = suggestions;
    }
    NSDictionary *envelope = @{@"ok": @NO, @"command": command ?: @"", @"error": errorDict};
    [self writeJSONObject:envelope];
}

- (void)writeJSONObject:(id)object {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (!data) {
        fputs("{\"ok\":false,\"error\":{\"code\":\"json_encoding\",\"message\":\"Could not encode output.\"}}\n", stderr);
        return;
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
}

@end

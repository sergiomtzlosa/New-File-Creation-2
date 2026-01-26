#import <Foundation/Foundation.h>
#import "NFCCLIApplication.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithCapacity:(NSUInteger)MAX(argc - 1, 0)];
        for (int index = 1; index < argc; index++) {
            NSString *argument = [NSString stringWithUTF8String:argv[index]];
            if (argument) {
                [arguments addObject:argument];
            }
        }
        NFCCLIApplication *application = [[NFCCLIApplication alloc] init];
        return [application runWithArguments:arguments];
    }
}

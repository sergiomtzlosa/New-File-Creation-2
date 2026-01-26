#import <Cocoa/Cocoa.h>
#import "NFCAppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        static NFCAppDelegate *delegate = nil;
        delegate = [[NFCAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}

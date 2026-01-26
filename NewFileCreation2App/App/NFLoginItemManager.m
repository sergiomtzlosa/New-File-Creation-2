#import "NFLoginItemManager.h"
#import "NFLocalization.h"
#import <ServiceManagement/ServiceManagement.h>
#import <AppKit/AppKit.h>

@implementation NFLoginItemManager

+ (BOOL)isEnabled {
    return [self status] == 1;
}

+ (NSInteger)status {
    if (@available(macOS 13.0, *)) {
        return (NSInteger)SMAppService.mainAppService.status;
    }
    return -1;
}

+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        if (enabled) {
            return [service registerAndReturnError:error];
        }
        return [service unregisterAndReturnError:error];
    }
    if (error) {
        *error = [NSError errorWithDomain:@"com.sid.newfilecreation2"
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: NFLocalizedString(@"Launch at login requires macOS 13 or later.")}];
    }
    return NO;
}

+ (NSString *)statusDescription {
    if (@available(macOS 13.0, *)) {
        switch (SMAppService.mainAppService.status) {
            case SMAppServiceStatusEnabled:
                return NFLocalizedString(@"Enabled");
            case SMAppServiceStatusRequiresApproval:
                return NFLocalizedString(@"Requires approval in System Settings");
            case SMAppServiceStatusNotFound:
                return NFLocalizedString(@"Not found; move the app to /Applications");
            case SMAppServiceStatusNotRegistered:
            default:
                return NFLocalizedString(@"Not registered");
        }
    }
    return NFLocalizedString(@"Unavailable");
}

+ (void)openLoginItemsSettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

@end

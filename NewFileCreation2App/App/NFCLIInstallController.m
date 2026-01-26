#import "NFCLIInstallController.h"
#import "NFLocalization.h"

@implementation NFCLIInstallController

+ (NSString *)helperPath {
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Helpers/nfc"];
}

+ (NSString *)installPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/nfc"];
}

+ (BOOL)isInstalled {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self installPath];
    if (![fm fileExistsAtPath:path]) {
        return NO;
    }
    NSString *destination = [fm destinationOfSymbolicLinkAtPath:path error:nil];
    if (!destination) {
        return NO;
    }
    if (!destination.isAbsolutePath) {
        destination = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:destination];
    }
    return [destination.stringByStandardizingPath isEqualToString:[self helperPath].stringByStandardizingPath];
}

+ (BOOL)install:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *helper = [self helperPath];
    if (![fm isExecutableFileAtPath:helper]) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.sid.newfilecreation2"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: NFLocalizedString(@"The bundled nfc helper is missing. Rebuild or reinstall the app.")}];
        }
        return NO;
    }
    NSString *directory = [self installPath].stringByDeletingLastPathComponent;
    if (![fm fileExistsAtPath:directory]) {
        if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }
    NSString *path = [self installPath];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
        NSString *existingDestination = [fm destinationOfSymbolicLinkAtPath:path error:nil];
        if (!existingDestination) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.sid.newfilecreation2"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:NFLocalizedString(@"%@ already exists and is not a symlink. Remove it manually or choose another location."), path]}];
            }
            return NO;
        }
        if (![fm removeItemAtPath:path error:error]) {
            return NO;
        }
    }
    return [fm createSymbolicLinkAtPath:path withDestinationPath:helper error:error];
}

+ (BOOL)uninstall:(NSError **)error {
    NSString *path = [self installPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        return YES;
    }
    if (![fm destinationOfSymbolicLinkAtPath:path error:nil]) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.sid.newfilecreation2"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey: NFLocalizedString(@"The existing nfc is not a symlink managed by this app.")}];
        }
        return NO;
    }
    return [fm removeItemAtPath:path error:error];
}

+ (BOOL)isInstallDirectoryOnPATH {
    NSString *directory = [self installPath].stringByDeletingLastPathComponent;
    NSString *path = NSProcessInfo.processInfo.environment[@"PATH"] ?: @"";
    for (NSString *component in [path componentsSeparatedByString:@":"]) {
        if ([component.stringByStandardizingPath isEqualToString:directory.stringByStandardizingPath]) {
            return YES;
        }
    }
    return NO;
}

@end

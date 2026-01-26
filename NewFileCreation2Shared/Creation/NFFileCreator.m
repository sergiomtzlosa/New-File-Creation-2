#import "NFFileCreator.h"
#import "NFSanitize.h"
#import "NFErrors.h"

@implementation NFFileCreator

+ (BOOL)directoryIsWritable:(NSURL *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:directory.path isDirectory:&isDir] || !isDir) {
        return NO;
    }
    return [fm isWritableFileAtPath:directory.path];
}

+ (NSURL *)createFileFromTemplateAtURL:(NSURL *)templateURL
                             template:(NFTemplate *)template
                            directory:(NSURL *)directory
                             baseName:(NSString *)baseName
                               unique:(BOOL)unique
                                error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL isDir = NO;
    if (![fm fileExistsAtPath:templateURL.path isDirectory:&isDir]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorTemplateMissing
                                   description:[NSString stringWithFormat:@"The template “%@” is missing.", template.resolvedDisplayName]];
        }
        return nil;
    }
    if (![fm isReadableFileAtPath:templateURL.path]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorTemplateUnreadable
                                   description:[NSString stringWithFormat:@"The template “%@” cannot be read.", template.resolvedDisplayName]];
        }
        return nil;
    }

    BOOL directoryFlag = NO;
    if (![fm fileExistsAtPath:directory.path isDirectory:&directoryFlag] || !directoryFlag) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorDestinationInvalid
                                   description:[NSString stringWithFormat:@"“%@” is not a folder.", directory.path]];
        }
        return nil;
    }
    if (![self directoryIsWritable:directory]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorDestinationNotWritable
                                   description:[NSString stringWithFormat:@"The folder “%@” is not writable.", directory.lastPathComponent]];
        }
        return nil;
    }

    NSString *fallback = @"Untitled";
    NSString *sanitizedBase = [NFSanitize sanitizedBaseName:baseName fallback:fallback];
    NSString *fileName = [NFSanitize fileNameForBaseName:sanitizedBase
                                         templateFileName:templateURL.lastPathComponent.length > 0 ? templateURL.lastPathComponent : template.fileName];
    if (![NFSanitize isValidFileName:fileName]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorNameInvalid
                                   description:[NSString stringWithFormat:@"“%@” is not a valid file name.", fileName]];
        }
        return nil;
    }

    NSURL *proposed = [directory URLByAppendingPathComponent:fileName];
    return [self createFileFromTemplateAtURL:templateURL destination:proposed unique:unique error:error];
}

+ (NSURL *)createFileFromTemplateAtURL:(NSURL *)templateURL
                           destination:(NSURL *)destination
                                unique:(BOOL)unique
                                 error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL isDir = NO;
    if (![fm fileExistsAtPath:templateURL.path isDirectory:&isDir]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorTemplateMissing
                                   description:[NSString stringWithFormat:@"The template “%@” is missing.", templateURL.lastPathComponent]];
        }
        return nil;
    }
    if (![fm isReadableFileAtPath:templateURL.path]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorTemplateUnreadable
                                   description:[NSString stringWithFormat:@"The template “%@” cannot be read.", templateURL.lastPathComponent]];
        }
        return nil;
    }

    NSURL *directory = destination.URLByDeletingLastPathComponent;
    BOOL directoryFlag = NO;
    if (![fm fileExistsAtPath:directory.path isDirectory:&directoryFlag] || !directoryFlag) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorDestinationInvalid
                                   description:[NSString stringWithFormat:@"“%@” is not a folder.", directory.path]];
        }
        return nil;
    }
    if (![self directoryIsWritable:directory]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorDestinationNotWritable
                                   description:[NSString stringWithFormat:@"The folder “%@” is not writable.", directory.lastPathComponent]];
        }
        return nil;
    }
    if (![NFSanitize isValidFileName:destination.lastPathComponent]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorNameInvalid
                                   description:[NSString stringWithFormat:@"“%@” is not a valid file name.", destination.lastPathComponent]];
        }
        return nil;
    }

    if (!unique && [fm fileExistsAtPath:destination.path]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorFileExists
                                   description:[NSString stringWithFormat:@"“%@” already exists.", destination.lastPathComponent]];
        }
        return nil;
    }

    NSURL *target = unique ? [NFSanitize uniqueDestinationURLForURL:destination] : destination;
    for (NSUInteger attempt = 0; attempt < 1000; attempt++) {
        NSError *copyError = nil;
        if ([fm copyItemAtURL:templateURL toURL:target error:&copyError]) {
            return target;
        }
        BOOL exists = [fm fileExistsAtPath:target.path];
        if (unique && exists) {
            target = [NFSanitize uniqueDestinationURLForURL:target];
            continue;
        }
        if (error) {
            if (exists) {
                *error = [NSError nf_errorWithCode:NFErrorFileExists
                                       description:[NSString stringWithFormat:@"“%@” already exists.", target.lastPathComponent]];
            } else {
                *error = [NSError nf_errorWithCode:NFErrorDestinationNotWritable
                                       description:copyError.localizedDescription ?: @"The file could not be created."];
            }
        }
        return nil;
    }

    if (error) {
        *error = [NSError nf_errorWithCode:NFErrorFileExists
                               description:@"A unique file name could not be generated."];
    }
    return nil;
}

@end

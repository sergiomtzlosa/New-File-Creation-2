#import "NFFilePromiseProvider.h"
#import "NFFileCreator.h"
#import "NFSanitize.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation NFFilePromiseProvider

+ (NSString *)promisedFileNameForTemplate:(NFTemplate *)template defaultBaseName:(NSString *)defaultBaseName {
    NSString *base = [NFSanitize sanitizedBaseName:defaultBaseName fallback:NFDefaultBaseName];
    NSString *templateFileName = template.fileName.length > 0 ? template.fileName : template.resolvedDisplayName;
    return [NFSanitize fileNameForBaseName:base templateFileName:templateFileName];
}

+ (NSString *)fileTypeIdentifierForTemplateURL:(NSURL *)templateURL {
    NSNumber *isDirectory = nil;
    [templateURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    if (isDirectory.boolValue) {
        return UTTypeFolder.identifier;
    }
    UTType *type = [UTType typeWithFilenameExtension:templateURL.pathExtension];
    if (type && ([type conformsToType:UTTypeData] || [type conformsToType:UTTypeDirectory])) {
        return type.identifier;
    }
    return UTTypeData.identifier;
}

- (instancetype)initWithTemplate:(NFTemplate *)template
                     templateURL:(NSURL *)templateURL
                        fileName:(NSString *)fileName {
    self = [super init];
    if (self) {
        _template = template;
        _templateURL = [templateURL copy];
        _promisedFileName = [(fileName.length > 0 ? fileName : template.fileName) copy];
        self.fileType = [[self class] fileTypeIdentifierForTemplateURL:templateURL];
        self.delegate = self;
    }
    return self;
}

- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error {
    return [NFFileCreator createFileFromTemplateAtURL:self.templateURL
                                          destination:url
                                               unique:NO
                                                error:error] != nil;
}

#pragma mark - NSFilePromiseProviderDelegate

- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider fileNameForType:(NSString *)fileType {
    return self.promisedFileName;
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider
          writePromiseToURL:(NSURL *)url
          completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSError *error = nil;
    if (![self writeToURL:url error:&error]) {
        completionHandler(error ?: [NSError errorWithDomain:NSCocoaErrorDomain
                                                       code:NSFileWriteUnknownError
                                                   userInfo:@{NSLocalizedDescriptionKey: @"The promised file could not be created."}]);
        return;
    }

    void (^didWrite)(NSURL *) = self.didWriteFile;
    if (didWrite) {
        dispatch_async(dispatch_get_main_queue(), ^{
            didWrite(url);
        });
    }
    completionHandler(nil);
}

@end

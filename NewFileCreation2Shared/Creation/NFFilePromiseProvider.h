#import <AppKit/AppKit.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

/// A file promise for a new file created from a template.
///
/// Unlike dragging the template file itself, the promise writes a fresh copy with
/// the configured default base name when the drop target asks for it. The drop
/// target chooses the destination directory, so the file lands wherever the user
/// dropped it.
@interface NFFilePromiseProvider : NSFilePromiseProvider <NSFilePromiseProviderDelegate>

@property (nonatomic, strong, readonly) NFTemplate *template;
@property (nonatomic, strong, readonly) NSURL *templateURL;
@property (nonatomic, copy, readonly) NSString *promisedFileName;

/// Called on the main queue after the template has been copied successfully.
@property (nonatomic, copy, nullable) void (^didWriteFile)(NSURL *destinationURL);

/// Builds “Untitled.ext” from the configured base name and the template extension.
+ (NSString *)promisedFileNameForTemplate:(NFTemplate *)template
                          defaultBaseName:(NSString *)defaultBaseName;

/// Returns a UTI that is safe to promise. Falls back to public.data (or public.folder
/// for directory templates) when the extension does not identify a usable type.
+ (NSString *)fileTypeIdentifierForTemplateURL:(NSURL *)templateURL;

- (instancetype)initWithTemplate:(NFTemplate *)template
                     templateURL:(NSURL *)templateURL
                        fileName:(NSString *)fileName;

/// Copies the template to url. Never replaces an existing destination.
- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

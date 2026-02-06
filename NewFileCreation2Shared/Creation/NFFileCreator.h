#import <Foundation/Foundation.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFFileCreator : NSObject

/// Copies the template to the destination directory. Never overwrites an existing file.
+ (nullable NSURL *)createFileFromTemplateAtURL:(NSURL *)templateURL
                                       template:(NFTemplate *)template
                                      directory:(NSURL *)directory
                                       baseName:(nullable NSString *)baseName
                                         unique:(BOOL)unique
                                          error:(NSError **)error;

/// Copies a template to an exact destination path. The template extension is not
/// applied. When unique is YES, a numeric suffix is inserted before the extension.
+ (nullable NSURL *)createFileFromTemplateAtURL:(NSURL *)templateURL
                                    destination:(NSURL *)destination
                                         unique:(BOOL)unique
                                          error:(NSError **)error;

+ (BOOL)directoryIsWritable:(NSURL *)directory;

@end

NS_ASSUME_NONNULL_END

#import "NFRequest.h"
#import "NFErrors.h"

NSString * const NFURLScheme = @"newfilecreation2";

@implementation NFRequest

- (instancetype)init {
    self = [super init];
    if (self) {
        _kind = NFRequestKindUnknown;
        _unique = YES;
        _filePaths = @[];
    }
    return self;
}

+ (NFRequestKind)kindForHost:(NSString *)host {
    NSString *value = host.lowercaseString;
    if ([value isEqualToString:@"create"]) {
        return NFRequestKindCreate;
    }
    if ([value isEqualToString:@"quick"]) {
        return NFRequestKindQuick;
    }
    if ([value isEqualToString:@"library"] || [value isEqualToString:@"templates"]) {
        return NFRequestKindLibrary;
    }
    if ([value isEqualToString:@"settings"]) {
        return NFRequestKindSettings;
    }
    if ([value isEqualToString:@"add-template"] || [value isEqualToString:@"addtemplates"]) {
        return NFRequestKindAddTemplate;
    }
    return NFRequestKindUnknown;
}

+ (BOOL)hasTraversalComponent:(NSString *)path {
    for (NSString *component in [path componentsSeparatedByString:@"/"]) {
        if ([component isEqualToString:@".."]) {
            return YES;
        }
    }
    return NO;
}

+ (instancetype)requestWithURL:(NSURL *)url error:(NSError **)error {
    if (![url.scheme.lowercaseString isEqualToString:NFURLScheme]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorRequestInvalid
                                   description:@"The URL does not use the newfilecreation2 scheme."];
        }
        return nil;
    }
    NFRequestKind kind = [self kindForHost:url.host];
    if (kind == NFRequestKindUnknown) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorRequestInvalid
                                   description:[NSString stringWithFormat:@"Unknown request “%@”.", url.host ?: @""]];
        }
        return nil;
    }

    NFRequest *request = [[self alloc] init];
    request.kind = kind;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableDictionary<NSString *, NSString *> *query = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if (item.name.length > 0) {
            query[item.name.lowercaseString] = item.value ?: @"";
        }
    }

    if (kind == NFRequestKindCreate) {
        NSString *identifier = query[@"template"] ?: query[@"templateid"] ?: query[@"id"];
        if (identifier.length == 0) {
            if (error) {
                *error = [NSError nf_errorWithCode:NFErrorRequestInvalid
                                       description:@"The create request is missing a template identifier."];
            }
            return nil;
        }
        request.templateIdentifier = identifier;
        request.directoryPath = query[@"dir"] ?: query[@"directory"];
        request.baseName = query[@"name"] ?: query[@"basename"];
        NSString *unique = query[@"unique"];
        if (unique.length > 0) {
            request.unique = [unique boolValue];
        }
        request.openAfterCreate = [query[@"open"] boolValue];
        request.revealAfterCreate = [query[@"reveal"] boolValue];

        if (request.directoryPath.length > 0) {
            if (![request.directoryPath isAbsolutePath]) {
                if (error) {
                    *error = [NSError nf_errorWithCode:NFErrorRequestInvalid
                                           description:@"The destination folder must be an absolute path."];
                }
                return nil;
            }
            if ([self hasTraversalComponent:request.directoryPath]) {
                if (error) {
                    *error = [NSError nf_errorWithCode:NFErrorRequestInvalid
                                           description:@"The destination folder contains a path traversal component."];
                }
                return nil;
            }
        }
        if (request.baseName.length > 0 && ![request.baseName isKindOfClass:[NSString class]]) {
            if (error) {
                *error = [NSError nf_errorWithCode:NFErrorRequestInvalid description:@"The name is invalid."];
            }
            return nil;
        }
    } else if (kind == NFRequestKindAddTemplate) {
        NSMutableArray<NSString *> *paths = [NSMutableArray array];
        NSString *path = query[@"path"];
        if (path.length > 0) {
            [paths addObject:path];
        }
        NSString *encodedPaths = query[@"paths"];
        if (encodedPaths.length > 0) {
            for (NSString *candidate in [encodedPaths componentsSeparatedByString:@"|"]) {
                NSString *decoded = candidate.stringByRemovingPercentEncoding ?: candidate;
                if (decoded.length > 0) {
                    [paths addObject:decoded];
                }
            }
        }
        request.filePaths = paths;
    }
    return request;
}

- (NSURL *)URLRepresentation {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = NFURLScheme;
    switch (self.kind) {
        case NFRequestKindCreate: components.host = @"create"; break;
        case NFRequestKindQuick: components.host = @"quick"; break;
        case NFRequestKindLibrary: components.host = @"library"; break;
        case NFRequestKindSettings: components.host = @"settings"; break;
        case NFRequestKindAddTemplate: components.host = @"add-template"; break;
        default: components.host = @"unknown"; break;
    }
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    if (self.templateIdentifier.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"template" value:self.templateIdentifier]];
    }
    if (self.directoryPath.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"dir" value:self.directoryPath]];
    }
    if (self.baseName.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"name" value:self.baseName]];
    }
    if (self.kind == NFRequestKindCreate) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"unique" value:self.unique ? @"1" : @"0"]];
        if (self.openAfterCreate) {
            [items addObject:[NSURLQueryItem queryItemWithName:@"open" value:@"1"]];
        }
        if (self.revealAfterCreate) {
            [items addObject:[NSURLQueryItem queryItemWithName:@"reveal" value:@"1"]];
        }
    }
    if (self.filePaths.count > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"paths" value:[self.filePaths componentsJoinedByString:@"|"]]];
    }
    components.queryItems = items;
    return components.URL;
}

+ (NSURL *)createRequestURLWithTemplateIdentifier:(NSString *)identifier
                                    directoryPath:(NSString *)directoryPath
                                         baseName:(NSString *)baseName
                                           unique:(BOOL)unique {
    NFRequest *request = [[self alloc] init];
    request.kind = NFRequestKindCreate;
    request.templateIdentifier = identifier;
    request.directoryPath = directoryPath;
    request.baseName = baseName;
    request.unique = unique;
    request.revealAfterCreate = YES;
    return [request URLRepresentation];
}

+ (NSURL *)addTemplateRequestURLWithPaths:(NSArray<NSString *> *)paths {
    NFRequest *request = [[self alloc] init];
    request.kind = NFRequestKindAddTemplate;
    request.filePaths = paths ?: @[];
    return [request URLRepresentation];
}

@end

#import "NFTemplate.h"

NSString * const NFDefaultBaseName = @"Untitled";
NSString * const NFDefaultCategoryOther = @"Other";

NSString *NFTemplateSortModeString(NFTemplateSortMode mode) {
    switch (mode) {
        case NFTemplateSortName: return @"name";
        case NFTemplateSortCategory: return @"category";
        case NFTemplateSortFileType: return @"fileType";
        case NFTemplateSortLastUsed: return @"lastUsed";
        case NFTemplateSortMostUsed: return @"mostUsed";
        case NFTemplateSortManual:
        default: return @"manual";
    }
}

NFTemplateSortMode NFTemplateSortModeFromString(NSString *value) {
    NSString *normalized = [value.lowercaseString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"_" withString:@""];
    if ([normalized isEqualToString:@"name"] || [normalized isEqualToString:@"displayname"]) {
        return NFTemplateSortName;
    }
    if ([normalized isEqualToString:@"category"] || [normalized isEqualToString:@"categories"]) {
        return NFTemplateSortCategory;
    }
    if ([normalized isEqualToString:@"filetype"] || [normalized isEqualToString:@"extension"] ||
        [normalized isEqualToString:@"type"]) {
        return NFTemplateSortFileType;
    }
    if ([normalized isEqualToString:@"lastused"] || [normalized isEqualToString:@"recent"]) {
        return NFTemplateSortLastUsed;
    }
    if ([normalized isEqualToString:@"mostused"] || [normalized isEqualToString:@"usage"]) {
        return NFTemplateSortMostUsed;
    }
    return NFTemplateSortManual;
}

static NSString *NFStringOr(NSDictionary *dict, NSString *key, NSString *fallback) {
    id value = dict[key];
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        return value;
    }
    return fallback;
}

static NSDate *NFDateFromValue(id value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });
    NSDate *date = [formatter dateFromString:value];
    if (!date) {
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        date = [formatter dateFromString:value];
    }
    return date;
}

static NSString *NFDateString(NSDate *date) {
    if (!date) {
        return nil;
    }
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });
    return [formatter stringFromDate:date];
}

@implementation NFTemplate

+ (instancetype)templateWithFileName:(NSString *)fileName {
    NFTemplate *template = [[self alloc] init];
    template.identifier = NSUUID.UUID.UUIDString;
    template.fileName = fileName;
    template.displayName = [self displayNameForFileName:fileName];
    template.category = [self inferCategoryForFileExtension:fileName.pathExtension];
    template.enabled = YES;
    template.favorite = NO;
    template.sortIndex = 0;
    template.createdAt = [NSDate date];
    template.source = @"user";
    return template;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = NSUUID.UUID.UUIDString;
        _fileName = @"";
        _displayName = @"";
        _category = NFDefaultCategoryOther;
        _enabled = YES;
        _favorite = NO;
        _sortIndex = 0;
        _createdAt = [NSDate date];
        _useCount = 0;
        _source = @"user";
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary {
    self = [self init];
    if (!self) {
        return nil;
    }
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return self;
    }

    NSString *identifier = NFStringOr(dictionary, @"id", nil);
    if (identifier.length == 0) {
        identifier = NFStringOr(dictionary, @"identifier", nil);
    }
    _identifier = identifier.length > 0 ? identifier : NSUUID.UUID.UUIDString;

    NSString *fileName = NFStringOr(dictionary, @"fileName", @"");
    if (fileName.length == 0) {
        fileName = NFStringOr(dictionary, @"file", @"");
    }
    _fileName = fileName;
    _displayName = NFStringOr(dictionary, @"displayName", [NFTemplate displayNameForFileName:fileName]);
    _category = NFStringOr(dictionary, @"category", [NFTemplate inferCategoryForFileExtension:fileName.pathExtension]);

    id enabled = dictionary[@"enabled"];
    _enabled = [enabled respondsToSelector:@selector(boolValue)] ? [enabled boolValue] : YES;
    id favorite = dictionary[@"favorite"];
    _favorite = [favorite respondsToSelector:@selector(boolValue)] ? [favorite boolValue] : NO;

    id sortIndex = dictionary[@"sortIndex"];
    _sortIndex = [sortIndex respondsToSelector:@selector(integerValue)] ? [sortIndex integerValue] : 0;
    id useCount = dictionary[@"useCount"];
    _useCount = [useCount respondsToSelector:@selector(integerValue)] ? [useCount integerValue] : 0;

    _createdAt = NFDateFromValue(dictionary[@"createdAt"]) ?: [NSDate date];
    _lastUsedAt = NFDateFromValue(dictionary[@"lastUsedAt"]);
    _source = NFStringOr(dictionary, @"source", @"user");
    _notes = NFStringOr(dictionary, @"notes", nil);
    return self;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = self.identifier ?: NSUUID.UUID.UUIDString;
    dict[@"fileName"] = self.fileName ?: @"";
    dict[@"displayName"] = self.resolvedDisplayName;
    dict[@"category"] = self.category ?: NFDefaultCategoryOther;
    dict[@"enabled"] = @(self.enabled);
    dict[@"favorite"] = @(self.favorite);
    dict[@"sortIndex"] = @(self.sortIndex);
    dict[@"useCount"] = @(self.useCount);
    dict[@"source"] = self.source ?: @"user";
    if (self.createdAt) {
        dict[@"createdAt"] = NFDateString(self.createdAt);
    }
    if (self.lastUsedAt) {
        dict[@"lastUsedAt"] = NFDateString(self.lastUsedAt);
    }
    if (self.notes.length > 0) {
        dict[@"notes"] = self.notes;
    }
    return dict;
}

- (NSString *)fileExtension {
    return self.fileName.pathExtension ?: @"";
}

- (NSString *)resolvedDisplayName {
    if (self.displayName.length > 0) {
        return self.displayName;
    }
    return [NFTemplate displayNameForFileName:self.fileName];
}

+ (NSString *)displayNameForFileName:(NSString *)fileName {
    NSString *base = fileName.lastPathComponent.stringByDeletingPathExtension;
    if (base.length == 0) {
        return fileName.lastPathComponent;
    }
    static NSDictionary<NSString *, NSString *> *friendlyNames = nil;
    static NSDictionary<NSString *, NSString *> *friendlyFileNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        friendlyFileNames = @{
            @"file.jsp": @"JSP Page",
            @"file.php": @"PHP Script",
            @"file.wml": @"WML Document",
            @"file.xml": @"XML Document",
            @"script.pl": @"Perl Script",
            @"script.py": @"Python Script",
            @"script.rb": @"Ruby Script",
            @"script.sh": @"Shell Script",
            @"style.css": @"CSS Stylesheet",
            @"tcl.tcl": @"Tcl Script",
            @"tk.tcl": @"Tk Script"
        };
        friendlyNames = @{
            @"textfile": @"Text File",
            @"rtfdocument": @"Rich Text",
            @"worddocument": @"Word Document",
            @"exceldocument": @"Excel Spreadsheet",
            @"powerpointdocument": @"PowerPoint Presentation",
            @"pages10": @"Pages Document",
            @"numbers10": @"Numbers Spreadsheet",
            @"numbers09": @"Numbers Spreadsheet",
            @"keynote09": @"Keynote Presentation",
            @"latex": @"LaTeX Document",
            @"epub": @"ePub",
            @"html": @"HTML Page",
            @"html5": @"HTML5 Page",
            @"xhtml": @"XHTML Page",
            @"graphic": @"SVG Graphic",
            @"odftextdocument": @"ODF Text Document",
            @"odfspreadsheet": @"ODF Spreadsheet",
            @"odfpresentation": @"ODF Presentation",
            @"odfdrawing": @"ODF Drawing"
        };
    });
    NSString *friendly = friendlyFileNames[fileName.lastPathComponent.lowercaseString];
    if (friendly) {
        return friendly;
    }
    friendly = friendlyNames[base.lowercaseString];
    if (friendly) {
        return friendly;
    }

    NSMutableString *result = [NSMutableString stringWithString:[base stringByReplacingOccurrencesOfString:@"_" withString:@" "]];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"([a-z0-9])([A-Z])" options:0 error:nil];
    [regex replaceMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"$1 $2"];
    [result replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, result.length)];
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString *)inferCategoryForFileExtension:(NSString *)fileExtension {
    NSString *ext = fileExtension.lowercaseString;
    if (ext.length == 0) {
        return NFDefaultCategoryOther;
    }
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"txt": @"Documents", @"md": @"Documents", @"markdown": @"Documents",
            @"rtf": @"Documents", @"rtfd": @"Documents", @"doc": @"Documents",
            @"docx": @"Documents", @"pages": @"Documents", @"pdf": @"Documents",
            @"tex": @"Documents", @"odt": @"Documents",
            @"xls": @"Spreadsheets", @"xlsx": @"Spreadsheets", @"numbers": @"Spreadsheets",
            @"csv": @"Spreadsheets", @"tsv": @"Spreadsheets", @"ods": @"Spreadsheets",
            @"ppt": @"Presentations", @"pptx": @"Presentations", @"key": @"Presentations",
            @"odp": @"Presentations",
            @"swift": @"Code", @"m": @"Code", @"mm": @"Code", @"h": @"Code",
            @"c": @"Code", @"cpp": @"Code", @"hpp": @"Code", @"js": @"Code",
            @"ts": @"Code", @"jsx": @"Code", @"tsx": @"Code", @"py": @"Code",
            @"rb": @"Code", @"go": @"Code", @"rs": @"Code", @"java": @"Code",
            @"kt": @"Code", @"sh": @"Code", @"zsh": @"Code", @"bash": @"Code",
            @"html": @"Code", @"css": @"Code", @"scss": @"Code", @"json": @"Code",
            @"yaml": @"Code", @"yml": @"Code", @"toml": @"Code", @"xml": @"Code",
            @"sql": @"Code", @"plist": @"Code",
            @"png": @"Images", @"jpg": @"Images", @"jpeg": @"Images", @"gif": @"Images",
            @"svg": @"Images", @"tiff": @"Images", @"heic": @"Images", @"webp": @"Images",
            @"mp3": @"Audio", @"wav": @"Audio", @"m4a": @"Audio", @"aiff": @"Audio",
            @"flac": @"Audio",
            @"mp4": @"Video", @"mov": @"Video", @"m4v": @"Video", @"avi": @"Video",
            @"mkv": @"Video",
            @"zip": @"Archives", @"tar": @"Archives", @"gz": @"Archives",
            @"7z": @"Archives", @"rar": @"Archives"
        };
    });
    return map[ext] ?: NFDefaultCategoryOther;
}

- (id)copyWithZone:(NSZone *)zone {
    NFTemplate *copy = [[NFTemplate allocWithZone:zone] init];
    copy.identifier = [self.identifier copy];
    copy.fileName = [self.fileName copy];
    copy.displayName = [self.displayName copy];
    copy.category = [self.category copy];
    copy.enabled = self.enabled;
    copy.favorite = self.favorite;
    copy.sortIndex = self.sortIndex;
    copy.createdAt = [self.createdAt copy];
    copy.lastUsedAt = [self.lastUsedAt copy];
    copy.useCount = self.useCount;
    copy.source = [self.source copy];
    copy.notes = [self.notes copy];
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[NFTemplate class]]) {
        return NO;
    }
    return [self.identifier isEqualToString:((NFTemplate *)object).identifier];
}

- (NSUInteger)hash {
    return self.identifier.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NFTemplate %@ (%@)>", self.resolvedDisplayName, self.identifier];
}

@end

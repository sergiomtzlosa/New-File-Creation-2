#import "NFTestSupport.h"
#import "NFLocalization.h"

@interface NFLocalizationTests : NFTestCase
@end

@implementation NFLocalizationTests

- (NSArray<NSString *> *)v1Languages {
    return @[@"en", @"ar", @"ca", @"da", @"de", @"el", @"es", @"eu-ES", @"fi", @"fr",
             @"gl", @"hi", @"id", @"is-IS", @"it", @"ja", @"ko", @"ms", @"nb", @"nl",
             @"pl", @"pt-PT", @"ro", @"ru", @"sv", @"tr", @"zh-Hans", @"zh-Hant"];
}

- (NSBundle *)localizationBundleForLanguage:(NSString *)language {
    NSString *directory = [language stringByAppendingPathExtension:@"lproj"];
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:directory];
    return [NSBundle bundleWithPath:path];
}

- (NSDictionary<NSString *, NSString *> *)stringsForLanguage:(NSString *)language {
    NSBundle *bundle = [self localizationBundleForLanguage:language];
    NSString *path = [bundle pathForResource:@"Localizable" ofType:@"strings"];
    if (!path) {
        return @{};
    }
    NSDictionary *strings = [NSDictionary dictionaryWithContentsOfFile:path];
    return [strings isKindOfClass:[NSDictionary class]] ? strings : @{};
}

- (NSArray<NSString *> *)placeholdersInString:(NSString *)string {
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:
        @"%(?:\\d+\\$)?[-+#0-9.]*[a-zA-Z@%]" options:0 error:nil];
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSTextCheckingResult *match in [expression matchesInString:string
                                                            options:0
                                                              range:NSMakeRange(0, string.length)]) {
        [tokens addObject:[string substringWithRange:match.range]];
    }
    return [tokens sortedArrayUsingSelector:@selector(compare:)];
}

- (void)testEveryV1LanguageHasTheSameKeysAsEnglish {
    NSDictionary *english = [self stringsForLanguage:@"en"];
    XCTAssertGreaterThan(english.count, 0u);

    for (NSString *language in [self v1Languages]) {
        NSDictionary *localized = [self stringsForLanguage:language];
        XCTAssertGreaterThan(localized.count, 0u, @"%@ has no Localizable.strings", language);
        NSMutableSet<NSString *> *missing = [NSMutableSet setWithArray:english.allKeys];
        [missing minusSet:[NSSet setWithArray:localized.allKeys]];
        NSMutableSet<NSString *> *extra = [NSMutableSet setWithArray:localized.allKeys];
        [extra minusSet:[NSSet setWithArray:english.allKeys]];
        XCTAssertEqualObjects(missing, [NSSet set], @"Keys missing from %@", language);
        XCTAssertEqualObjects(extra, [NSSet set], @"Keys only present in %@", language);
    }
}

- (void)testLocalizedValuesAreNotBlankInEveryLanguage {
    for (NSString *language in [self v1Languages]) {
        NSDictionary<NSString *, NSString *> *strings = [self stringsForLanguage:language];
        for (NSString *key in strings) {
            NSString *value = strings[key];
            XCTAssertGreaterThan(value.length, 0u, @"%@ has an empty value for “%@”", language, key);
            XCTAssertFalse([value containsString:@"[[["], @"%@ still contains a translation marker for “%@”", language, key);
        }
    }
}

- (void)testPlaceholdersArePreservedInEveryLanguage {
    NSDictionary<NSString *, NSString *> *english = [self stringsForLanguage:@"en"];
    for (NSString *language in [self v1Languages]) {
        NSDictionary<NSString *, NSString *> *strings = [self stringsForLanguage:language];
        for (NSString *key in english) {
            NSString *translated = strings[key];
            if (translated.length == 0) {
                continue;
            }
            XCTAssertEqualObjects([self placeholdersInString:translated],
                                  [self placeholdersInString:english[key]],
                                  @"%@ changed the placeholders for “%@”: %@", language, key, translated);
        }
    }
}

- (void)testFinderStringsAreLocalized {
    NSBundle *spanishBundle = [self localizationBundleForLanguage:@"es"];
    XCTAssertNotNil(spanishBundle);
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"New File" value:nil table:@"Localizable"], @"Nuevo archivo");
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"Add as Template" value:nil table:@"Localizable"], @"Añadir como plantilla");
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"Create a new file from a template" value:nil table:@"Localizable"], @"Crea un archivo nuevo a partir de una plantilla");
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"Create the file in “%@”." value:nil table:@"Localizable"], @"Crea el archivo en «%@».");
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"Search Templates" value:nil table:@"Localizable"], @"Buscar plantillas");
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"Menu bar icon (always available)" value:nil table:@"Localizable"], @"Icono de la barra de menús (siempre disponible)");
}

- (void)testNewInterfaceStringsAreLocalized {
    NSBundle *spanish = [self localizationBundleForLanguage:@"es"];
    XCTAssertEqualObjects([spanish localizedStringForKey:@"Remove Category" value:nil table:@"Localizable"], @"Eliminar categoría");
    XCTAssertEqualObjects([spanish localizedStringForKey:@"File type" value:nil table:@"Localizable"], @"Tipo de archivo");
    XCTAssertEqualObjects([spanish localizedStringForKey:@"Show Get Started" value:nil table:@"Localizable"], @"Mostrar primeros pasos");

    NSBundle *german = [self localizationBundleForLanguage:@"de"];
    XCTAssertEqualObjects([german localizedStringForKey:@"Settings" value:nil table:@"Localizable"], @"Einstellungen");
    XCTAssertFalse([[german localizedStringForKey:@"Drag a template to a folder or the Desktop." value:nil table:@"Localizable"]
                    isEqualToString:@"Drag a template to a folder or the Desktop."]);

    NSBundle *japanese = [self localizationBundleForLanguage:@"ja"];
    XCTAssertFalse([[japanese localizedStringForKey:@"Help and getting started" value:nil table:@"Localizable"]
                    isEqualToString:@"Help and getting started"]);
}

- (void)testQuickPanelDragHintIsLocalized {
    NSBundle *spanishBundle = [self localizationBundleForLanguage:@"es"];
    XCTAssertEqualObjects([spanishBundle localizedStringForKey:@"↩ Create file    ⠿ Drag to Finder    esc Close" value:nil table:@"Localizable"],
                          @"↩ Crear archivo    ⠿ Arrastrar al Finder    esc Cerrar");
}

- (void)testMissingKeysFallBackToTheKey {
    XCTAssertEqualObjects(NFLocalizedString(@"A key that does not exist"), @"A key that does not exist");
    XCTAssertEqualObjects(NFLocalizedStringDefault(@"A key that does not exist", @"fallback"), @"fallback");
}

@end

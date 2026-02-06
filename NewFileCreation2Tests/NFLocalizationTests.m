#import "NFTestSupport.h"
#import "NFLocalization.h"

@interface NFLocalizationTests : NFTestCase
@end

@implementation NFLocalizationTests

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

- (void)testEnglishAndSpanishHaveTheSameKeys {
    NSDictionary *english = [self stringsForLanguage:@"en"];
    NSDictionary *spanish = [self stringsForLanguage:@"es"];
    XCTAssertGreaterThan(english.count, 0u);
    XCTAssertGreaterThan(spanish.count, 0u);

    NSMutableSet<NSString *> *missingInSpanish = [NSMutableSet setWithArray:english.allKeys];
    [missingInSpanish minusSet:[NSSet setWithArray:spanish.allKeys]];
    NSMutableSet<NSString *> *missingInEnglish = [NSMutableSet setWithArray:spanish.allKeys];
    [missingInEnglish minusSet:[NSSet setWithArray:english.allKeys]];

    XCTAssertEqualObjects(missingInSpanish, [NSSet set], @"Keys missing from Spanish");
    XCTAssertEqualObjects(missingInEnglish, [NSSet set], @"Keys missing from English");
}

- (void)testLocalizedValuesAreNotBlank {
    for (NSString *language in @[@"en", @"es"]) {
        NSDictionary<NSString *, NSString *> *strings = [self stringsForLanguage:language];
        for (NSString *key in strings) {
            NSString *value = strings[key];
            XCTAssertGreaterThan(value.length, 0u, @"%@ has an empty value for “%@”", language, key);
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

#import "NFShortcutCenter.h"
#import "NFErrors.h"
#import "NFLocalization.h"
#import <Carbon/Carbon.h>

static const OSType NFHotKeySignature = 'NFC2';

@interface NFShortcutCenter () {
    EventHotKeyRef _hotKeyRef;
    EventHandlerRef _handlerRef;
}
@end

static OSStatus NFHotKeyEventHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    EventHotKeyID hotKeyID = {0};
    GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hotKeyID), NULL, &hotKeyID);
    if (hotKeyID.signature == NFHotKeySignature) {
        NFShortcutCenter *center = (__bridge NFShortcutCenter *)userData;
        if (center.handler) {
            center.handler();
        }
    }
    return noErr;
}

@implementation NFShortcutCenter

+ (instancetype)sharedCenter {
    static NFShortcutCenter *center = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [[self alloc] init];
    });
    return center;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        EventTypeSpec type = {kEventClassKeyboard, kEventHotKeyPressed};
        InstallApplicationEventHandler(&NFHotKeyEventHandler, 1, &type, (__bridge void *)self, &_handlerRef);
    }
    return self;
}

- (void)dealloc {
    [self unregister];
    if (_handlerRef) {
        RemoveEventHandler(_handlerRef);
    }
}

- (void)unregister {
    if (_hotKeyRef) {
        UnregisterEventHotKey(_hotKeyRef);
        _hotKeyRef = NULL;
    }
}

- (BOOL)registerShortcut:(NSString *)shortcut error:(NSError **)error {
    [self unregister];
    if (shortcut.length == 0 || [shortcut.lowercaseString isEqualToString:@"none"]) {
        return YES;
    }

    UInt32 modifiers = 0;
    NSString *keyToken = nil;
    for (NSString *token in [shortcut.lowercaseString componentsSeparatedByString:@"+"]) {
        NSString *part = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([part isEqualToString:@"control"] || [part isEqualToString:@"ctrl"]) {
            modifiers |= controlKey;
        } else if ([part isEqualToString:@"option"] || [part isEqualToString:@"alt"]) {
            modifiers |= optionKey;
        } else if ([part isEqualToString:@"command"] || [part isEqualToString:@"cmd"]) {
            modifiers |= cmdKey;
        } else if ([part isEqualToString:@"shift"]) {
            modifiers |= shiftKey;
        } else if (part.length > 0) {
            keyToken = part;
        }
    }

    UInt32 keyCode = 0;
    if (![self keyCodeForKey:keyToken code:&keyCode]) {
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorUnknown
                                   description:[NSString stringWithFormat:NFLocalizedString(@"Unsupported shortcut key “%@”."), keyToken ?: shortcut]];
        }
        return NO;
    }

    EventHotKeyID hotKeyID = {.signature = NFHotKeySignature, .id = 1};
    OSStatus status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &_hotKeyRef);
    if (status != noErr) {
        _hotKeyRef = NULL;
        if (error) {
            *error = [NSError nf_errorWithCode:NFErrorUnknown
                                   description:[NSString stringWithFormat:NFLocalizedString(@"The shortcut could not be registered (Carbon error %d). It may conflict with another app."), (int)status]];
        }
        return NO;
    }
    return YES;
}

- (BOOL)keyCodeForKey:(NSString *)key code:(UInt32 *)code {
    if (key.length == 1) {
        unichar character = [key characterAtIndex:0];
        if (character >= 'a' && character <= 'z') {
            static const UInt32 keyCodes[26] = {
                kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
                kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
                kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
                kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
                kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
                kVK_ANSI_Z
            };
            *code = keyCodes[character - 'a'];
            return YES;
        }
        if (character >= '0' && character <= '9') {
            static const UInt32 keyCodes[10] = {
                kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
            };
            *code = keyCodes[character - '0'];
            return YES;
        }
    }
    static NSDictionary<NSString *, NSNumber *> *named = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        named = @{
            @"space": @(kVK_Space),
            @"return": @(kVK_Return),
            @"enter": @(kVK_Return),
            @"tab": @(kVK_Tab),
            @"escape": @(kVK_Escape),
            @"esc": @(kVK_Escape),
            @"delete": @(kVK_Delete),
            @"backspace": @(kVK_Delete),
            @"left": @(kVK_LeftArrow),
            @"right": @(kVK_RightArrow),
            @"up": @(kVK_UpArrow),
            @"down": @(kVK_DownArrow),
            @"f1": @(kVK_F1), @"f2": @(kVK_F2), @"f3": @(kVK_F3),
            @"f4": @(kVK_F4), @"f5": @(kVK_F5), @"f6": @(kVK_F6),
            @"f7": @(kVK_F7), @"f8": @(kVK_F8), @"f9": @(kVK_F9),
            @"f10": @(kVK_F10), @"f11": @(kVK_F11), @"f12": @(kVK_F12)
        };
    });
    NSNumber *value = named[key.lowercaseString];
    if (value) {
        *code = value.unsignedIntValue;
        return YES;
    }
    return NO;
}

+ (NSArray<NSString *> *)presetShortcuts {
    return @[@"control+option+n", @"control+option+space", @"command+shift+n", @"option+command+n", @"none"];
}

+ (NSString *)displayNameForShortcut:(NSString *)shortcut {
    if (shortcut.length == 0 || [shortcut.lowercaseString isEqualToString:@"none"]) {
        return NFLocalizedString(@"None");
    }
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *token in [shortcut componentsSeparatedByString:@"+"]) {
        NSString *lower = token.lowercaseString;
        if ([lower isEqualToString:@"control"] || [lower isEqualToString:@"ctrl"]) {
            [parts addObject:NFLocalizedString(@"Control")];
        } else if ([lower isEqualToString:@"option"] || [lower isEqualToString:@"alt"]) {
            [parts addObject:NFLocalizedString(@"Option")];
        } else if ([lower isEqualToString:@"command"] || [lower isEqualToString:@"cmd"]) {
            [parts addObject:NFLocalizedString(@"Command")];
        } else if ([lower isEqualToString:@"shift"]) {
            [parts addObject:NFLocalizedString(@"Shift")];
        } else if (token.length > 0) {
            [parts addObject:token.uppercaseString];
        }
    }
    return [parts componentsJoinedByString:@"+"];
}

@end

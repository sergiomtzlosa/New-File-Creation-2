#import "NFFinderMenuBuilder.h"
#import "NFLocalization.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation NFFinderMenuBuilder

+ (NSArray<NFTemplate *> *)orderedTemplatesForConfig:(NFConfig *)config favoritesFirst:(BOOL)favoritesFirst {
    NSArray<NFTemplate *> *enabled = config.enabledTemplates;
    return [enabled sortedArrayUsingComparator:^NSComparisonResult(NFTemplate *a, NFTemplate *b) {
        if (favoritesFirst && a.favorite != b.favorite) {
            return a.favorite ? NSOrderedAscending : NSOrderedDescending;
        }
        if (a.sortIndex != b.sortIndex) {
            return a.sortIndex < b.sortIndex ? NSOrderedAscending : NSOrderedDescending;
        }
        return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
    }];
}

+ (NSImage *)iconForTemplate:(NFTemplate *)template {
    NSString *extension = template.fileExtension;
    if (extension.length == 0) {
        return [NSImage imageWithSystemSymbolName:@"doc" accessibilityDescription:template.resolvedDisplayName];
    }
    UTType *type = [UTType typeWithFilenameExtension:extension];
    NSImage *icon = nil;
    if (type) {
        icon = [[NSWorkspace sharedWorkspace] iconForContentType:type];
    }
    if (!icon) {
        icon = [NSImage imageWithSystemSymbolName:@"doc" accessibilityDescription:template.resolvedDisplayName];
    }
    icon.size = NSMakeSize(16, 16);
    return icon;
}

+ (NSMenuItem *)itemForTemplate:(NFTemplate *)template
                         target:(id)target
                         action:(SEL)action
                      showIcons:(BOOL)showIcons {
    NSString *title = [NSString stringWithFormat:NFLocalizedString(@"New %@"), template.resolvedDisplayName];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                  action:action
                                           keyEquivalent:@""];
    item.target = target;
    item.representedObject = template.identifier;
    item.toolTip = template.fileName;
    if (showIcons) {
        item.image = [self iconForTemplate:template];
    }
    return item;
}

+ (NSMenu *)menuForConfig:(NFConfig *)config
                   target:(id)target
                   action:(SEL)action
                  options:(NFFinderMenuOptions)options {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:NFLocalizedString(@"New File")];
    BOOL favoritesFirst = (options & NFFinderMenuOptionFavoritesFirst) != 0;
    BOOL groupByCategory = (options & NFFinderMenuOptionGroupByCategory) != 0;
    BOOL showIcons = (options & NFFinderMenuOptionShowIcons) != 0;

    NSArray<NFTemplate *> *templates = [self orderedTemplatesForConfig:config favoritesFirst:favoritesFirst];
    if (templates.count == 0) {
        NSMenuItem *empty = [[NSMenuItem alloc] initWithTitle:NFLocalizedString(@"No Templates") action:nil keyEquivalent:@""];
        empty.enabled = NO;
        [menu addItem:empty];
        return menu;
    }

    if (groupByCategory) {
        NSMutableArray<NFTemplate *> *favorites = [NSMutableArray array];
        NSMutableOrderedSet<NSString *> *categoryNames = [NSMutableOrderedSet orderedSet];
        NSMutableDictionary<NSString *, NSMutableArray<NFTemplate *> *> *byCategory = [NSMutableDictionary dictionary];
        for (NFTemplate *template in templates) {
            if (favoritesFirst && template.favorite) {
                [favorites addObject:template];
                continue;
            }
            NSString *category = template.category.length > 0 ? template.category : NFDefaultCategoryOther;
            [categoryNames addObject:category];
            if (!byCategory[category]) {
                byCategory[category] = [NSMutableArray array];
            }
            [byCategory[category] addObject:template];
        }
        if (favorites.count > 0) {
            for (NFTemplate *template in favorites) {
                [menu addItem:[self itemForTemplate:template target:target action:action showIcons:showIcons]];
            }
            if (byCategory.count > 0) {
                [menu addItem:[NSMenuItem separatorItem]];
            }
        }
        NSArray<NSString *> *sortedCategories = [categoryNames.array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        for (NSString *category in sortedCategories) {
            NSString *displayName = NFLocalizedString(category);
            NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:displayName action:nil keyEquivalent:@""];
            NSMenu *submenu = [[NSMenu alloc] initWithTitle:displayName];
            for (NFTemplate *template in byCategory[category]) {
                [submenu addItem:[self itemForTemplate:template target:target action:action showIcons:showIcons]];
            }
            categoryItem.submenu = submenu;
            [menu addItem:categoryItem];
        }
        return menu;
    }

    for (NFTemplate *template in templates) {
        [menu addItem:[self itemForTemplate:template target:target action:action showIcons:showIcons]];
    }
    return menu;
}

@end

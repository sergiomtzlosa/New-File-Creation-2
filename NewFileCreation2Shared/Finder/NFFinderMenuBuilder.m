#import "NFFinderMenuBuilder.h"
#import "NFLocalization.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation NFFinderMenuBuilder

+ (NFTemplateSortMode)sortModeForConfig:(NFConfig *)config {
    return NFTemplateSortModeFromString([config stringSettingForKey:@"sortMode" defaultValue:@"manual"]);
}

+ (NSComparisonResult)compareTemplate:(NFTemplate *)a
                             toTemplate:(NFTemplate *)b
                               sortMode:(NFTemplateSortMode)sortMode {
    switch (sortMode) {
        case NFTemplateSortName:
            return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
        case NFTemplateSortCategory: {
            NSComparisonResult result = [a.category localizedCaseInsensitiveCompare:b.category];
            if (result != NSOrderedSame) {
                return result;
            }
            return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
        }
        case NFTemplateSortFileType: {
            NSComparisonResult result = [a.fileExtension localizedCaseInsensitiveCompare:b.fileExtension];
            if (result != NSOrderedSame) {
                return result;
            }
            return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
        }
        case NFTemplateSortLastUsed:
            if (!a.lastUsedAt && !b.lastUsedAt) {
                return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
            }
            if (!a.lastUsedAt) {
                return NSOrderedDescending;
            }
            if (!b.lastUsedAt) {
                return NSOrderedAscending;
            }
            return [b.lastUsedAt compare:a.lastUsedAt];
        case NFTemplateSortMostUsed:
            if (a.useCount == b.useCount) {
                return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
            }
            return a.useCount > b.useCount ? NSOrderedAscending : NSOrderedDescending;
        case NFTemplateSortManual:
        default:
            if (a.sortIndex != b.sortIndex) {
                return a.sortIndex < b.sortIndex ? NSOrderedAscending : NSOrderedDescending;
            }
            return [a.resolvedDisplayName localizedCaseInsensitiveCompare:b.resolvedDisplayName];
    }
}

+ (NSArray<NFTemplate *> *)orderedTemplatesForConfig:(NFConfig *)config favoritesFirst:(BOOL)favoritesFirst {
    return [self orderedTemplatesForConfig:config
                            favoritesFirst:favoritesFirst
                                  sortMode:[self sortModeForConfig:config]];
}

+ (NSArray<NFTemplate *> *)orderedTemplatesForConfig:(NFConfig *)config
                                      favoritesFirst:(BOOL)favoritesFirst
                                            sortMode:(NFTemplateSortMode)sortMode {
    NSArray<NFTemplate *> *enabled = config.enabledTemplates;
    return [enabled sortedArrayUsingComparator:^NSComparisonResult(NFTemplate *a, NFTemplate *b) {
        if (favoritesFirst && a.favorite != b.favorite) {
            return a.favorite ? NSOrderedAscending : NSOrderedDescending;
        }
        return [self compareTemplate:a toTemplate:b sortMode:sortMode];
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

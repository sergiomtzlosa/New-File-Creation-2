#import <Cocoa/Cocoa.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NFCTemplateFilter) {
    NFCTemplateFilterAll = 0,
    NFCTemplateFilterFavorites,
    NFCTemplateFilterRecent,
    NFCTemplateFilterCategory
};

@interface NFCTemplateGridViewController : NSViewController

@property (nonatomic, assign) NFCTemplateFilter filter;
@property (nonatomic, copy, nullable) NSString *categoryFilter;
@property (nonatomic, copy, nullable) NSString *searchQuery;
@property (nonatomic, assign) NFTemplateSortMode sortMode;

@property (nonatomic, readonly, nullable) NFTemplate *selectedTemplate;
@property (nonatomic, readonly, strong) NSSearchField *searchField;
@property (nonatomic, copy, nullable) void (^onCreate)(NFTemplate *template);
@property (nonatomic, copy, nullable) void (^onAddTemplates)(void);
@property (nonatomic, copy, nullable) void (^onSelectionChanged)(NFTemplate * _Nullable template);

- (void)reloadData;
- (void)selectTemplateWithIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END

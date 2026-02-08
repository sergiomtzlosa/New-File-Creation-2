#import <Foundation/Foundation.h>
#import "NFTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFConfig : NSObject

@property (nonatomic, assign) NSInteger schemaVersion;
@property (nonatomic, assign) NSInteger revision;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *settings;
@property (nonatomic, strong) NSMutableArray<NFTemplate *> *templates;
@property (nonatomic, strong) NSMutableArray<NSString *> *recentTemplateIDs;
@property (nonatomic, strong) NSMutableArray<NSString *> *recentFiles;

+ (instancetype)defaultConfig;
- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

- (nullable NFTemplate *)templateWithIdentifier:(NSString *)identifier;
- (nullable NFTemplate *)templateWithFileName:(NSString *)fileName;
- (NSArray<NFTemplate *> *)enabledTemplates;
- (NSArray<NFTemplate *> *)favoriteTemplates;
- (NSArray<NSString *> *)categories;
- (NSArray<NSString *> *)customCategories;
/// Adds a user-defined category. Returns NO when the name is blank or already exists.
- (BOOL)addCustomCategory:(NSString *)category;

- (id)settingForKey:(NSString *)key;
- (BOOL)boolSettingForKey:(NSString *)key defaultValue:(BOOL)defaultValue;
- (NSString *)stringSettingForKey:(NSString *)key defaultValue:(NSString *)defaultValue;
- (NSInteger)integerSettingForKey:(NSString *)key defaultValue:(NSInteger)defaultValue;
- (void)setSetting:(nullable id)value forKey:(NSString *)key;

- (void)recordUsageOfTemplate:(NFTemplate *)template;
- (void)addRecentFile:(NSString *)path;

@end

NS_ASSUME_NONNULL_END

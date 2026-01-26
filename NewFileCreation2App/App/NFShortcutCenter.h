#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFShortcutCenter : NSObject

+ (instancetype)sharedCenter;

@property (nonatomic, copy, nullable) void (^handler)(void);

/// Accepts strings such as "control+option+n", "command+shift+n", or "none".
- (BOOL)registerShortcut:(NSString *)shortcut error:(NSError **)error;
- (void)unregister;

+ (NSArray<NSString *> *)presetShortcuts;
+ (NSString *)displayNameForShortcut:(NSString *)shortcut;

@end

NS_ASSUME_NONNULL_END

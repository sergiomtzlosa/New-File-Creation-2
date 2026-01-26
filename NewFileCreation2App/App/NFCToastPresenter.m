#import "NFCToastPresenter.h"

@interface NFCToastActionTarget : NSObject
@property (nonatomic, copy, nullable) void (^block)(void);
+ (instancetype)sharedTarget;
- (void)invoke:(id)sender;
@end

@implementation NFCToastPresenter

+ (void)showMessage:(NSString *)message inWindow:(NSWindow *)window {
    [self showMessage:message inWindow:window actionTitle:nil action:nil];
}

+ (void)showMessage:(NSString *)message
           inWindow:(NSWindow *)window
        actionTitle:(NSString *)actionTitle
             action:(void (^)(void))action {
    if (!window || message.length == 0) {
        return;
    }
    NSView *contentView = window.contentView;
    if (!contentView) {
        return;
    }

    NSVisualEffectView *toast = [[NSVisualEffectView alloc] init];
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.material = NSVisualEffectMaterialHUDWindow;
    toast.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    toast.state = NSVisualEffectStateActive;
    toast.wantsLayer = YES;
    toast.layer.cornerRadius = 12;
    toast.layer.masksToBounds = YES;
    toast.alphaValue = 0;

    NSTextField *label = [NSTextField labelWithString:message];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    label.textColor = NSColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.maximumNumberOfLines = 2;
    [toast addSubview:label];

    NSButton *button = nil;
    if (actionTitle.length > 0 && action) {
        button = [NSButton buttonWithTitle:actionTitle target:nil action:nil];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.bezelStyle = NSBezelStyleInline;
        button.controlSize = NSControlSizeSmall;
        button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
        button.target = [NFCToastActionTarget sharedTarget];
        button.action = @selector(invoke:);
        [NFCToastActionTarget sharedTarget].block = action;
        [toast addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-14],
            [button.centerYAnchor constraintEqualToAnchor:toast.centerYAnchor]
        ]];
        [NSLayoutConstraint activateConstraints:@[
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:button.leadingAnchor constant:-10]
        ]];
    }

    [contentView addSubview:toast];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:toast.centerYAnchor],
        [toast.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [toast.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24],
        [toast.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-48]
    ]];
    if (!button) {
        [label.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-16].active = YES;
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        toast.animator.alphaValue = 1;
    } completionHandler:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.25;
                toast.animator.alphaValue = 0;
            } completionHandler:^{
                [toast removeFromSuperview];
            }];
        });
    }];
}

@end

@implementation NFCToastActionTarget
+ (instancetype)sharedTarget {
    static NFCToastActionTarget *target = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [[self alloc] init];
    });
    return target;
}
- (void)invoke:(id)sender {
    if (self.block) {
        void (^block)(void) = self.block;
        self.block = nil;
        block();
    }
}
@end

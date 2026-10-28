//
//  DuoPad.h
//  Artemide Duo for iOS
//
//  Controller navigation outside the stream (host page, app list, settings):
//  D-pad / left stick move, A/B/X/Y, LB/RB, Menu (START) and Options (SELECT) as discrete
//  key presses with key repeat, delivered to the topmost screen.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DuoPadKey) {
    DuoPadUp, DuoPadDown, DuoPadLeft, DuoPadRight,
    DuoPadA, DuoPadB, DuoPadX, DuoPadY,
    DuoPadLB, DuoPadRB, DuoPadStart, DuoPadSelect,
};

@protocol DuoPadTarget <NSObject>
/// Returns YES when the key was used.
- (BOOL)duoPadKey:(DuoPadKey)key;
@end

extern NSString* const DuoPadChangedNotification;

@interface DuoPad : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) BOOL hasGamepad;
/// Show the focus ring (a controller is connected or the hardware keyboard was used).
@property (nonatomic, readonly) BOOL focusVisible;
/// Hardware keyboard (Magic Keyboard): arrows, Return, Esc, Tab … act like the controller.
- (void)keyboard:(DuoPadKey)key;
/// Key commands for a screen; their action must call -keyboard: with propertyList as key.
+ (NSArray<UIKeyCommand*>*)keyCommandsWithAction:(SEL)action;
/// The screen in front gets the keys (last pushed).
- (void)push:(id<DuoPadTarget>)target;
- (void)remove:(id<DuoPadTarget>)target;
/// Installs our handlers on all controllers (call when no stream is running).
- (void)attach;
/// Removes them (the stream installs its own).
- (void)detach;
@end

NS_ASSUME_NONNULL_END

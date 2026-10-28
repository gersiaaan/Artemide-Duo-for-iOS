//
//  DuoStreamMenu.h
//  Artemide Duo for iOS
//
//  In-stream floating button (draggable) and the quick menu it opens:
//  keyboard, performance overlay, controller as mouse, disconnect, quit.
//

#import <UIKit/UIKit.h>
#import "DuoPad.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DuoStreamMenuDelegate <NSObject>
- (void)duoMenuKeyboard;
- (void)duoMenuTogglePerf;
- (BOOL)duoMenuPerfOn;
- (void)duoMenuToggleMouse;
- (BOOL)duoMenuMouseOn;
- (BOOL)duoMenuMouseAvailable;
- (void)duoMenuDisconnect;
- (void)duoMenuQuit;
@end

@interface DuoStreamMenu : UIView <DuoPadTarget>
@property (nonatomic, weak, nullable) id<DuoStreamMenuDelegate> delegate;
- (instancetype)initWithFrame:(CGRect)frame showButton:(BOOL)showButton;
@property (nonatomic, readonly) BOOL menuOpen;
/// Menu opened / closed (the stream routes the controller to the menu while it's open).
@property (nonatomic, copy, nullable) void (^onOpenChange)(BOOL open);
- (void)openMenu;
- (void)closeMenu;
@end

NS_ASSUME_NONNULL_END

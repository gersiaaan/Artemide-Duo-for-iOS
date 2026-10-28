//
//  DuoAppsView.h
//  Artemide Duo for iOS
//
//  App list of one host (port of the Android DuoAppsView, laid out after StreamLight's apps
//  page): tabs ALL / GAMES / APPS, "Last played" and favourites on top, a big cover with play
//  time and sessions, Open and Options. Touch: tap a row to select it, tap it again (or Open)
//  to start. Controller: D-pad, A start, X favourite, Y settings, View options, Menu quit all,
//  LB/RB tabs, B back.
//

#import <UIKit/UIKit.h>
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "DuoPad.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DuoAppsDelegate <NSObject>
- (void)duoStartApp:(TemporaryApp*)app view:(UIView*)view;
- (void)duoAppOptions:(TemporaryApp*)app view:(UIView*)view;
- (void)duoQuitAll:(TemporaryHost*)host;
- (void)duoOpenSettings;
- (void)duoBackToHosts;
@end

@interface DuoAppsView : UIView <DuoPadTarget>
@property (nonatomic, weak, nullable) id<DuoAppsDelegate> delegate;
@property (nonatomic, readonly, nullable) TemporaryHost* host;
- (void)showApps:(NSArray<TemporaryApp*>*)apps host:(TemporaryHost*)host cache:(NSCache*)cache;
/// Box art arrived / state changed.
- (void)refresh;
@end

NS_ASSUME_NONNULL_END

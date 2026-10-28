//
//  DuoHomeView.h
//  Artemide Duo for iOS
//
//  The Artemide Duo host page and app list, drawn on top of Moonlight's main screen.
//  MainFrameViewController keeps all the logic (discovery, pairing, launching); this view
//  only shows the data and reports taps back through the delegate.
//

#import <UIKit/UIKit.h>
#import "TemporaryHost.h"
#import "TemporaryApp.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DuoHomeDelegate <NSObject>
- (void)duoOpenHost:(TemporaryHost*)host view:(UIView*)view;
- (void)duoHostOptions:(TemporaryHost*)host view:(UIView*)view;
- (void)duoAddHost;
- (void)duoOpenApp:(TemporaryApp*)app view:(UIView*)view;
- (void)duoAppOptions:(TemporaryApp*)app view:(UIView*)view;
- (void)duoOpenSettings;
- (void)duoBackToHosts;
- (void)duoQuitAll:(TemporaryHost*)host;
@end

@interface DuoHomeView : UIView
@property (nonatomic, weak, nullable) id<DuoHomeDelegate> delegate;
@property (nonatomic, readonly) BOOL showingApps;

/// Host page with these hosts (any order).
- (void)setHosts:(NSArray<TemporaryHost*>*)hosts;
- (void)showHostPage;
/// App list of one host; box art comes from the cache (keys are the apps).
- (void)showApps:(NSArray<TemporaryApp*>*)apps host:(TemporaryHost*)host cache:(NSCache*)cache;
/// Box art arrived / running state changed: redraw the current page.
- (void)refresh;
@end

NS_ASSUME_NONNULL_END

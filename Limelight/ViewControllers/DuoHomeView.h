//
//  DuoHomeView.h
//  Artemide Duo for iOS
//
//  Start screen of Artemide Duo (port of the Android DuoHomeView, laid out after StreamLight's
//  host page): one host at a time (LB/RB or the chips switch), a big host card, the last played
//  app with "Play again", and buttons along the bottom. Touch and controller.
//
//  MainFrameViewController keeps all the logic (discovery, pairing, launching); this view only
//  shows the data and reports actions back through the delegate.
//

#import <UIKit/UIKit.h>
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "DuoPad.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DuoHomeDelegate <NSObject>
- (void)duoOpenHost:(TemporaryHost*)host view:(UIView*)view;
- (void)duoHostOptions:(TemporaryHost*)host view:(UIView*)view;
- (void)duoWakeHost:(TemporaryHost*)host;
- (void)duoAddHost;
- (void)duoRefreshHosts;
- (void)duoPlayAgain:(TemporaryHost*)host appId:(NSString*)appId;
- (void)duoQuitAll:(TemporaryHost*)host;
- (void)duoOpenSettings;
/// Box art of an app of this host, if it is cached.
- (nullable UIImage*)duoCoverForHost:(TemporaryHost*)host appId:(NSString*)appId;
@end

@interface DuoHomeView : UIView <DuoPadTarget>
@property (nonatomic, weak, nullable) id<DuoHomeDelegate> delegate;
- (void)setHosts:(NSArray<TemporaryHost*>*)hosts;
/// The host whose card is shown (nil on the "Add a host" tab).
- (nullable TemporaryHost*)selectedHost;
/// Re-reads the last played app etc. (after a stream, settings, box art).
- (void)refresh;
@end

NS_ASSUME_NONNULL_END

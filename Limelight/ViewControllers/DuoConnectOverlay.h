//
//  DuoConnectOverlay.h
//  Artemide Duo for iOS
//
//  The Artemide Duo stream-start screen: cover, name, connection stage and a progress bar.
//  It fades out as soon as the first video frame is on screen.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DuoConnectOverlay : UIView
- (instancetype)initWithFrame:(CGRect)frame app:(NSString*)app host:(nullable NSString*)host cover:(nullable UIImage*)cover;
/// One connection stage started (moonlight-common-c stage names).
- (void)stageStarting:(NSString*)stage;
/// The connection is up; video follows.
- (void)connected;
/// First frame is on screen: zoom into the stream and remove the overlay.
- (void)dismiss;
@end

NS_ASSUME_NONNULL_END

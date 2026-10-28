//
//  DuoConnectOverlay.h
//  Artemide Duo for iOS
//
//  Stream start screen (port of the Android DuoConnectOverlay): the app's cover pops in over
//  the waves with a pulsing accent glow, "Connecting to <PC>" and the current stage. When the
//  stream is up the cover zooms through the screen and the overlay dissolves into the video.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DuoConnectOverlay : UIView
- (instancetype)initWithFrame:(CGRect)frame app:(NSString*)app host:(nullable NSString*)host cover:(nullable UIImage*)cover;
/// One connection stage started (moonlight-common-c stage name).
- (void)stageStarting:(NSString*)stage;
- (void)connected;
/// connected = fill to 100 %, then the cover glides towards you and dissolves into the stream.
- (void)dismiss:(BOOL)connected;
@end

NS_ASSUME_NONNULL_END

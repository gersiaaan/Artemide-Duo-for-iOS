//
//  DuoMetalRenderer.h
//  Artemide Duo for iOS
//
//  Optional video path with Apple's MetalFX spatial upscaler: VideoToolbox decodes the frames,
//  a small Metal kernel turns them into RGB and MetalFX scales them to the full screen.
//  Used only when "MetalFX upscaling" is on, the device supports it and the stream is SDR.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface DuoMetalRenderer : NSObject
/// nil when Metal / MetalFX can't be set up.
- (nullable instancetype)initWithLayerFrame:(CGRect)frame inView:(UIView*)view;
@property (nonatomic, readonly) CALayer* layer;
- (void)setLayerFrame:(CGRect)frame;
/// Decodes and shows one frame. Returns NO if decoding failed (caller asks for an IDR frame).
- (BOOL)decode:(CMSampleBufferRef)sample format:(CMVideoFormatDescriptionRef)format;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

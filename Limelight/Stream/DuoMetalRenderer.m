//
//  DuoMetalRenderer.m
//  Artemide Duo for iOS
//

#import "DuoMetalRenderer.h"

@import Metal;
#include <dlfcn.h>

// MetalFX is loaded at runtime (not linked), so the app also starts on systems / devices
// without it. Only the bits we use are declared here.
@protocol DuoFXScaler <NSObject>
@property (nonatomic, readonly) MTLTextureUsage colorTextureUsage;
@property (nonatomic, readonly) MTLTextureUsage outputTextureUsage;
@property (nonatomic) NSUInteger inputContentWidth;
@property (nonatomic) NSUInteger inputContentHeight;
@property (nonatomic, retain, nullable) id<MTLTexture> colorTexture;
@property (nonatomic, retain, nullable) id<MTLTexture> outputTexture;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
@end

@protocol DuoFXDescriptor <NSObject>
+ (BOOL)supportsDevice:(id<MTLDevice>)device;
- (nullable id<DuoFXScaler>)newSpatialScalerWithDevice:(id<MTLDevice>)device;
@end

static Class DuoFXDescriptorClass(void) {
    static Class c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(iOS 16.0, *)) {
            if (dlopen("/System/Library/Frameworks/MetalFX.framework/MetalFX", RTLD_LAZY) != NULL) {
                c = NSClassFromString(@"MTLFXSpatialScalerDescriptor");
            }
        }
    });
    return c;
}
@import QuartzCore;
@import VideoToolbox;
@import CoreVideo;

static NSString* const kShader =
@"#include <metal_stdlib>\n"
 "using namespace metal;\n"
 "kernel void duoNv12(texture2d<float, access::read> yTex [[texture(0)]],\n"
 "                    texture2d<float, access::read> cTex [[texture(1)]],\n"
 "                    texture2d<float, access::write> outTex [[texture(2)]],\n"
 "                    constant float4& m [[buffer(0)]],\n"
 "                    uint2 gid [[thread_position_in_grid]]) {\n"
 "    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;\n"
 "    float y = (yTex.read(gid).r - 16.0 / 255.0) * (255.0 / 219.0);\n"
 "    float2 c = (cTex.read(gid / 2).rg - 128.0 / 255.0) * (255.0 / 224.0);\n"
 "    float r = y + m.x * c.y;\n"
 "    float g = y - m.y * c.x - m.z * c.y;\n"
 "    float b = y + m.w * c.x;\n"
 "    outTex.write(float4(saturate(float3(r, g, b)), 1.0), gid);\n"
 "}\n";

@interface DuoMetalRenderer ()
- (void)draw:(CVPixelBufferRef)pb;
@end

@implementation DuoMetalRenderer {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _queue;
    id<MTLComputePipelineState> _convert;
    CAMetalLayer* _metal;
    CVMetalTextureCacheRef _cache;
    VTDecompressionSessionRef _session;
    CMVideoFormatDescriptionRef _sessionFormat;
    id<MTLTexture> _rgb;
    id<MTLTexture> _scaled;
    id _scaler;          // id<MTLFXSpatialScaler>
    CGSize _scalerIn, _scalerOut;
    dispatch_semaphore_t _inFlight;
    BOOL _stopped;
}

- (instancetype)initWithLayerFrame:(CGRect)frame inView:(UIView*)view {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (![DuoMetalRenderer supported]) {
        return nil;
    }
    _device = MTLCreateSystemDefaultDevice();
    NSError* err = nil;
    id<MTLLibrary> lib = [_device newLibraryWithSource:kShader options:nil error:&err];
    id<MTLFunction> fn = [lib newFunctionWithName:@"duoNv12"];
    if (fn == nil) {
        NSLog(@"DuoMetal: shader failed: %@", err);
        return nil;
    }
    _convert = [_device newComputePipelineStateWithFunction:fn error:&err];
    if (_convert == nil) {
        return nil;
    }
    _queue = [_device newCommandQueue];
    if (CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, _device, NULL, &_cache) != kCVReturnSuccess) {
        return nil;
    }
    _metal = [CAMetalLayer layer];
    _metal.device = _device;
    _metal.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metal.framebufferOnly = NO;
    _metal.contentsScale = view.window.screen.scale ?: [UIScreen mainScreen].scale;
    _metal.maximumDrawableCount = 3;
    _metal.allowsNextDrawableTimeout = YES;
    _metal.backgroundColor = [UIColor blackColor].CGColor;
    [view.layer addSublayer:_metal];
    [self setLayerFrame:frame];
    _inFlight = dispatch_semaphore_create(2);
    return self;
}

+ (BOOL)supported {
    static BOOL ok, checked;
    if (!checked) {
        checked = YES;
        Class<DuoFXDescriptor> c = (Class<DuoFXDescriptor>)DuoFXDescriptorClass();
        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        ok = c != nil && dev != nil && [c respondsToSelector:@selector(supportsDevice:)] && [c supportsDevice:dev];
    }
    return ok;
}

- (CALayer*)layer {
    return _metal;
}

- (void)setLayerFrame:(CGRect)frame {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _metal.frame = frame;
    _metal.drawableSize = CGSizeMake(frame.size.width * _metal.contentsScale, frame.size.height * _metal.contentsScale);
    [CATransaction commit];
}

static void DuoDecoded(void* refcon, void* frameRefcon, OSStatus status, VTDecodeInfoFlags flags,
                       CVImageBufferRef image, CMTime pts, CMTime duration) {
    if (status != noErr || image == NULL) {
        return;
    }
    DuoMetalRenderer* r = (__bridge DuoMetalRenderer*)refcon;
    [r draw:image];
}

- (BOOL)makeSession:(CMVideoFormatDescriptionRef)format {
    if (_session != NULL) {
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (_sessionFormat != NULL) {
        CFRelease(_sessionFormat);
        _sessionFormat = NULL;
    }
    NSDictionary* attrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferMetalCompatibilityKey: @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    VTDecompressionOutputCallbackRecord cb = {DuoDecoded, (__bridge void*)self};
    OSStatus st = VTDecompressionSessionCreate(kCFAllocatorDefault, format, NULL, (__bridge CFDictionaryRef)attrs, &cb, &_session);
    if (st != noErr) {
        NSLog(@"DuoMetal: VTDecompressionSessionCreate %d", (int)st);
        _session = NULL;
        return NO;
    }
    VTSessionSetProperty(_session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    _sessionFormat = (CMVideoFormatDescriptionRef)CFRetain(format);
    return YES;
}

- (BOOL)decode:(CMSampleBufferRef)sample format:(CMVideoFormatDescriptionRef)format {
    if (_stopped) {
        return YES;
    }
    if (_session == NULL || _sessionFormat == NULL || !CMFormatDescriptionEqual(format, _sessionFormat)) {
        if (![self makeSession:format]) {
            return NO;
        }
    }
    VTDecodeInfoFlags info = 0;
    OSStatus st = VTDecompressionSessionDecodeFrame(_session, sample, kVTDecodeFrame_EnableAsynchronousDecompression, NULL, &info);
    if (st != noErr) {
        NSLog(@"DuoMetal: decode %d", (int)st);
        if (st == kVTInvalidSessionErr) {
            [self makeSession:format];
        }
        return NO;
    }
    return YES;
}

- (id<MTLTexture>)plane:(CVPixelBufferRef)pb index:(size_t)i format:(MTLPixelFormat)fmt ref:(CVMetalTextureRef*)ref {
    size_t w = CVPixelBufferGetWidthOfPlane(pb, i), h = CVPixelBufferGetHeightOfPlane(pb, i);
    if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _cache, pb, NULL, fmt, w, h, i, ref) != kCVReturnSuccess) {
        return nil;
    }
    return CVMetalTextureGetTexture(*ref);
}

- (void)draw:(CVPixelBufferRef)pb {
    if (_stopped) {
        return;
    }
    // Never queue up: if two frames are still in flight, this one is dropped (lowest latency).
    if (dispatch_semaphore_wait(_inFlight, DISPATCH_TIME_NOW) != 0) {
        return;
    }
    CVMetalTextureRef yRef = NULL, cRef = NULL;
    id<MTLTexture> y = [self plane:pb index:0 format:MTLPixelFormatR8Unorm ref:&yRef];
    id<MTLTexture> c = [self plane:pb index:1 format:MTLPixelFormatRG8Unorm ref:&cRef];
    if (y == nil || c == nil) {
        if (yRef) CFRelease(yRef);
        if (cRef) CFRelease(cRef);
        dispatch_semaphore_signal(_inFlight);
        return;
    }
    size_t w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb);
    id<CAMetalDrawable> drawable = [_metal nextDrawable];
    if (drawable == nil) {
        CFRelease(yRef);
        CFRelease(cRef);
        dispatch_semaphore_signal(_inFlight);
        return;
    }
    CGSize out = CGSizeMake(drawable.texture.width, drawable.texture.height);
    [self prepareIn:CGSizeMake(w, h) out:out];
    if (_rgb == nil) {
        CFRelease(yRef);
        CFRelease(cRef);
        dispatch_semaphore_signal(_inFlight);
        return;
    }

    // BT.709 or BT.601 (limited range), as the encoder tagged it.
    float m[4] = {1.402f, 0.344136f, 0.714136f, 1.772f};
    CFTypeRef matrix = CVBufferCopyAttachment(pb, kCVImageBufferYCbCrMatrixKey, NULL);
    if (matrix != NULL) {
        if (CFEqual(matrix, kCVImageBufferYCbCrMatrix_ITU_R_709_2)) {
            m[0] = 1.5748f; m[1] = 0.1873f; m[2] = 0.4681f; m[3] = 1.8556f;
        }
        CFRelease(matrix);
    }

    id<MTLCommandBuffer> cmd = [_queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
    [enc setComputePipelineState:_convert];
    [enc setTexture:y atIndex:0];
    [enc setTexture:c atIndex:1];
    [enc setTexture:_rgb atIndex:2];
    [enc setBytes:m length:sizeof(m) atIndex:0];
    MTLSize tg = MTLSizeMake(16, 16, 1);
    MTLSize groups = MTLSizeMake((w + 15) / 16, (h + 15) / 16, 1);
    [enc dispatchThreadgroups:groups threadsPerThreadgroup:tg];
    [enc endEncoding];

    id<MTLTexture> result = _rgb;
    if (_scaler != nil && _scaled != nil) {
        id<DuoFXScaler> sc = _scaler;
        sc.colorTexture = _rgb;
        sc.outputTexture = _scaled;
        sc.inputContentWidth = w;
        sc.inputContentHeight = h;
        [sc encodeToCommandBuffer:cmd];
        result = _scaled;
    }
    id<MTLBlitCommandEncoder> blit = [cmd blitCommandEncoder];
    NSUInteger bw = MIN(result.width, drawable.texture.width), bh = MIN(result.height, drawable.texture.height);
    [blit copyFromTexture:result sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(bw, bh, 1)
                toTexture:drawable.texture destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    [cmd presentDrawable:drawable];
    dispatch_semaphore_t sem = _inFlight;
    [cmd addCompletedHandler:^(id<MTLCommandBuffer> b) {
        CFRelease(yRef);
        CFRelease(cRef);
        dispatch_semaphore_signal(sem);
    }];
    [cmd commit];
}

- (void)prepareIn:(CGSize)in out:(CGSize)out {
    if (_rgb == nil || _rgb.width != (NSUInteger)in.width || _rgb.height != (NSUInteger)in.height ||
        !CGSizeEqualToSize(_scalerOut, out)) {
        _scaler = nil;
        _scaled = nil;
        MTLTextureUsage colorUsage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
        BOOL upscale = out.width > in.width + 1 || out.height > in.height + 1;
        Class c = DuoFXDescriptorClass();
        if (upscale && c != nil) {
            id d = [[c alloc] init];
            [d setValue:@((NSUInteger)in.width) forKey:@"inputWidth"];
            [d setValue:@((NSUInteger)in.height) forKey:@"inputHeight"];
            [d setValue:@((NSUInteger)out.width) forKey:@"outputWidth"];
            [d setValue:@((NSUInteger)out.height) forKey:@"outputHeight"];
            [d setValue:@(MTLPixelFormatBGRA8Unorm) forKey:@"colorTextureFormat"];
            [d setValue:@(MTLPixelFormatBGRA8Unorm) forKey:@"outputTextureFormat"];
            id<DuoFXScaler> sc = [(id<DuoFXDescriptor>)d newSpatialScalerWithDevice:_device];
            if (sc != nil) {
                _scaler = sc;
                colorUsage |= sc.colorTextureUsage;
                MTLTextureDescriptor* od = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                              width:(NSUInteger)out.width height:(NSUInteger)out.height mipmapped:NO];
                od.usage = sc.outputTextureUsage | MTLTextureUsageShaderRead;
                od.storageMode = MTLStorageModePrivate;
                _scaled = [_device newTextureWithDescriptor:od];
            }
        }
        MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                      width:(NSUInteger)in.width height:(NSUInteger)in.height mipmapped:NO];
        td.usage = colorUsage;
        td.storageMode = MTLStorageModePrivate;
        _rgb = [_device newTextureWithDescriptor:td];
        _scalerIn = in;
        _scalerOut = out;
    }
}

- (void)stop {
    _stopped = YES;
    if (_session != NULL) {
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (_sessionFormat != NULL) {
        CFRelease(_sessionFormat);
        _sessionFormat = NULL;
    }
}

- (void)dealloc {
    [self stop];
    if (_cache != NULL) {
        CFRelease(_cache);
    }
    [_metal removeFromSuperlayer];
}

@end

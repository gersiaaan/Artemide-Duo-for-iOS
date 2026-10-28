//
//  DuoWavesView.m
//  Artemide Duo for iOS
//

#import "DuoWavesView.h"
#import "DuoSupport.h"

#define DUO_LAYERS 5

@implementation DuoWavesView {
    CAGradientLayer* _floor;
    CAShapeLayer* _fill[DUO_LAYERS];
    CAShapeLayer* _crest[DUO_LAYERS];
    CADisplayLink* _link;
    CFTimeInterval _start;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        _floor = [CAGradientLayer layer];
        _floor.colors = @[(id)[DuoTheme hex:0x0B0D10].CGColor, (id)[DuoTheme hex:0x0E1E24].CGColor, (id)[DuoTheme hex:0x0F3A44].CGColor];
        _floor.locations = @[@0.0, @0.62, @1.0];
        [self.layer addSublayer:_floor];
        for (int i = 0; i < DUO_LAYERS; i++) {
            _fill[i] = [CAShapeLayer layer];
            _crest[i] = [CAShapeLayer layer];
            _crest[i].fillColor = [UIColor clearColor].CGColor;
            _crest[i].lineWidth = 1.2;
            [self.layer addSublayer:_fill[i]];
            [self.layer addSublayer:_crest[i]];
        }
        [self applyColors];
        _start = CACurrentMediaTime();
    }
    return self;
}

- (void)setOverlay:(BOOL)overlay {
    _overlay = overlay;
    _floor.hidden = overlay;
    [self applyColors];
}

- (void)applyColors {
    UIColor* accent = [DuoTheme accent];
    for (int i = 0; i < DUO_LAYERS; i++) {
        CGFloat depth = i / (CGFloat)(DUO_LAYERS - 1);
        if (_overlay) {
            _fill[i].fillColor = [UIColor colorWithWhite:1.0 alpha:0.006 + 0.006 * depth].CGColor;
            _crest[i].strokeColor = [UIColor colorWithWhite:1.0 alpha:0.05 + 0.06 * depth].CGColor;
        } else {
            _fill[i].fillColor = [accent colorWithAlphaComponent:0.022 + 0.022 * depth].CGColor;
            _crest[i].strokeColor = [accent colorWithAlphaComponent:0.07 + 0.13 * depth].CGColor;
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _floor.frame = self.bounds;
    for (int i = 0; i < DUO_LAYERS; i++) {
        _fill[i].frame = self.bounds;
        _crest[i].frame = self.bounds;
    }
    [CATransaction commit];
    [self step];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_link invalidate];
    _link = nil;
    if (self.window != nil) {
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(step)];
        if (@available(iOS 15.0, *)) {
            _link.preferredFrameRateRange = CAFrameRateRangeMake(20, 30, 30);
        } else {
            _link.preferredFramesPerSecond = 30;
        }
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)step {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (w <= 0 || h <= 0) {
        return;
    }
    CGFloat t = (CGFloat)(CACurrentMediaTime() - _start);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (int i = 0; i < DUO_LAYERS; i++) {
        CGFloat depth = i / (CGFloat)(DUO_LAYERS - 1);
        CGFloat level = h * (0.42 + 0.11 * i);
        CGFloat amp = h * (0.018 + 0.010 * (DUO_LAYERS - i));
        CGFloat wave = w * (0.9 + 0.35 * depth);
        CGFloat speed = 0.05 + 0.02 * i;
        CGFloat swell = h * 0.012 * sin(t * 0.21 + i * 1.3);
        UIBezierPath* crest = [UIBezierPath bezierPath];
        for (CGFloat x = -8; x <= w + 8; x += 8) {
            CGFloat y = level + swell + amp * sin((x / wave) * 2 * M_PI + t * speed * 2 * M_PI + i * 0.9);
            if (x < -7) {
                [crest moveToPoint:CGPointMake(x, y)];
            } else {
                [crest addLineToPoint:CGPointMake(x, y)];
            }
        }
        UIBezierPath* body = [crest copy];
        [body addLineToPoint:CGPointMake(w + 8, h + 8)];
        [body addLineToPoint:CGPointMake(-8, h + 8)];
        [body closePath];
        _crest[i].path = crest.CGPath;
        _fill[i].path = body.CGPath;
    }
    [CATransaction commit];
}

- (void)dealloc {
    [_link invalidate];
}

@end

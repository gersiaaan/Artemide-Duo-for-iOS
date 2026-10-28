//
//  DuoWavesView.m
//  Artemide Duo for iOS
//

#import "DuoWavesView.h"
#import "DuoSupport.h"

#define DUO_LAYERS 5
static const CGFloat kSpeed = 1.1;          // 10 % quicker than StreamLight's drift
static const CFTimeInterval kRise = 1.8;    // s

@implementation DuoWavesView {
    CAGradientLayer* _floor;
    CAShapeLayer* _fill[DUO_LAYERS];
    CAShapeLayer* _crest[DUO_LAYERS];
    CGFloat _level[DUO_LAYERS], _amp[DUO_LAYERS], _wave[DUO_LAYERS], _travel[DUO_LAYERS],
            _swellAmp[DUO_LAYERS], _swellPeriod[DUO_LAYERS], _phase[DUO_LAYERS];
    CGSize _builtFor;
    CADisplayLink* _link;
    CFTimeInterval _last;
    CGFloat _t;          // flow time in ms at speed 1
    CGFloat _rise;       // 0 = below the edge, 1 = in place
    BOOL _riseStarted;
    CFTimeInterval _riseStart;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame rise:NO];
}

- (instancetype)initWithFrame:(CGRect)frame rise:(BOOL)riseOnStart {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        _floor = [CAGradientLayer layer];
        UIColor* accent = [DuoTheme accent];
        _floor.colors = @[(id)[DuoTheme floor].CGColor,
                          (id)[DuoTheme mix:accent with:[DuoTheme floor] k:0.07].CGColor,
                          (id)[DuoTheme mix:accent with:[DuoTheme floor] k:0.20].CGColor];
        _floor.locations = @[@0.0, @0.7, @1.0];
        [self.layer addSublayer:_floor];
        for (int i = 0; i < DUO_LAYERS; i++) {
            _fill[i] = [CAShapeLayer layer];
            _crest[i] = [CAShapeLayer layer];
            _crest[i].fillColor = [UIColor clearColor].CGColor;
            _crest[i].lineJoin = kCALineJoinRound;
            _fill[i].anchorPoint = CGPointZero;
            _crest[i].anchorPoint = CGPointZero;
            [self.layer addSublayer:_fill[i]];
            [self.layer addSublayer:_crest[i]];
        }
        _rise = riseOnStart ? 0 : 1;
        [self applyColors];
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
    UIColor* light = [DuoTheme mix:[UIColor whiteColor] with:accent k:0.55];
    for (int i = 0; i < DUO_LAYERS; i++) {
        CGFloat depth = i / (CGFloat)(DUO_LAYERS - 1);
        CGFloat fa = 0.022 + 0.022 * depth, ca = 0.07 + 0.13 * depth;
        if (_overlay) {
            _fill[i].fillColor = [light colorWithAlphaComponent:fa * 0.10].CGColor;
            _crest[i].strokeColor = [light colorWithAlphaComponent:MIN(0.22, ca * 0.8 + 0.03)].CGColor;
        } else {
            _fill[i].fillColor = [accent colorWithAlphaComponent:fa].CGColor;
            _crest[i].strokeColor = [accent colorWithAlphaComponent:ca].CGColor;
        }
    }
}

- (void)build {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    _builtFor = self.bounds.size;
    CGFloat u = MAX(w, h) / 1280.0;
    for (int i = 0; i < DUO_LAYERS; i++) {
        CGFloat depth = i / (CGFloat)(DUO_LAYERS - 1);
        _level[i] = h * (0.25 + 0.53 * depth);
        _amp[i] = (12 + 22 * depth) * u;
        _wave[i] = (720 + 780 * depth) * u;
        _travel[i] = 34000 - 18000 * depth;
        _swellAmp[i] = (4 + 6 * depth) * u;
        _swellPeriod[i] = 11000 + 2300 * i;
        _phase[i] = i * 1.7;
        CGFloat width = w + _wave[i];
        CGFloat below = _amp[i] + _swellAmp[i] + 8 * u;
        CGFloat height = h - _level[i] + _amp[i] + below;
        UIBezierPath* c = [UIBezierPath bezierPath];
        CGFloat step = MAX(6, 10 * u);
        int n = (int)ceil(width / step);
        for (int k = 0; k <= n; k++) {
            CGFloat px = k * step;
            double a = px / _wave[i] * 2 * M_PI;
            CGFloat py = _amp[i] * (1 - 0.72 * sin(a + _phase[i]) - 0.28 * sin(2 * a + _phase[i] * 2.3));
            if (k == 0) {
                [c moveToPoint:CGPointMake(px, py)];
            } else {
                [c addLineToPoint:CGPointMake(px, py)];
            }
        }
        UIBezierPath* b = [c copy];
        [b addLineToPoint:CGPointMake(width, height)];
        [b addLineToPoint:CGPointMake(0, height)];
        [b closePath];
        _crest[i].path = c.CGPath;
        _fill[i].path = b.CGPath;
        _crest[i].lineWidth = MAX(1, 1.5 * u);
        _crest[i].bounds = CGRectMake(0, 0, width, height);
        _fill[i].bounds = CGRectMake(0, 0, width, height);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _floor.frame = self.bounds;
    if (!CGSizeEqualToSize(_builtFor, self.bounds.size) && self.bounds.size.width > 0) {
        [self build];
    }
    [CATransaction commit];
    [self place];
}

static CGFloat DuoEaseOut(CGFloat k) {
    return 1 - (1 - k) * (1 - k) * (1 - k);
}

- (void)place {
    CGFloat h = self.bounds.size.height;
    if (h <= 0 || _crest[0].path == NULL) {
        return;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (int i = 0; i < DUO_LAYERS; i++) {
        CGFloat depth = i / (CGFloat)(DUO_LAYERS - 1);
        CGFloat x = -_wave[i] + _wave[i] * fmod(_t / _travel[i] + i * 0.37, 1.0);
        CGFloat riseK = MIN(1, MAX(0, _rise * 1.6 - depth * 0.6));
        CGFloat y = _level[i] - _amp[i]
            + _swellAmp[i] * sin(_t / _swellPeriod[i] * 2 * M_PI + _phase[i])
            + (h - _level[i] + _amp[i] + _swellAmp[i]) * (1 - DuoEaseOut(riseK));
        _fill[i].position = CGPointMake(x, y);
        _crest[i].position = CGPointMake(x, y);
    }
    [CATransaction commit];
}

- (void)step:(CADisplayLink*)link {
    CFTimeInterval now = link.timestamp;
    if (_last != 0) {
        _t += MIN(now - _last, 0.1) * 1000.0 * kSpeed;
    }
    _last = now;
    if (_rise < 1) {
        if (!_riseStarted) {
            _riseStarted = YES;
            _riseStart = now;
        }
        _rise = MIN(1, (now - _riseStart) / kRise);
    }
    [self place];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_link invalidate];
    _link = nil;
    _last = 0;
    if (self.window != nil) {
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
        _link.preferredFrameRateRange = CAFrameRateRangeMake(30, 60, 60);
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    _link.paused = hidden;
    _last = 0;
}

- (void)removeFromSuperview {
    [_link invalidate];
    _link = nil;
    [super removeFromSuperview];
}

@end

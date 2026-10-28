//
//  DuoConnectOverlay.m
//  Artemide Duo for iOS
//

#import "DuoConnectOverlay.h"
#import "DuoSupport.h"
#import "DuoWavesView.h"

static const NSInteger kStageCount = 11; // moonlight-common-c connection stages

@implementation DuoConnectOverlay {
    CGFloat d;
    UIView* _coverBox;
    CAGradientLayer* _coverBg;
    UIView* _glow;
    UILabel* _stage;
    UIView* _bar;
    UILabel* _percent;
    CGFloat _trackW;
    CADisplayLink* _link;
    BOOL _gone;
    // Progress 0..1: shown glides towards the target; a slow creep keeps it alive
    // while a step takes long (app launch on the PC).
    CGFloat _shown, _target, _ceiling;
    NSInteger _stages;
}

- (instancetype)initWithFrame:(CGRect)frame app:(NSString*)app host:(NSString*)host cover:(UIImage*)cover {
    self = [super initWithFrame:frame];
    if (self) {
        d = [DuoTheme scale];
        UIColor* accent = [DuoTheme accent];
        self.backgroundColor = [DuoTheme floor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        DuoWavesView* waves = [[DuoWavesView alloc] initWithFrame:self.bounds rise:YES];
        waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:waves];

        CGFloat cw = 118 * d, ch = roundf(cw * 1.41);
        UIView* col = [[UIView alloc] init];
        col.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:col];

        _glow = [[UIView alloc] init];
        _glow.translatesAutoresizingMaskIntoConstraints = NO;
        CAGradientLayer* g = [CAGradientLayer layer];
        g.type = kCAGradientLayerRadial;
        g.colors = @[(id)[accent colorWithAlphaComponent:0.55].CGColor, (id)[accent colorWithAlphaComponent:0].CGColor];
        g.startPoint = CGPointMake(0.5, 0.5);
        g.endPoint = CGPointMake(1, 1);
        g.frame = CGRectMake(0, 0, cw + 70 * d, ch + 70 * d);
        [_glow.layer addSublayer:g];
        _glow.alpha = 0;
        [col addSubview:_glow];

        _coverBox = [[UIView alloc] init];
        _coverBox.translatesAutoresizingMaskIntoConstraints = NO;
        _coverBox.layer.cornerRadius = 14 * d;
        _coverBox.clipsToBounds = YES;
        _coverBg = DuoPlaceholderLayer();
        _coverBg.frame = CGRectMake(0, 0, cw, ch);
        [_coverBox.layer addSublayer:_coverBg];
        UILabel* ph = DuoText([app uppercaseString], 13, [DuoTheme text], YES);
        ph.font = [DuoTheme bold:13];
        ph.numberOfLines = 3;
        ph.textAlignment = NSTextAlignmentCenter;
        [_coverBox addSubview:ph];
        UIImageView* iv = [[UIImageView alloc] initWithImage:cover];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [_coverBox addSubview:iv];
        [col addSubview:_coverBox];

        UILabel* name = DuoText(app, 20, [DuoTheme text], YES);
        name.textAlignment = NSTextAlignmentCenter;
        name.lineBreakMode = NSLineBreakByTruncatingTail;
        [col addSubview:name];
        _stage = DuoText([NSString stringWithFormat:@"Connecting to %@ …", host ?: @"your PC"], 12.5, [DuoTheme text2], NO);
        _stage.textAlignment = NSTextAlignmentCenter;
        [col addSubview:_stage];

        _trackW = 200 * d;
        UIView* track = [[UIView alloc] init];
        track.translatesAutoresizingMaskIntoConstraints = NO;
        track.backgroundColor = [UIColor colorWithWhite:1 alpha:0x1F / 255.0];
        track.layer.cornerRadius = 2 * d;
        track.clipsToBounds = YES;
        [col addSubview:track];
        _bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _trackW, 3 * d)];
        CAGradientLayer* bb = [CAGradientLayer layer];
        bb.colors = @[(id)[accent colorWithAlphaComponent:0.55].CGColor, (id)accent.CGColor];
        bb.startPoint = CGPointMake(0, 0.5);
        bb.endPoint = CGPointMake(1, 0.5);
        bb.frame = _bar.bounds;
        [_bar.layer addSublayer:bb];
        _bar.layer.anchorPoint = CGPointMake(0, 0.5);
        _bar.layer.position = CGPointMake(0, 1.5 * d);
        _bar.transform = CGAffineTransformMakeScale(0.0001, 1);
        [track addSubview:_bar];
        _percent = DuoText(@"0 %", 10.5, [DuoTheme text2], NO);
        _percent.font = [DuoTheme digits:10.5 * d weight:UIFontWeightMedium];
        _percent.textAlignment = NSTextAlignmentCenter;
        [col addSubview:_percent];

        UILabel* tip = DuoText(@"Swipe from the left edge to leave the stream", 11, [DuoTheme text3], NO);
        [self addSubview:tip];

        [NSLayoutConstraint activateConstraints:@[
            [col.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [col.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [col.widthAnchor constraintEqualToConstant:MAX(cw + 70 * d, 280 * d)],
            [_glow.topAnchor constraintEqualToAnchor:col.topAnchor],
            [_glow.centerXAnchor constraintEqualToAnchor:col.centerXAnchor],
            [_glow.widthAnchor constraintEqualToConstant:cw + 70 * d],
            [_glow.heightAnchor constraintEqualToConstant:ch + 70 * d],
            [_coverBox.centerXAnchor constraintEqualToAnchor:_glow.centerXAnchor],
            [_coverBox.centerYAnchor constraintEqualToAnchor:_glow.centerYAnchor],
            [_coverBox.widthAnchor constraintEqualToConstant:cw],
            [_coverBox.heightAnchor constraintEqualToConstant:ch],
            [ph.leadingAnchor constraintEqualToAnchor:_coverBox.leadingAnchor constant:8 * d],
            [ph.trailingAnchor constraintEqualToAnchor:_coverBox.trailingAnchor constant:-8 * d],
            [ph.centerYAnchor constraintEqualToAnchor:_coverBox.centerYAnchor],
            [iv.topAnchor constraintEqualToAnchor:_coverBox.topAnchor],
            [iv.bottomAnchor constraintEqualToAnchor:_coverBox.bottomAnchor],
            [iv.leadingAnchor constraintEqualToAnchor:_coverBox.leadingAnchor],
            [iv.trailingAnchor constraintEqualToAnchor:_coverBox.trailingAnchor],
            [name.topAnchor constraintEqualToAnchor:_glow.bottomAnchor constant:-14 * d],
            [name.leadingAnchor constraintEqualToAnchor:col.leadingAnchor],
            [name.trailingAnchor constraintEqualToAnchor:col.trailingAnchor],
            [_stage.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:6 * d],
            [_stage.leadingAnchor constraintEqualToAnchor:col.leadingAnchor],
            [_stage.trailingAnchor constraintEqualToAnchor:col.trailingAnchor],
            [track.topAnchor constraintEqualToAnchor:_stage.bottomAnchor constant:18 * d],
            [track.centerXAnchor constraintEqualToAnchor:col.centerXAnchor],
            [track.widthAnchor constraintEqualToConstant:_trackW],
            [track.heightAnchor constraintEqualToConstant:3 * d],
            [_percent.topAnchor constraintEqualToAnchor:track.bottomAnchor constant:8 * d],
            [_percent.centerXAnchor constraintEqualToAnchor:col.centerXAnchor],
            [_percent.bottomAnchor constraintEqualToAnchor:col.bottomAnchor],
            [tip.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [tip.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-16 * d],
        ]];
        [self enter];
    }
    return self;
}

- (void)enter {
    // Calm entrance: the cover rises softly, the glow breathes slowly.
    _coverBox.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.86, 0.86), CGAffineTransformMakeTranslation(0, 10 * d));
    _coverBox.alpha = 0;
    [DuoMotion curve:CGPointMake(0.22, 1) :CGPointMake(0.36, 1) duration:0.9 delay:0 animations:^{
        self->_coverBox.transform = CGAffineTransformIdentity;
        self->_coverBox.alpha = 1;
    } completion:nil];
    CABasicAnimation* p = [CABasicAnimation animationWithKeyPath:@"opacity"];
    p.fromValue = @0.45;
    p.toValue = @0.85;
    p.duration = 2.2;
    p.autoreverses = YES;
    p.repeatCount = HUGE_VALF;
    p.beginTime = CACurrentMediaTime() + 0.5;
    p.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    p.fillMode = kCAFillModeBackwards;
    [_glow.layer addAnimation:p forKey:@"pulse"];
    _glow.alpha = 1;
    // Starting the app on the PC: up to 30 %.
    _target = 0.03;
    _ceiling = 0.30;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    _link.preferredFrameRateRange = CAFrameRateRangeMake(30, 60, 60);
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

/// Every frame: creep towards the ceiling, glide the bar towards the target.
- (void)tick {
    _target += (_ceiling - _target) * 0.0027;
    _shown += (_target - _shown) * 0.08;
    [self showProgress];
}

- (void)showProgress {
    CGFloat k = MAX(0.0001, MIN(1, _shown));
    _bar.transform = CGAffineTransformMakeScale(k, 1);
    _percent.text = [NSString stringWithFormat:@"%ld %%", (long)MAX(1, MIN(100, lroundf(_shown * 100)))];
}

- (void)stageStarting:(NSString*)stage {
    if (_gone) {
        return;
    }
    _stages = MIN(kStageCount, _stages + 1);
    _ceiling = 0.30 + 0.65 * _stages / (CGFloat)kStageCount;
    NSString* t = stage.length > 0 ? [[[stage substringToIndex:1] uppercaseString] stringByAppendingString:[stage substringFromIndex:1]] : @"";
    [self setStageText:[t stringByAppendingString:@" …"]];
}

- (void)connected {
    if (!_gone) {
        [self setStageText:@"Connected · waiting for the picture …"];
        _ceiling = 0.97;
    }
}

- (void)setStageText:(NSString*)s {
    if ([s isEqualToString:_stage.text]) {
        return;
    }
    [UIView animateWithDuration:0.14 animations:^{
        self->_stage.alpha = 0.35;
    } completion:^(BOOL f) {
        self->_stage.text = s;
        [UIView animateWithDuration:0.22 animations:^{
            self->_stage.alpha = 1;
        }];
    }];
}

- (void)dismiss:(BOOL)connected {
    if (_gone) {
        return;
    }
    _gone = YES;
    self.userInteractionEnabled = NO;
    [_link invalidate];
    _link = nil;
    if (!connected) {
        [DuoMotion ease:0.32 delay:0 animations:^{
            self.alpha = 0;
        } completion:^{
            [self removeFromSuperview];
        }];
        return;
    }
    _shown = 1;
    [DuoMotion ease:0.32 delay:0 animations:^{
        self->_bar.transform = CGAffineTransformIdentity;
    } completion:nil];
    _percent.text = @"100 %";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.36 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self->_glow.layer removeAllAnimations];
        // Relaxed zoom: grows to 1.6× while fading.
        [DuoMotion ease:0.9 delay:0 animations:^{
            self->_coverBox.transform = CGAffineTransformMakeScale(1.6, 1.6);
            self->_coverBox.alpha = 0;
        } completion:nil];
        [DuoMotion ease:0.7 delay:0 animations:^{
            self->_glow.transform = CGAffineTransformMakeScale(1.8, 1.8);
            self->_glow.alpha = 0;
        } completion:nil];
        [DuoMotion ease:0.76 delay:0.26 animations:^{
            self.alpha = 0;
        } completion:^{
            [self removeFromSuperview];
        }];
    });
}

- (void)removeFromSuperview {
    [_link invalidate];
    _link = nil;
    [super removeFromSuperview];
}

@end

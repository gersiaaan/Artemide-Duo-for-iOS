//
//  DuoConnectOverlay.m
//  Artemide Duo for iOS
//

#import "DuoConnectOverlay.h"
#import "DuoSupport.h"
#import "DuoWavesView.h"

// moonlight-common-c runs about eleven stages before the stream is up.
static const CGFloat kStageCount = 12;

@implementation DuoConnectOverlay {
    UIImageView* _backdrop;
    UIView* _content;
    UILabel* _stage;
    UIView* _track;
    UIView* _bar;
    NSLayoutConstraint* _barWidth;
    NSInteger _stages;
    BOOL _dismissed;
}

- (instancetype)initWithFrame:(CGRect)frame app:(NSString*)app host:(NSString*)host cover:(UIImage*)cover {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [DuoTheme floor];
        self.userInteractionEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        DuoWavesView* waves = [[DuoWavesView alloc] initWithFrame:self.bounds];
        waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:waves];

        if (cover != nil) {
            _backdrop = [[UIImageView alloc] initWithFrame:self.bounds];
            _backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _backdrop.contentMode = UIViewContentModeScaleAspectFill;
            _backdrop.clipsToBounds = YES;
            _backdrop.image = cover;
            _backdrop.alpha = 0.35;
            UIVisualEffectView* blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
            blur.frame = _backdrop.bounds;
            blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_backdrop addSubview:blur];
            [self addSubview:_backdrop];
        }

        _content = [[UIView alloc] init];
        _content.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_content];

        UIView* box = [[UIView alloc] init];
        box.translatesAutoresizingMaskIntoConstraints = NO;
        box.backgroundColor = [[DuoTheme accent] colorWithAlphaComponent:0.22];
        box.layer.cornerRadius = 16;
        box.layer.borderWidth = 1;
        box.layer.borderColor = [DuoTheme line].CGColor;
        box.clipsToBounds = YES;
        [_content addSubview:box];
        UIImageView* art = [[UIImageView alloc] initWithImage:cover];
        art.translatesAutoresizingMaskIntoConstraints = NO;
        art.contentMode = UIViewContentModeScaleAspectFill;
        [box addSubview:art];
        UILabel* initials = [[UILabel alloc] init];
        initials.translatesAutoresizingMaskIntoConstraints = NO;
        initials.text = [app uppercaseString];
        initials.numberOfLines = 3;
        initials.textAlignment = NSTextAlignmentCenter;
        initials.font = [DuoTheme font:16 weight:UIFontWeightBold];
        initials.textColor = [DuoTheme text];
        initials.hidden = (cover != nil);
        [box addSubview:initials];

        UILabel* name = [[UILabel alloc] init];
        name.translatesAutoresizingMaskIntoConstraints = NO;
        name.text = app;
        name.font = [DuoTheme font:28 weight:UIFontWeightBold];
        name.textColor = [DuoTheme text];
        name.textAlignment = NSTextAlignmentCenter;
        name.adjustsFontSizeToFitWidth = YES;
        name.minimumScaleFactor = 0.6;
        [_content addSubview:name];

        UILabel* sub = [[UILabel alloc] init];
        sub.translatesAutoresizingMaskIntoConstraints = NO;
        sub.text = host != nil ? [NSString stringWithFormat:@"on %@", host] : @"";
        sub.font = [DuoTheme font:15 weight:UIFontWeightRegular];
        sub.textColor = [DuoTheme text2];
        sub.textAlignment = NSTextAlignmentCenter;
        [_content addSubview:sub];

        _track = [[UIView alloc] init];
        _track.translatesAutoresizingMaskIntoConstraints = NO;
        _track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        _track.layer.cornerRadius = 2;
        _track.clipsToBounds = YES;
        [_content addSubview:_track];
        _bar = [[UIView alloc] init];
        _bar.translatesAutoresizingMaskIntoConstraints = NO;
        _bar.backgroundColor = [DuoTheme accent];
        _bar.layer.cornerRadius = 2;
        [_track addSubview:_bar];

        _stage = [[UILabel alloc] init];
        _stage.translatesAutoresizingMaskIntoConstraints = NO;
        _stage.text = @"Starting …";
        _stage.font = [DuoTheme font:13 weight:UIFontWeightMedium];
        _stage.textColor = [DuoTheme text2];
        _stage.textAlignment = NSTextAlignmentCenter;
        [_content addSubview:_stage];

        UILabel* tip = [[UILabel alloc] init];
        tip.translatesAutoresizingMaskIntoConstraints = NO;
        tip.text = @"Swipe from the left edge to disconnect";
        tip.font = [DuoTheme font:12 weight:UIFontWeightRegular];
        tip.textColor = [DuoTheme text3];
        tip.textAlignment = NSTextAlignmentCenter;
        [self addSubview:tip];

        _barWidth = [_bar.widthAnchor constraintEqualToConstant:0];
        [NSLayoutConstraint activateConstraints:@[
            [_content.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_content.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_content.widthAnchor constraintEqualToConstant:300],
            [box.topAnchor constraintEqualToAnchor:_content.topAnchor],
            [box.centerXAnchor constraintEqualToAnchor:_content.centerXAnchor],
            [box.widthAnchor constraintEqualToConstant:150],
            [box.heightAnchor constraintEqualToConstant:212],
            [art.topAnchor constraintEqualToAnchor:box.topAnchor],
            [art.bottomAnchor constraintEqualToAnchor:box.bottomAnchor],
            [art.leadingAnchor constraintEqualToAnchor:box.leadingAnchor],
            [art.trailingAnchor constraintEqualToAnchor:box.trailingAnchor],
            [initials.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:10],
            [initials.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-10],
            [initials.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
            [name.topAnchor constraintEqualToAnchor:box.bottomAnchor constant:20],
            [name.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor],
            [name.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor],
            [sub.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:4],
            [sub.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor],
            [sub.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor],
            [_track.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:26],
            [_track.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor constant:30],
            [_track.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor constant:-30],
            [_track.heightAnchor constraintEqualToConstant:4],
            [_bar.leadingAnchor constraintEqualToAnchor:_track.leadingAnchor],
            [_bar.topAnchor constraintEqualToAnchor:_track.topAnchor],
            [_bar.bottomAnchor constraintEqualToAnchor:_track.bottomAnchor],
            _barWidth,
            [_stage.topAnchor constraintEqualToAnchor:_track.bottomAnchor constant:12],
            [_stage.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor],
            [_stage.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor],
            [_stage.bottomAnchor constraintEqualToAnchor:_content.bottomAnchor],
            [tip.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [tip.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-18],
        ]];

        // Entry: the cover rises in.
        _content.alpha = 0;
        _content.transform = CGAffineTransformMakeTranslation(0, 24);
        [UIView animateWithDuration:0.5 delay:0.05 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:0 animations:^{
            self->_content.alpha = 1;
            self->_content.transform = CGAffineTransformIdentity;
        } completion:nil];
        [self setProgress:0.06];
    }
    return self;
}

- (void)setProgress:(CGFloat)p {
    [self layoutIfNeeded];
    _barWidth.constant = 240 * MAX(0, MIN(1, p));
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)stageStarting:(NSString*)stage {
    if (_dismissed) {
        return;
    }
    _stages++;
    NSString* text = stage.length > 0 ? [[[stage substringToIndex:1] uppercaseString] stringByAppendingString:[stage substringFromIndex:1]] : stage;
    _stage.text = [text stringByAppendingString:@" …"];
    [self setProgress:0.06 + 0.86 * (_stages / kStageCount)];
}

- (void)connected {
    if (_dismissed) {
        return;
    }
    _stage.text = @"Connected · waiting for the picture …";
    [self setProgress:0.96];
}

- (void)dismiss {
    if (_dismissed) {
        return;
    }
    _dismissed = YES;
    [self setProgress:1];
    [UIView animateWithDuration:0.45 delay:0.12 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.alpha = 0;
        self->_content.transform = CGAffineTransformMakeScale(1.15, 1.15);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

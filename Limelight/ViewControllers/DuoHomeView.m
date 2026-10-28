//
//  DuoHomeView.m
//  Artemide Duo for iOS
//

#import "DuoHomeView.h"
#import "DuoSupport.h"
#import "DuoWavesView.h"
#import "DataManager.h"
#import "TemporarySettings.h"

static NSString* const kSelected = @"duo_home_selected_host";
static BOOL sSplashShown;

NSString* DuoClockText(void);
NSString* DuoDateLine(void);

NSString* DuoClockText(void) {
    return [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
}

NSString* DuoDateLine(void) {
    NSString* date = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
    UIDevice* dev = [UIDevice currentDevice];
    dev.batteryMonitoringEnabled = YES;
    float level = dev.batteryLevel;
    if (level < 0) {
        return date;
    }
    BOOL charging = dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull;
    return [NSString stringWithFormat:@"%@  ·  %@%d %%", date, charging ? @"⚡ " : @"", (int)roundf(level * 100)];
}

static UIStackView* DuoRow(CGFloat spacing) {
    UIStackView* s = [[UIStackView alloc] init];
    s.axis = UILayoutConstraintAxisHorizontal;
    s.alignment = UIStackViewAlignmentCenter;
    s.spacing = spacing;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    return s;
}

static UIStackView* DuoCol(CGFloat spacing) {
    UIStackView* s = [[UIStackView alloc] init];
    s.axis = UILayoutConstraintAxisVertical;
    s.spacing = spacing;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    return s;
}

static UIView* DuoFlex(void) {
    UIView* v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [v setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [v setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [v setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [v setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisVertical];
    return v;
}

static NSString* DuoInitials(NSString* n) {
    NSMutableString* b = [NSMutableString string];
    for (NSString* w in [n componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
        if (w.length > 0 && b.length < 3) {
            [b appendString:[[w substringToIndex:1] uppercaseString]];
        }
    }
    return b;
}

static BOOL DuoRunning(TemporaryHost* h) {
    return h.state == StateOnline && h.currentGame != nil && ![h.currentGame isEqualToString:@"0"];
}

static UIColor* DuoStateColor(TemporaryHost* h) {
    if (h.state == StateOnline) return [DuoTheme online];
    return h.state == StateOffline ? [DuoTheme offline] : [DuoTheme warn];
}

/// Host tab chip.
@interface DuoChipButton : UIControl
@property (nonatomic, strong) UILabel* label;
@property (nonatomic, strong) UIView* dot;
@end

@implementation DuoChipButton
- (void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    [DuoMotion ease:0.09 delay:0 animations:^{
        self.transform = h ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    } completion:nil];
}
@end

@implementation DuoHomeView {
    CGFloat d;
    NSMutableArray<TemporaryHost*>* _computers;
    NSString* _selectedUuid;
    BOOL _addMode;

    UIView* _content;
    UIStackView* _body;
    UILabel* _clock;
    UILabel* _dateLine;
    UIStackView* _hostChips;
    NSArray<UIView*>* _pills;

    UIView* _card;
    UIView* _badge;
    UILabel* _badgeLabel;
    UIView* _badgeDot;
    UILabel* _name;
    UILabel* _subline;
    UIScrollView* _chipScroll;
    UIStackView* _chips;
    UIView* _searchRow;
    UILabel* _addressLabel;
    UILabel* _address;
    UIView* _tsRow;
    UIView* _tsDot;
    UILabel* _tailscale;
    DuoButton* _primary;
    DuoButton* _options;

    UIStackView* _lastPanel;
    UILabel* _lastInfo;
    UIView* _coverBox;
    CAGradientLayer* _coverBg;
    UIImageView* _lastCover;
    UILabel* _lastPlaceholder;
    UIImageView* _lastIcon;
    UILabel* _lastName;
    DuoButton* _playAgain;
    NSLayoutConstraint* _coverH;

    DuoButton* _settings;
    DuoButton* _quitAll;

    NSArray<DuoButton*>* _focusRow;
    NSInteger _focus;
    NSTimer* _clockTimer;
    BOOL _landscape;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        d = [DuoTheme scale];
        _computers = [NSMutableArray array];
        _selectedUuid = [[NSUserDefaults standardUserDefaults] stringForKey:kSelected];
        self.backgroundColor = [DuoTheme floor];
        self.clipsToBounds = YES;
        NSInteger splash = sSplashShown ? 0 : [DuoPrefs splashSeconds];

        DuoWavesView* waves = [[DuoWavesView alloc] initWithFrame:self.bounds rise:!sSplashShown];
        waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:waves];

        _content = [[UIView alloc] init];
        _content.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_content];
        UILayoutGuide* safe = self.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [_content.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18 * d],
            [_content.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12 * d],
            [_content.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:22 * d],
            [_content.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-22 * d],
        ]];
        UIStackView* col = DuoCol(0);
        [_content addSubview:col];
        [self pin:col to:_content];

        // ---------- header ----------
        UIStackView* header = DuoRow(10 * d);
        header.alignment = UIStackViewAlignmentTop;
        [header addArrangedSubview:[[DuoLogoView alloc] initWithSize:30 * d]];
        UIStackView* titles = DuoCol(0);
        UILabel* title = DuoText(@"", 16, [DuoTheme text], YES);
        title.attributedText = [DuoTheme brand:YES size:16 * d];
        [titles addArrangedSubview:title];
        [titles addArrangedSubview:DuoText(@"an Artemide fork for iPad and iPhone", 10.5, [DuoTheme text2], NO)];
        [header addArrangedSubview:titles];
        [header addArrangedSubview:DuoFlex()];
        UIStackView* clockCol = DuoCol(0);
        clockCol.alignment = UIStackViewAlignmentTrailing;
        _clock = DuoText(@"", 34, [DuoTheme text], NO);
        _clock.font = [DuoTheme digits:34 * d weight:UIFontWeightRegular];
        _dateLine = DuoText(@"", 13.5, [DuoTheme text2], NO);
        [clockCol addArrangedSubview:_clock];
        [clockCol addArrangedSubview:_dateLine];
        [header addArrangedSubview:clockCol];
        [col addArrangedSubview:header];
        [col setCustomSpacing:14 * d afterView:header];

        // ---------- host bar ----------
        UIStackView* hostBar = DuoRow(10 * d);
        [hostBar.heightAnchor constraintEqualToConstant:32 * d].active = YES;
        UILabel* lb = DuoKeyPill(@"LB");
        UILabel* rb = DuoKeyPill(@"RB");
        lb.userInteractionEnabled = YES;
        rb.userInteractionEnabled = YES;
        [lb addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(prevHost)]];
        [rb addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nextHost)]];
        _pills = @[lb, rb];
        UIScrollView* scroll = [[UIScrollView alloc] init];
        scroll.translatesAutoresizingMaskIntoConstraints = NO;
        scroll.showsHorizontalScrollIndicator = NO;
        _hostChips = DuoRow(6 * d);
        _hostChips.alignment = UIStackViewAlignmentFill;
        [scroll addSubview:_hostChips];
        [NSLayoutConstraint activateConstraints:@[
            [_hostChips.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
            [_hostChips.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
            [_hostChips.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
            [_hostChips.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
            [_hostChips.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
            [scroll.heightAnchor constraintEqualToConstant:32 * d],
        ]];
        NSLayoutConstraint* sw = [scroll.widthAnchor constraintEqualToAnchor:_hostChips.widthAnchor];
        sw.priority = UILayoutPriorityDefaultLow;
        sw.active = YES;
        [scroll setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [hostBar addArrangedSubview:lb];
        [hostBar addArrangedSubview:scroll];
        [hostBar addArrangedSubview:rb];
        [hostBar addArrangedSubview:DuoFlex()];
        [col addArrangedSubview:hostBar];
        [col setCustomSpacing:14 * d afterView:hostBar];

        // ---------- body ----------
        _body = [[UIStackView alloc] init];
        _body.translatesAutoresizingMaskIntoConstraints = NO;
        _body.axis = UILayoutConstraintAxisHorizontal;
        _body.alignment = UIStackViewAlignmentFill;
        _body.distribution = UIStackViewDistributionFill;
        _body.spacing = 18 * d;
        [self buildCard];
        [self buildLastPanel];
        [_body addArrangedSubview:_card];
        [_body addArrangedSubview:_lastPanel];
        [_body setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
        [col addArrangedSubview:_body];
        [col setCustomSpacing:14 * d afterView:_body];
        _landscape = YES;
        [self applyOrientation];

        // ---------- bottom buttons ----------
        UIStackView* bottom = DuoRow(8 * d);
        [bottom.heightAnchor constraintEqualToConstant:36 * d].active = YES;
        _settings = [[DuoButton alloc] initWithTitle:@"Settings" glyph:@"Y" primary:NO];
        __weak DuoHomeView* weakSelf = self;
        _settings.onTap = ^{
            [weakSelf.delegate duoOpenSettings];
        };
        [_settings.heightAnchor constraintEqualToConstant:36 * d].active = YES;
        [bottom addArrangedSubview:_settings];
        [bottom addArrangedSubview:DuoFlex()];
        // Quit everything running on this PC (Menu ≡), no questions asked.
        _quitAll = [[DuoButton alloc] initWithTitle:@"Quit all sessions" glyph:@"≡" primary:NO];
        _quitAll.onTap = ^{
            DuoHomeView* s = weakSelf;
            TemporaryHost* h = [s selectedHost];
            if (h != nil) {
                [s.delegate duoQuitAll:h];
            }
        };
        [_quitAll.heightAnchor constraintEqualToConstant:36 * d].active = YES;
        _quitAll.hidden = YES;
        [bottom addArrangedSubview:_quitAll];
        [col addArrangedSubview:bottom];

        _focusRow = @[_primary, _options];
        _focus = 0;

        [self updateClock];
        [self render];
        [self updateGlyphs];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateGlyphs) name:DuoPadChangedNotification object:nil];

        // ---------- start screen ----------
        sSplashShown = YES;
        if (splash > 0) {
            _content.alpha = 0;
            UIView* s = [self buildSplash];
            [self addSubview:s];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(splash * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.4 animations:^{
                    s.alpha = 0;
                } completion:^(BOOL f) {
                    [s removeFromSuperview];
                }];
                self->_content.transform = CGAffineTransformMakeTranslation(0, 8 * self->d);
                [DuoMotion ease:0.5 delay:0 animations:^{
                    self->_content.alpha = 1;
                    self->_content.transform = CGAffineTransformIdentity;
                } completion:nil];
            });
        }
    }
    return self;
}

- (void)pin:(UIView*)v to:(UIView*)p {
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:p.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:p.bottomAnchor],
        [v.leadingAnchor constraintEqualToAnchor:p.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:p.trailingAnchor],
    ]];
}

- (UIView*)buildSplash {
    UIView* s = [[UIView alloc] initWithFrame:self.bounds];
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIStackView* c = DuoCol(18 * d);
    c.alignment = UIStackViewAlignmentCenter;
    [c addArrangedSubview:[[DuoLogoView alloc] initWithSize:64 * d]];
    UILabel* t = DuoText(@"", 30, [DuoTheme text], YES);
    t.attributedText = [DuoTheme brand:NO size:30 * d];
    [c addArrangedSubview:t];
    [s addSubview:c];
    [NSLayoutConstraint activateConstraints:@[
        [c.centerXAnchor constraintEqualToAnchor:s.centerXAnchor],
        [c.centerYAnchor constraintEqualToAnchor:s.centerYAnchor],
    ]];
    s.alpha = 0;
    [UIView animateWithDuration:1.2 animations:^{
        s.alpha = 1;
    }];
    return s;
}

#pragma mark Card

- (void)buildCard {
    _card = [[UIView alloc] init];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    // Slightly see-through so the waves show behind it (StreamLight's host card).
    _card.backgroundColor = [[DuoTheme card] colorWithAlphaComponent:0.72];
    _card.layer.cornerRadius = 16 * d;
    _card.layer.borderWidth = 1;
    _card.layer.borderColor = [DuoTheme line].CGColor;
    UIStackView* c = DuoCol(0);
    c.alignment = UIStackViewAlignmentLeading;
    [_card addSubview:c];
    [NSLayoutConstraint activateConstraints:@[
        [c.topAnchor constraintEqualToAnchor:_card.topAnchor constant:18 * d],
        [c.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-18 * d],
        [c.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20 * d],
        [c.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-20 * d],
    ]];
    UILabel* bl = nil;
    UIView* bd = nil;
    _badge = DuoBadge(@"", [DuoTheme warn], &bl, &bd);
    _badgeLabel = bl;
    _badgeDot = bd;
    [c addArrangedSubview:_badge];
    [c setCustomSpacing:14 * d afterView:_badge];
    _name = DuoText(@"", 34, [DuoTheme text], YES);
    _name.lineBreakMode = NSLineBreakByTruncatingTail;
    [c addArrangedSubview:_name];
    [_name.widthAnchor constraintLessThanOrEqualToAnchor:c.widthAnchor].active = YES;
    [c setCustomSpacing:10 * d afterView:_name];
    _subline = DuoText(@"", 12, [DuoTheme text2], NO);
    [c addArrangedSubview:_subline];
    [c setCustomSpacing:6 * d afterView:_subline];

    _chipScroll = [[UIScrollView alloc] init];
    _chipScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _chipScroll.showsHorizontalScrollIndicator = NO;
    _chips = DuoRow(6 * d);
    [_chipScroll addSubview:_chips];
    [NSLayoutConstraint activateConstraints:@[
        [_chips.topAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.topAnchor],
        [_chips.bottomAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.bottomAnchor],
        [_chips.leadingAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.leadingAnchor],
        [_chips.trailingAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.trailingAnchor],
        [_chips.heightAnchor constraintEqualToAnchor:_chipScroll.frameLayoutGuide.heightAnchor],
        [_chipScroll.heightAnchor constraintEqualToConstant:24 * d],
    ]];
    [c addArrangedSubview:_chipScroll];
    [_chipScroll.widthAnchor constraintEqualToAnchor:c.widthAnchor].active = YES;
    [c setCustomSpacing:18 * d afterView:_chipScroll];

    UIStackView* sr = DuoRow(10 * d);
    UIActivityIndicatorView* spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spin.color = [DuoTheme accent];
    [spin startAnimating];
    [sr addArrangedSubview:spin];
    [sr addArrangedSubview:DuoText(@"Hosts found on the network appear as tabs above.", 12, [DuoTheme text2], NO)];
    _searchRow = sr;
    [c addArrangedSubview:sr];
    [c setCustomSpacing:16 * d afterView:sr];

    _addressLabel = DuoText(@"", 9.5, [DuoTheme text2], NO);
    _addressLabel.attributedText = [DuoTheme spaced:@"ADDRESS" font:[DuoTheme regular:9.5 * d] color:[DuoTheme text2] em:0.15];
    [c addArrangedSubview:_addressLabel];
    _address = DuoText(@"", 16, [DuoTheme text], YES);
    [c addArrangedSubview:_address];
    [c setCustomSpacing:6 * d afterView:_address];
    // How the PC is reached: over the LAN or through Tailscale (and whether Tailscale is on).
    UIStackView* ts = DuoRow(7 * d);
    _tsDot = [[UIView alloc] init];
    _tsDot.translatesAutoresizingMaskIntoConstraints = NO;
    _tsDot.layer.cornerRadius = 3 * d;
    [NSLayoutConstraint activateConstraints:@[
        [_tsDot.widthAnchor constraintEqualToConstant:6 * d],
        [_tsDot.heightAnchor constraintEqualToConstant:6 * d],
    ]];
    _tailscale = DuoText(@"", 11.5, [DuoTheme text2], NO);
    _tailscale.numberOfLines = 2;
    [ts addArrangedSubview:_tsDot];
    [ts addArrangedSubview:_tailscale];
    _tsRow = ts;
    [c addArrangedSubview:ts];
    UIView* flex = DuoFlex();
    [c addArrangedSubview:flex];

    UIStackView* buttons = DuoRow(8 * d);
    [buttons.heightAnchor constraintEqualToConstant:40 * d].active = YES;
    _primary = [[DuoButton alloc] initWithTitle:@"Open" glyph:@"A" primary:YES];
    _options = [[DuoButton alloc] initWithTitle:@"Options" glyph:@"⧉" primary:NO];
    __weak DuoHomeView* weakSelf = self;
    _options.onTap = ^{
        DuoHomeView* s = weakSelf;
        TemporaryHost* h = [s selectedHost];
        if (h != nil) {
            [s.delegate duoHostOptions:h view:s->_options];
        }
    };
    [_primary.heightAnchor constraintEqualToConstant:40 * d].active = YES;
    [_options.heightAnchor constraintEqualToConstant:40 * d].active = YES;
    [buttons addArrangedSubview:_primary];
    [buttons addArrangedSubview:_options];
    [c addArrangedSubview:buttons];
}

- (void)buildLastPanel {
    _lastPanel = DuoCol(0);
    _lastPanel.alignment = UIStackViewAlignmentCenter;
    UIView* top = DuoFlex();
    [_lastPanel addArrangedSubview:top];

    UILabel* infoLabel = nil;
    UIView* info = DuoBadge(@"", [UIColor clearColor], &infoLabel, NULL);
    _lastInfo = infoLabel;
    [_lastPanel addArrangedSubview:info];
    [_lastPanel setCustomSpacing:14 * d afterView:info];

    _coverBox = [[UIView alloc] init];
    _coverBox.translatesAutoresizingMaskIntoConstraints = NO;
    _coverBox.layer.cornerRadius = 12 * d;
    _coverBox.layer.borderWidth = 1;
    _coverBox.layer.borderColor = [DuoTheme line].CGColor;
    _coverBox.layer.shadowColor = [UIColor blackColor].CGColor;
    _coverBox.layer.shadowOpacity = 0.5;
    _coverBox.layer.shadowRadius = 10 * d;
    _coverBox.layer.shadowOffset = CGSizeMake(0, 6 * d);
    UIView* clip = [[UIView alloc] init];
    clip.translatesAutoresizingMaskIntoConstraints = NO;
    clip.layer.cornerRadius = 12 * d;
    clip.clipsToBounds = YES;
    [_coverBox addSubview:clip];
    [self pin:clip to:_coverBox];
    _coverBg = DuoPlaceholderLayer();
    [clip.layer addSublayer:_coverBg];
    UIStackView* ph = DuoCol(8 * d);
    ph.alignment = UIStackViewAlignmentCenter;
    _lastIcon = [[UIImageView alloc] initWithImage:DuoMonitorIcon(40 * d, [DuoTheme text])];
    _lastIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _lastPlaceholder = DuoText(@"", 11, [DuoTheme text], YES);
    _lastPlaceholder.textAlignment = NSTextAlignmentCenter;
    _lastPlaceholder.numberOfLines = 3;
    [ph addArrangedSubview:_lastIcon];
    [ph addArrangedSubview:_lastPlaceholder];
    [clip addSubview:ph];
    _lastCover = [[UIImageView alloc] init];
    _lastCover.translatesAutoresizingMaskIntoConstraints = NO;
    _lastCover.contentMode = UIViewContentModeScaleAspectFill;
    _lastCover.clipsToBounds = YES;
    [clip addSubview:_lastCover];
    [self pin:_lastCover to:clip];
    CGFloat cw = 128 * 1.2 * d;
    _coverH = [_coverBox.heightAnchor constraintEqualToConstant:cw * 1.41];
    _coverH.priority = UILayoutPriorityDefaultLow;
    [NSLayoutConstraint activateConstraints:@[
        [ph.centerXAnchor constraintEqualToAnchor:clip.centerXAnchor],
        [ph.centerYAnchor constraintEqualToAnchor:clip.centerYAnchor],
        [ph.widthAnchor constraintLessThanOrEqualToAnchor:clip.widthAnchor constant:-12 * d],
        _coverH,
        [_coverBox.heightAnchor constraintLessThanOrEqualToConstant:cw * 1.41],
        [_coverBox.heightAnchor constraintGreaterThanOrEqualToConstant:90 * d],
        [_coverBox.widthAnchor constraintEqualToAnchor:_coverBox.heightAnchor multiplier:1 / 1.41],
    ]];
    [_coverBox setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_lastPanel addArrangedSubview:_coverBox];
    [_lastPanel setCustomSpacing:14 * d afterView:_coverBox];

    _lastName = DuoText(@"", 19, [DuoTheme text], YES);
    _lastName.textAlignment = NSTextAlignmentCenter;
    _lastName.lineBreakMode = NSLineBreakByTruncatingTail;
    [_lastPanel addArrangedSubview:_lastName];
    [_lastName.widthAnchor constraintLessThanOrEqualToAnchor:_lastPanel.widthAnchor].active = YES;
    [_lastPanel setCustomSpacing:12 * d afterView:_lastName];

    _playAgain = [[DuoButton alloc] initWithTitle:@"Play again" glyph:@"X" primary:NO];
    [_playAgain.heightAnchor constraintEqualToConstant:36 * d].active = YES;
    [_lastPanel addArrangedSubview:_playAgain];
    UIView* bottomFlex = DuoFlex();
    [_lastPanel addArrangedSubview:bottomFlex];
    [top.heightAnchor constraintEqualToAnchor:bottomFlex.heightAnchor].active = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _coverBg.frame = _coverBox.bounds;
    BOOL land = self.bounds.size.width >= self.bounds.size.height;
    if (land != _landscape) {
        _landscape = land;
        [self applyOrientation];
    }
}

- (void)applyOrientation {
    // Landscape: card | last played side by side; portrait: stacked.
    for (NSLayoutConstraint* c in _body.constraints) {
        if ([c.identifier isEqualToString:@"duoWeight"]) {
            c.active = NO;
        }
    }
    _body.axis = _landscape ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    _body.spacing = (_landscape ? 18 : 16) * d;
    NSLayoutConstraint* w = _landscape
        ? [_lastPanel.widthAnchor constraintEqualToAnchor:_card.widthAnchor multiplier:1 / 1.55]
        : [_lastPanel.heightAnchor constraintEqualToAnchor:_card.heightAnchor multiplier:1 / 1.1];
    w.identifier = @"duoWeight";
    [_body addConstraint:w];
    _name.font = [DuoTheme semibold:(_landscape ? 34 : 30) * d];
}

#pragma mark Data

- (void)setHosts:(NSArray<TemporaryHost*>*)hosts {
    // On the "Add a host" page a newly found PC opens right away as its tab.
    TemporaryHost* found = nil;
    if (_addMode) {
        for (TemporaryHost* n in hosts) {
            BOOL known = NO;
            for (TemporaryHost* o in _computers) {
                known |= (o.uuid != nil && [o.uuid isEqualToString:n.uuid]);
            }
            if (!known) {
                found = n;
                break;
            }
        }
    }
    [_computers setArray:[hosts sortedArrayUsingSelector:@selector(compareName:)]];
    if (found != nil && found.uuid != nil) {
        [self select:found];
        return;
    }
    [self render];
}

- (TemporaryHost*)selected {
    if (_computers.count == 0) {
        return nil;
    }
    for (TemporaryHost* c in _computers) {
        if (c.uuid != nil && [c.uuid isEqualToString:_selectedUuid]) {
            return c;
        }
    }
    return _computers.firstObject;
}

- (TemporaryHost*)selectedHost {
    return _addMode ? nil : [self selected];
}

- (void)select:(TemporaryHost*)c {
    _addMode = NO;
    _selectedUuid = c.uuid;
    if (c.uuid != nil) {
        [[NSUserDefaults standardUserDefaults] setObject:c.uuid forKey:kSelected];
    }
    [self render];
}

- (void)prevHost { [self cycle:-1]; }
- (void)nextHost { [self cycle:1]; }

- (void)cycle:(NSInteger)dir {
    // Tabs: every host, then "Add a host".
    NSInteger n = _computers.count + 1;
    NSInteger i = _addMode ? n - 1 : (NSInteger)[_computers indexOfObject:[self selected]];
    if (i == NSNotFound || i < 0) {
        i = n - 1;
    }
    NSInteger j = (i + dir + n) % n;
    if (j == n - 1) {
        _addMode = YES;
        [self render];
    } else {
        [self select:_computers[j]];
    }
    // The host card slides in from the side you switched to.
    [DuoMotion slideIn:_card dir:dir distance:28 * d];
    [DuoMotion fadeIn:_lastPanel duration:0.36];
}

- (void)refresh {
    [self render];
}

- (UIControl*)hostChip:(NSString*)title dot:(UIColor*)dot selected:(BOOL)sel {
    DuoChipButton* chip = [[DuoChipButton alloc] init];
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    chip.layer.cornerRadius = 9 * d;
    UIColor* accent = [DuoTheme accent];
    chip.backgroundColor = sel ? [DuoTheme mix:accent with:[DuoTheme card] k:0.16] : [UIColor clearColor];
    chip.layer.borderWidth = sel ? 1 : 0;
    chip.layer.borderColor = [accent colorWithAlphaComponent:0.45].CGColor;
    UIStackView* r = DuoRow(8 * d);
    r.userInteractionEnabled = NO;
    if (dot != nil) {
        UIView* v = [[UIView alloc] init];
        v.translatesAutoresizingMaskIntoConstraints = NO;
        v.backgroundColor = dot;
        v.layer.cornerRadius = 3.5 * d;
        [NSLayoutConstraint activateConstraints:@[
            [v.widthAnchor constraintEqualToConstant:7 * d],
            [v.heightAnchor constraintEqualToConstant:7 * d],
        ]];
        [r addArrangedSubview:v];
    }
    UILabel* t = DuoText(@"", 12, sel ? [DuoTheme text] : [DuoTheme text2], YES);
    t.attributedText = [DuoTheme spaced:title font:(dot != nil || sel) ? [DuoTheme semibold:12 * d] : [DuoTheme regular:12 * d]
                                  color:sel ? [DuoTheme text] : [DuoTheme text2] em:0.04];
    [r addArrangedSubview:t];
    [chip addSubview:r];
    CGFloat pad = (dot != nil ? 12 : 10) * d;
    [NSLayoutConstraint activateConstraints:@[
        [r.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:pad],
        [r.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-pad],
        [r.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
    ]];
    return chip;
}

- (void)render {
    TemporaryHost* c = [self selected];

    // host chips
    for (UIView* v in _hostChips.arrangedSubviews) {
        [v removeFromSuperview];
    }
    __weak DuoHomeView* weakSelf = self;
    for (TemporaryHost* pc in _computers) {
        BOOL sel = pc == c && !_addMode;
        UIControl* chip = [self hostChip:[pc.name ?: @"?" uppercaseString] dot:DuoStateColor(pc) selected:sel];
        __weak TemporaryHost* wpc = pc;
        [chip addAction:[UIAction actionWithHandler:^(__kindof UIAction* a) {
            if (wpc != nil) {
                [weakSelf select:wpc];
            }
        }] forControlEvents:UIControlEventTouchUpInside];
        [_hostChips addArrangedSubview:chip];
    }
    BOOL addSel = _addMode || c == nil;
    UIControl* add = [self hostChip:@"+  Add a host" dot:nil selected:addSel];
    [add addAction:[UIAction actionWithHandler:^(__kindof UIAction* a) {
        DuoHomeView* s = weakSelf;
        s->_addMode = YES;
        [s render];
    }] forControlEvents:UIControlEventTouchUpInside];
    [_hostChips addArrangedSubview:add];

    // card
    BOOL addPage = c == nil || _addMode;
    _badge.hidden = addPage;
    _searchRow.hidden = !addPage;
    _options.hidden = addPage;
    if (addPage) {
        // StreamLight's "Add a host" tab: search runs in the background, manual add by address.
        _name.text = @"Add a host";
        _subline.text = @"Searching your local network…";
        _chipScroll.hidden = YES;
        _address.hidden = YES;
        _addressLabel.hidden = YES;
        _tsRow.hidden = YES;
        [_primary setTitle:@"Add a host"];
        _primary.onTap = ^{
            [weakSelf.delegate duoAddHost];
        };
        _lastPanel.alpha = 0;
        _lastPanel.userInteractionEnabled = NO;
        _quitAll.hidden = YES;
        return;
    }
    _lastPanel.alpha = 1;
    _lastPanel.userInteractionEnabled = YES;
    NSString* state, *sub, *action = @"Open";
    switch (c.state) {
        case StateOnline:
            state = @"ONLINE";
            if (c.pairState != PairStatePaired && c.pairState != PairStateUnknown) {
                sub = @"Not paired yet";
                action = @"Pair";
            } else {
                sub = DuoRunning(c) ? @"A session is running" : @"Ready to stream";
            }
            break;
        case StateOffline:
            state = @"OFFLINE";
            sub = @"Offline";
            action = (c.mac != nil && ![c.mac isEqualToString:@"00:00:00:00:00:00"]) ? @"Wake" : @"Open";
            break;
        default:
            state = @"CHECKING";
            sub = @"Checking…";
            break;
    }
    _badgeLabel.attributedText = [DuoTheme spaced:state font:[DuoTheme semibold:10.5 * d] color:[DuoTheme text] em:0.1];
    _badgeDot.backgroundColor = DuoStateColor(c);
    _name.text = c.name;
    _subline.text = sub;
    _chipScroll.hidden = NO;
    [self fillChips];
    NSString* addr = c.activeAddress ?: (c.localAddress ?: (c.address ?: c.externalAddress));
    _address.text = addr ?: @"–";
    _address.hidden = NO;
    _addressLabel.hidden = NO;
    [self updateTailscale:c address:addr];
    [_primary setTitle:action];
    __weak TemporaryHost* wc = c;
    BOOL wake = [action isEqualToString:@"Wake"];
    _primary.onTap = ^{
        DuoHomeView* s = weakSelf;
        TemporaryHost* h = wc;
        if (h == nil) {
            return;
        }
        if (wake) {
            [s.delegate duoWakeHost:h];
        } else {
            [s.delegate duoOpenHost:h view:s->_primary];
        }
    };
    // Only while a session is actually running on this PC.
    _quitAll.hidden = !DuoRunning(c);

    // last played
    DuoLastPlayed* last = [DuoPlayStats lastForHost:c.uuid];
    if (last == nil) {
        _lastInfo.attributedText = [DuoTheme spaced:@"NOTHING PLAYED YET" font:[DuoTheme semibold:9.5 * d] color:[DuoTheme text] em:0.08];
        _lastName.text = @"";
        [self setCoverFor:c last:nil];
        _playAgain.alpha = 0;
        _playAgain.userInteractionEnabled = NO;
    } else {
        NSString* info = [NSString stringWithFormat:@"Last played %@%@", [DuoPlayStats ago:last.when],
                          last.total > 0 ? [NSString stringWithFormat:@"  ·  %@ total", [DuoPlayStats duration:last.total]] : @""];
        _lastInfo.attributedText = [DuoTheme spaced:[info uppercaseString] font:[DuoTheme semibold:9.5 * d] color:[DuoTheme text] em:0.08];
        _lastName.text = last.name;
        [self setCoverFor:c last:last];
        _playAgain.userInteractionEnabled = YES;
        BOOL ready = c.state == StateOnline && c.pairState == PairStatePaired;
        _playAgain.enabled = ready;
        _playAgain.alpha = ready ? 1 : 0.45;
        BOOL running = ready && DuoRunning(c);
        // Desktop / remote apps aren't "played": they're opened.
        BOOL isApp = [DuoPrefs isAppName:last.name];
        [_playAgain setTitle:running ? @"Resume" : isApp ? @"Open" : @"Play again"];
        NSString* appId = last.appId;
        _playAgain.onTap = ^{
            DuoHomeView* s = weakSelf;
            TemporaryHost* h = wc;
            if (h != nil) {
                [s.delegate duoPlayAgain:h appId:running ? h.currentGame : appId];
            }
        };
    }
    [self updateGlyphs];
}

- (void)updateTailscale:(TemporaryHost*)c address:(NSString*)addr {
    NSString* own = [DuoPrefs tailscaleAddress];
    BOOL viaTs = c.state == StateOnline && [DuoPrefs isTailscaleAddress:addr];
    NSString* text;
    if (viaTs) {
        text = [NSString stringWithFormat:@"Tailscale  ·  connected via %@%@", addr, own != nil ? [NSString stringWithFormat:@"  (this device %@)", own] : @""];
    } else if (own != nil) {
        text = [NSString stringWithFormat:@"Tailscale  ·  connected (%@)  ·  %@", own,
                c.state == StateOnline ? @"PC reached over the local network" : @"PC not reached"];
    } else {
        text = @"Tailscale  ·  not connected";
    }
    _tailscale.text = text;
    _tailscale.textColor = (viaTs || own != nil) ? [DuoTheme text] : [DuoTheme text2];
    _tsDot.backgroundColor = (viaTs || own != nil) ? [DuoTheme online] : [DuoTheme text3];
    _tsRow.hidden = NO;
}

- (void)fillChips {
    for (UIView* v in _chips.arrangedSubviews) {
        [v removeFromSuperview];
    }
    TemporarySettings* p = [[[DataManager alloc] init] getSettings];
    if (p == nil) {
        return;
    }
    NSMutableArray* l = [NSMutableArray array];
    [l addObject:[NSString stringWithFormat:@"%d×%d", [p.width intValue], [p.height intValue]]];
    NSInteger fps = [DuoPrefs customFps] > 0 ? [DuoPrefs customFps] : [p.framerate integerValue];
    [l addObject:[NSString stringWithFormat:@"%ld FPS", (long)fps]];
    [l addObject:[NSString stringWithFormat:@"%ld Mbps", lroundf([p.bitrate intValue] / 1000.0f)]];
    switch (p.preferredCodec) {
        case CODEC_PREF_HEVC: [l addObject:@"HEVC"]; break;
        case CODEC_PREF_AV1: [l addObject:@"AV1"]; break;
        case CODEC_PREF_H264: [l addObject:@"H.264"]; break;
        default: [l addObject:@"Auto codec"]; break;
    }
    int ch = [p.audioConfig intValue];
    [l addObject:ch >= 8 ? @"7.1" : ch >= 6 ? @"5.1" : @"Stereo"];
    for (NSString* s in l) {
        [_chips addArrangedSubview:DuoInfoChip(s)];
    }
}

- (void)setCoverFor:(TemporaryHost*)c last:(DuoLastPlayed*)last {
    BOOL desk = last == nil || [DuoPrefs isAppName:last.name];
    _lastPlaceholder.text = last == nil ? @"" : desk ? [last.name uppercaseString] : DuoInitials(last.name);
    _lastPlaceholder.font = [DuoTheme semibold:(desk ? 11 : 26) * d];
    _lastIcon.hidden = !(desk && last != nil);
    UIImage* art = last == nil ? nil : [self.delegate duoCoverForHost:c appId:last.appId];
    _lastCover.image = art;
    _lastCover.hidden = art == nil;
}

#pragma mark Clock, glyphs

- (void)updateClock {
    _clock.text = DuoClockText();
    _dateLine.text = DuoDateLine();
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_clockTimer invalidate];
    _clockTimer = nil;
    if (self.window != nil) {
        __weak DuoHomeView* weakSelf = self;
        _clockTimer = [NSTimer scheduledTimerWithTimeInterval:10 repeats:YES block:^(NSTimer* t) {
            [weakSelf updateClock];
        }];
        [self updateClock];
        [self updateGlyphs];
    }
}

- (void)updateGlyphs {
    BOOL pad = [DuoPad shared].hasGamepad;
    for (UIView* p in _pills) {
        p.hidden = !pad;
    }
    for (DuoButton* b in @[_primary, _options, _playAgain, _settings, _quitAll]) {
        [b updateGlyphs:pad];
    }
    [self showFocus:pad];
}

- (void)showFocus:(BOOL)on {
    for (NSInteger i = 0; i < (NSInteger)_focusRow.count; i++) {
        _focusRow[i].duoFocused = on && i == _focus && !_focusRow[i].hidden;
    }
}

#pragma mark Controller

- (BOOL)duoPadKey:(DuoPadKey)key {
    if (self.hidden || self.window == nil) {
        return NO;
    }
    switch (key) {
        case DuoPadLeft:
        case DuoPadRight: {
            NSInteger step = key == DuoPadRight ? 1 : -1;
            for (NSInteger i = _focus + step; i >= 0 && i < (NSInteger)_focusRow.count; i += step) {
                if (!_focusRow[i].hidden) {
                    _focus = i;
                    [DuoMotion navTick];
                    break;
                }
            }
            [self showFocus:YES];
            return YES;
        }
        case DuoPadUp:
        case DuoPadDown:
            [self showFocus:YES];
            return YES;
        case DuoPadLB:
            [self cycle:-1];
            return YES;
        case DuoPadRB:
            [self cycle:1];
            return YES;
        case DuoPadY:
            [_settings fire];
            return YES;
        case DuoPadX:
            if (_playAgain.alpha > 0.9 && _playAgain.enabled) {
                [_playAgain fire];
            }
            return YES;
        case DuoPadStart:
            if (!_quitAll.hidden) {
                [_quitAll fire];
            }
            return YES;
        case DuoPadSelect:
            if (!_options.hidden) {
                [_options fire];
            }
            return YES;
        case DuoPadA: {
            DuoButton* b = _focus < (NSInteger)_focusRow.count ? _focusRow[_focus] : _primary;
            [(b.hidden ? _primary : b) fire];
            return YES;
        }
        case DuoPadB:
            return YES;
    }
    return NO;
}

- (void)dealloc {
    [_clockTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

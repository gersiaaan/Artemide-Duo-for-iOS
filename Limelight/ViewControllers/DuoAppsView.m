//
//  DuoAppsView.m
//  Artemide Duo for iOS
//

#import "DuoAppsView.h"
#import "DuoSupport.h"
#import "DuoWavesView.h"
#import "DataManager.h"
#import "TemporarySettings.h"

extern NSString* DuoClockText(void);
extern NSString* DuoDateLine(void);

static NSArray<NSString*>* DuoTabNames(void) {
    return @[@"ALL", @"GAMES", @"APPS"];
}

static NSString* DuoInitials2(NSString* n) {
    NSMutableString* b = [NSMutableString string];
    for (NSString* w in [n componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
        if (w.length > 0 && b.length < 3) {
            [b appendString:[[w substringToIndex:1] uppercaseString]];
        }
    }
    return b;
}

#pragma mark - Row

@interface DuoAppRow : UIControl
@property (nonatomic, strong) TemporaryApp* app;
@property (nonatomic, strong) UIImageView* thumb;
@end

@implementation DuoAppRow
- (void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    self.backgroundColor = h ? [UIColor colorWithWhite:1 alpha:0x14 / 255.0] : [UIColor clearColor];
    [DuoMotion ease:0.09 delay:0 animations:^{
        self.transform = h ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    } completion:nil];
}
@end

#pragma mark - View

@implementation DuoAppsView {
    CGFloat d;
    NSArray<TemporaryApp*>* _apps;
    NSCache* _cache;
    NSInteger _tab;
    NSString* _selectedId;
    BOOL _opened;
    BOOL _staggered;
    NSString* _shownDetailId;

    UIImageView* _backA;
    UIImageView* _backB;
    BOOL _backFlip;
    UIView* _backScrim;
    DuoWavesView* _frontWaves;

    UILabel* _hostName;
    UIView* _badge;
    UILabel* _badgeLabel;
    UIView* _badgeDot;
    UILabel* _clock;
    UILabel* _dateLine;
    UIStackView* _chips;
    NSArray<UILabel*>* _tabViews;
    NSArray<UIView*>* _underlines;
    NSArray<UIView*>* _pills;

    UIStackView* _body;
    UIScrollView* _listScroll;
    UIView* _listFrame;
    UIStackView* _list;
    UIView* _ring;
    UIStackView* _detail;
    UIStackView* _info;
    UIView* _coverBox;
    CAGradientLayer* _coverBg;
    UIImageView* _bigCover;
    UIImageView* _coverGhost;
    UILabel* _bigPlaceholder;
    UIImageView* _bigIcon;
    UILabel* _bigName;
    UILabel* _statTime;
    UILabel* _statSessions;
    DuoButton* _play;

    DuoButton* _back;
    DuoButton* _settings;
    DuoButton* _fav;
    DuoButton* _options;
    DuoButton* _quitAll;
    BOOL _narrow;
    BOOL _landscape;
    NSTimer* _clockTimer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        d = [DuoTheme scale];
        self.backgroundColor = [DuoTheme floor];
        self.clipsToBounds = YES;
        DuoWavesView* waves = [[DuoWavesView alloc] initWithFrame:self.bounds rise:NO];
        waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:waves];

        // PlayStation-style backdrop: the selected cover, large, blurred and faint behind everything,
        // cross-dissolving between two layers when the selection changes.
        UIView* backdrop = [[UIView alloc] initWithFrame:self.bounds];
        backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        backdrop.userInteractionEnabled = NO;
        backdrop.clipsToBounds = YES;
        _backA = [[UIImageView alloc] initWithFrame:backdrop.bounds];
        _backB = [[UIImageView alloc] initWithFrame:backdrop.bounds];
        for (UIImageView* b in @[_backA, _backB]) {
            b.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            b.contentMode = UIViewContentModeScaleAspectFill;
            b.clipsToBounds = YES;
            b.alpha = 0;
            [backdrop addSubview:b];
        }
        UIVisualEffectView* blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
        blur.frame = backdrop.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.alpha = 0;
        blur.tag = 77;
        [backdrop addSubview:blur];
        _backScrim = [[UIView alloc] initWithFrame:backdrop.bounds];
        _backScrim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backScrim.alpha = 0;
        CAGradientLayer* g = [CAGradientLayer layer];
        UIColor* f = [DuoTheme floor];
        g.colors = @[(id)[f colorWithAlphaComponent:0.92].CGColor, (id)[f colorWithAlphaComponent:0.55].CGColor,
                     (id)[f colorWithAlphaComponent:0.35].CGColor];
        g.startPoint = CGPointMake(0, 0.5);
        g.endPoint = CGPointMake(1, 0.5);
        g.frame = CGRectMake(0, 0, 3000, 3000);
        [_backScrim.layer addSublayer:g];
        [backdrop addSubview:_backScrim];
        [self addSubview:backdrop];
        // Waves in front of the cover backdrop too: pale and faint, only while a game cover shows.
        _frontWaves = [[DuoWavesView alloc] initWithFrame:self.bounds rise:NO];
        _frontWaves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _frontWaves.overlay = YES;
        _frontWaves.alpha = 0;
        [self addSubview:_frontWaves];

        UIView* content = [[UIView alloc] init];
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:content];
        UILayoutGuide* safe = self.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [content.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18 * d],
            [content.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12 * d],
            [content.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:22 * d],
            [content.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-22 * d],
        ]];
        UIStackView* col = [self col:0];
        [content addSubview:col];
        [self pin:col to:content];

        // ---------- header ----------
        UIStackView* header = [self row:10 * d];
        header.alignment = UIStackViewAlignmentTop;
        [header addArrangedSubview:[[DuoLogoView alloc] initWithSize:30 * d]];
        _hostName = DuoText(@"", 20, [DuoTheme text], YES);
        _hostName.lineBreakMode = NSLineBreakByTruncatingTail;
        [_hostName.heightAnchor constraintEqualToConstant:30 * d].active = YES;
        [header addArrangedSubview:_hostName];
        UILabel* bl = nil;
        UIView* bd = nil;
        _badge = DuoBadge(@"", [DuoTheme warn], &bl, &bd);
        _badgeLabel = bl;
        _badgeDot = bd;
        UIView* badgeWrap = [[UIView alloc] init];
        badgeWrap.translatesAutoresizingMaskIntoConstraints = NO;
        [badgeWrap addSubview:_badge];
        [NSLayoutConstraint activateConstraints:@[
            [_badge.topAnchor constraintEqualToAnchor:badgeWrap.topAnchor constant:4 * d],
            [_badge.bottomAnchor constraintEqualToAnchor:badgeWrap.bottomAnchor],
            [_badge.leadingAnchor constraintEqualToAnchor:badgeWrap.leadingAnchor],
            [_badge.trailingAnchor constraintEqualToAnchor:badgeWrap.trailingAnchor],
        ]];
        [header addArrangedSubview:badgeWrap];
        [header addArrangedSubview:[self flex]];
        UIStackView* clockCol = [self col:0];
        clockCol.alignment = UIStackViewAlignmentTrailing;
        _clock = DuoText(@"", 34, [DuoTheme text], NO);
        _clock.font = [DuoTheme digits:34 * d weight:UIFontWeightRegular];
        _dateLine = DuoText(@"", 13.5, [DuoTheme text2], NO);
        [clockCol addArrangedSubview:_clock];
        [clockCol addArrangedSubview:_dateLine];
        [header addArrangedSubview:clockCol];
        [col addArrangedSubview:header];
        [col setCustomSpacing:8 * d afterView:header];

        // ---------- host + stream chips ----------
        UIScrollView* cs = [[DuoScrollView alloc] init];
        cs.translatesAutoresizingMaskIntoConstraints = NO;
        cs.showsHorizontalScrollIndicator = NO;
        _chips = [self row:6 * d];
        [cs addSubview:_chips];
        [NSLayoutConstraint activateConstraints:@[
            [_chips.topAnchor constraintEqualToAnchor:cs.contentLayoutGuide.topAnchor],
            [_chips.bottomAnchor constraintEqualToAnchor:cs.contentLayoutGuide.bottomAnchor],
            [_chips.leadingAnchor constraintEqualToAnchor:cs.contentLayoutGuide.leadingAnchor],
            [_chips.trailingAnchor constraintEqualToAnchor:cs.contentLayoutGuide.trailingAnchor],
            [_chips.heightAnchor constraintEqualToAnchor:cs.frameLayoutGuide.heightAnchor],
            [cs.heightAnchor constraintEqualToConstant:26 * d],
        ]];
        [col addArrangedSubview:cs];
        [col setCustomSpacing:12 * d afterView:cs];

        // ---------- tabs ----------
        UIStackView* tabs = [self row:8 * d];
        [tabs.heightAnchor constraintEqualToConstant:30 * d].active = YES;
        UILabel* lb = DuoKeyPill(@"LB");
        UILabel* rb = DuoKeyPill(@"RB");
        _pills = @[lb, rb];
        [tabs addArrangedSubview:lb];
        [tabs setCustomSpacing:10 * d afterView:lb];
        NSMutableArray* tv = [NSMutableArray array];
        NSMutableArray* ul = [NSMutableArray array];
        for (NSInteger i = 0; i < 3; i++) {
            UIControl* t = [[UIControl alloc] init];
            t.translatesAutoresizingMaskIntoConstraints = NO;
            t.tag = i;
            UILabel* l = DuoText(@"", 12, [DuoTheme text3], YES);
            l.attributedText = [DuoTheme spaced:DuoTabNames()[i] font:[DuoTheme semibold:12 * d] color:[DuoTheme text3] em:0.15];
            [t addSubview:l];
            UIView* u = [[UIView alloc] init];
            u.translatesAutoresizingMaskIntoConstraints = NO;
            u.backgroundColor = [DuoTheme accent];
            [t addSubview:u];
            [NSLayoutConstraint activateConstraints:@[
                [l.leadingAnchor constraintEqualToAnchor:t.leadingAnchor constant:6 * d],
                [l.trailingAnchor constraintEqualToAnchor:t.trailingAnchor constant:-6 * d],
                [l.centerYAnchor constraintEqualToAnchor:t.centerYAnchor],
                [t.heightAnchor constraintEqualToConstant:30 * d],
                [u.leadingAnchor constraintEqualToAnchor:t.leadingAnchor constant:6 * d],
                [u.trailingAnchor constraintEqualToAnchor:t.trailingAnchor constant:-6 * d],
                [u.bottomAnchor constraintEqualToAnchor:t.bottomAnchor],
                [u.heightAnchor constraintEqualToConstant:3 * d],
            ]];
            [t addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
            [tabs addArrangedSubview:t];
            [tv addObject:l];
            [ul addObject:u];
        }
        _tabViews = tv;
        _underlines = ul;
        [tabs setCustomSpacing:10 * d afterView:tabs.arrangedSubviews.lastObject];
        [tabs addArrangedSubview:rb];
        [tabs addArrangedSubview:[self flex]];
        [col addArrangedSubview:tabs];
        [col setCustomSpacing:8 * d afterView:tabs];

        // ---------- body ----------
        _body = [[UIStackView alloc] init];
        _body.translatesAutoresizingMaskIntoConstraints = NO;
        _body.alignment = UIStackViewAlignmentFill;
        _listScroll = [[DuoScrollView alloc] init];
        _listScroll.translatesAutoresizingMaskIntoConstraints = NO;
        _listScroll.showsVerticalScrollIndicator = NO;
        _listScroll.alwaysBounceVertical = YES;
        _listScroll.delaysContentTouches = NO;
        _listFrame = [[UIView alloc] init];
        _listFrame.translatesAutoresizingMaskIntoConstraints = NO;
        [_listScroll addSubview:_listFrame];
        // The selection ring is one view that glides from row to row (under the rows).
        _ring = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 62 * d)];
        _ring.backgroundColor = [[DuoTheme accent] colorWithAlphaComponent:0.07];
        _ring.layer.cornerRadius = 10 * d;
        _ring.layer.borderWidth = 1.5 * d;
        _ring.layer.borderColor = [DuoTheme focus].CGColor;
        _ring.alpha = 0;
        _ring.userInteractionEnabled = NO;
        [_listFrame addSubview:_ring];
        _list = [self col:0];
        [_listFrame addSubview:_list];
        [NSLayoutConstraint activateConstraints:@[
            [_listFrame.topAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.topAnchor],
            [_listFrame.bottomAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.bottomAnchor],
            [_listFrame.leadingAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.leadingAnchor],
            [_listFrame.trailingAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.trailingAnchor],
            [_listFrame.widthAnchor constraintEqualToAnchor:_listScroll.frameLayoutGuide.widthAnchor],
            [_list.topAnchor constraintEqualToAnchor:_listFrame.topAnchor],
            [_list.bottomAnchor constraintEqualToAnchor:_listFrame.bottomAnchor constant:-8 * d],
            [_list.leadingAnchor constraintEqualToAnchor:_listFrame.leadingAnchor],
            [_list.trailingAnchor constraintEqualToAnchor:_listFrame.trailingAnchor],
        ]];
        [self buildDetail];
        _landscape = YES;
        [self applyOrientation];
        [col addArrangedSubview:_body];
        [col setCustomSpacing:12 * d afterView:_body];

        // ---------- bottom ----------
        UIStackView* bottom = [self row:8 * d];
        [bottom.heightAnchor constraintEqualToConstant:36 * d].active = YES;
        __weak DuoAppsView* weakSelf = self;
        _back = [self button:@"‹  Back" glyph:@"B" tap:^{
            [weakSelf.delegate duoBackToHosts];
        }];
        _settings = [self button:@"Settings" glyph:@"Y" tap:^{
            [weakSelf.delegate duoOpenSettings];
        }];
        // Favourite on / off for the selected app (X).
        _fav = [self button:@"Add favourite" glyph:@"X" tap:^{
            DuoAppsView* s = weakSelf;
            TemporaryApp* a = [s selectedApp];
            if (a != nil) {
                [s togglePin:a];
            }
        }];
        // Options: the View button (⧉, left of the Xbox button).
        _options = [self button:@"Options" glyph:@"⧉" tap:^{
            DuoAppsView* s = weakSelf;
            TemporaryApp* a = [s selectedApp];
            if (a != nil) {
                [s.delegate duoAppOptions:a view:s->_options];
            }
        }];
        // Quit everything running on this PC (Menu ≡), no questions asked.
        _quitAll = [self button:@"Quit all sessions" glyph:@"≡" tap:^{
            DuoAppsView* s = weakSelf;
            if (s.host != nil) {
                [s.delegate duoQuitAll:s.host];
            }
        }];
        for (DuoButton* b in @[_back, _settings, _fav, _options]) {
            [bottom addArrangedSubview:b];
        }
        [bottom addArrangedSubview:[self flex]];
        [bottom addArrangedSubview:_quitAll];
        [col addArrangedSubview:bottom];

        [self setTab:0];
        [self updateClock];
        [self updateGlyphs];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateGlyphs) name:DuoPadChangedNotification object:nil];
    }
    return self;
}

#pragma mark helpers

- (UIStackView*)row:(CGFloat)spacing {
    UIStackView* s = [[UIStackView alloc] init];
    s.axis = UILayoutConstraintAxisHorizontal;
    s.alignment = UIStackViewAlignmentCenter;
    s.spacing = spacing;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    return s;
}

- (UIStackView*)col:(CGFloat)spacing {
    UIStackView* s = [[UIStackView alloc] init];
    s.axis = UILayoutConstraintAxisVertical;
    s.spacing = spacing;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    return s;
}

- (UIView*)flex {
    UIView* v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [v setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [v setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [v setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [v setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisVertical];
    return v;
}

- (void)pin:(UIView*)v to:(UIView*)p {
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:p.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:p.bottomAnchor],
        [v.leadingAnchor constraintEqualToAnchor:p.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:p.trailingAnchor],
    ]];
}

- (DuoButton*)button:(NSString*)title glyph:(NSString*)glyph tap:(void (^)(void))tap {
    DuoButton* b = [[DuoButton alloc] initWithTitle:title glyph:glyph primary:NO];
    b.onTap = tap;
    [b.heightAnchor constraintEqualToConstant:36 * d].active = YES;
    return b;
}

#pragma mark detail

- (void)buildDetail {
    _detail = [[UIStackView alloc] init];
    _detail.translatesAutoresizingMaskIntoConstraints = NO;

    _coverBox = [[UIView alloc] init];
    _coverBox.translatesAutoresizingMaskIntoConstraints = NO;
    _coverBox.layer.cornerRadius = 12 * d;
    _coverBox.layer.shadowColor = [UIColor blackColor].CGColor;
    _coverBox.layer.shadowOpacity = 0.5;
    _coverBox.layer.shadowRadius = 10 * d;
    _coverBox.layer.shadowOffset = CGSizeMake(0, 6 * d);
    UIView* clip = [[UIView alloc] init];
    clip.translatesAutoresizingMaskIntoConstraints = NO;
    clip.layer.cornerRadius = 12 * d;
    clip.layer.borderWidth = 1;
    clip.layer.borderColor = [DuoTheme line].CGColor;
    clip.clipsToBounds = YES;
    [_coverBox addSubview:clip];
    [self pin:clip to:_coverBox];
    _coverBg = DuoPlaceholderLayer();
    [clip.layer insertSublayer:_coverBg atIndex:0];
    UIStackView* ph = [self col:8 * d];
    ph.alignment = UIStackViewAlignmentCenter;
    _bigIcon = [[UIImageView alloc] initWithImage:DuoMonitorIcon(40 * d, [DuoTheme text])];
    _bigIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _bigPlaceholder = DuoText(@"", 13, [DuoTheme text], YES);
    _bigPlaceholder.textAlignment = NSTextAlignmentCenter;
    _bigPlaceholder.numberOfLines = 3;
    [ph addArrangedSubview:_bigIcon];
    [ph addArrangedSubview:_bigPlaceholder];
    [clip addSubview:ph];
    _bigCover = [[UIImageView alloc] init];
    _coverGhost = [[UIImageView alloc] init];
    for (UIImageView* iv in @[_bigCover, _coverGhost]) {
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        [clip addSubview:iv];
        [self pin:iv to:clip];
    }
    _coverGhost.alpha = 0;
    CGFloat cw = 124 * 1.2 * d;
    NSLayoutConstraint* h = [_coverBox.heightAnchor constraintEqualToConstant:cw * 1.41];
    h.priority = UILayoutPriorityDefaultLow;
    [NSLayoutConstraint activateConstraints:@[
        [ph.centerXAnchor constraintEqualToAnchor:clip.centerXAnchor],
        [ph.centerYAnchor constraintEqualToAnchor:clip.centerYAnchor],
        [ph.widthAnchor constraintLessThanOrEqualToAnchor:clip.widthAnchor constant:-12 * d],
        h,
        [_coverBox.heightAnchor constraintLessThanOrEqualToConstant:cw * 1.41],
        [_coverBox.heightAnchor constraintGreaterThanOrEqualToConstant:100 * d],
        [_coverBox.widthAnchor constraintEqualToAnchor:_coverBox.heightAnchor multiplier:1 / 1.41],
    ]];
    [_coverBox setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];

    _info = [self col:0];
    _bigName = DuoText(@"", 19, [DuoTheme text], YES);
    _bigName.lineBreakMode = NSLineBreakByTruncatingTail;
    [_info addArrangedSubview:_bigName];
    [_info setCustomSpacing:10 * d afterView:_bigName];
    UIStackView* stats = [self row:26 * d];
    _statTime = [self stat:stats label:@"PLAYED"];
    _statSessions = [self stat:stats label:@"SESSIONS"];
    [_info addArrangedSubview:stats];
    [_info setCustomSpacing:12 * d afterView:stats];
    __weak DuoAppsView* weakSelf = self;
    _play = [self button:@"Open" glyph:@"A" tap:^{
        DuoAppsView* s = weakSelf;
        TemporaryApp* a = [s selectedApp];
        if (a != nil) {
            [s.delegate duoStartApp:a view:s->_play];
        }
    }];
    [_info addArrangedSubview:_play];

    [_detail addArrangedSubview:_coverBox];
    [_detail addArrangedSubview:_info];
}

- (UILabel*)stat:(UIStackView*)parent label:(NSString*)label {
    UIStackView* c = [self col:3 * d];
    c.alignment = UIStackViewAlignmentCenter;
    UILabel* v = DuoText(@"–", 17, [DuoTheme text], YES);
    UILabel* l = DuoText(@"", 9, [DuoTheme text2], NO);
    l.attributedText = [DuoTheme spaced:label font:[DuoTheme regular:9 * d] color:[DuoTheme text2] em:0.15];
    [c addArrangedSubview:v];
    [c addArrangedSubview:l];
    [parent addArrangedSubview:c];
    return v;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _coverBg.frame = _coverBox.bounds;
    BOOL land = self.bounds.size.width >= self.bounds.size.height;
    if (land != _landscape) {
        _landscape = land;
        [self applyOrientation];
    }
    BOOL narrow = self.bounds.size.width > 0 && self.bounds.size.width / d < 760;
    if (narrow != _narrow) {
        _narrow = narrow;
        [_quitAll setTitle:narrow ? @"Quit all" : @"Quit all sessions"];
        [self renderDetail];
    }
    [self moveRing:NO];
}

- (void)applyOrientation {
    for (UIView* v in _body.arrangedSubviews.copy) {
        [_body removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (NSLayoutConstraint* c in _body.constraints.copy) {
        if ([c.identifier isEqualToString:@"duoWeight"]) {
            c.active = NO;
        }
    }
    if (_landscape) {
        _body.axis = UILayoutConstraintAxisHorizontal;
        _body.spacing = 18 * d;
        _detail.axis = UILayoutConstraintAxisVertical;
        _detail.alignment = UIStackViewAlignmentCenter;
        _detail.spacing = 12 * d;
        _info.alignment = UIStackViewAlignmentCenter;
        _bigName.textAlignment = NSTextAlignmentCenter;
        UIStackView* wrap = [self col:0];
        wrap.alignment = UIStackViewAlignmentCenter;
        UIView* topGap = [[UIView alloc] init];
        topGap.translatesAutoresizingMaskIntoConstraints = NO;
        [topGap.heightAnchor constraintEqualToConstant:10 * d].active = YES;
        [wrap addArrangedSubview:topGap];
        [wrap addArrangedSubview:_detail];
        [wrap addArrangedSubview:[self flex]];
        [_body addArrangedSubview:_listScroll];
        [_body addArrangedSubview:wrap];
        NSLayoutConstraint* w = [wrap.widthAnchor constraintEqualToAnchor:_listScroll.widthAnchor multiplier:1 / 1.45];
        w.identifier = @"duoWeight";
        [_body addConstraint:w];
        [_bigName.widthAnchor constraintLessThanOrEqualToAnchor:wrap.widthAnchor].active = YES;
    } else {
        _body.axis = UILayoutConstraintAxisVertical;
        _body.spacing = 10 * d;
        _detail.axis = UILayoutConstraintAxisHorizontal;
        _detail.alignment = UIStackViewAlignmentCenter;
        _detail.spacing = 16 * d;
        _info.alignment = UIStackViewAlignmentLeading;
        _bigName.textAlignment = NSTextAlignmentNatural;
        [_body addArrangedSubview:_detail];
        [_body addArrangedSubview:_listScroll];
    }
}

#pragma mark data

- (void)showApps:(NSArray<TemporaryApp*>*)apps host:(TemporaryHost*)host cache:(NSCache*)cache {
    if (_host != host) {
        _opened = NO;
        _staggered = NO;
        _tab = 0;
        [self setTab:0];
    }
    _host = host;
    _apps = apps;
    _cache = cache;
    [self refresh];
}

- (void)refresh {
    TemporaryHost* c = _host;
    if (c != nil) {
        _hostName.text = c.name;
        NSString* st = c.state == StateOnline ? @"ONLINE" : c.state == StateOffline ? @"OFFLINE" : @"CHECKING";
        _badgeLabel.attributedText = [DuoTheme spaced:st font:[DuoTheme semibold:10 * d] color:[DuoTheme text] em:0.1];
        _badgeDot.backgroundColor = c.state == StateOnline ? [DuoTheme online] : c.state == StateOffline ? [DuoTheme offline] : [DuoTheme warn];
    }
    [self fillChips];
    [self renderList];
}

- (BOOL)isRunning:(TemporaryApp*)a {
    return _host != nil && a.id != nil && [a.id isEqualToString:_host.currentGame];
}

- (BOOL)inTab:(TemporaryApp*)a {
    return _tab == 0 || ((_tab == 1) != [DuoPrefs isAppName:a.name]);
}

- (void)tabTapped:(UIControl*)sender {
    [self setTab:sender.tag];
}

- (void)setTab:(NSInteger)t {
    NSInteger dir = t > _tab ? 1 : t < _tab ? -1 : 0;
    BOOL changed = t != _tab;
    _tab = t;
    if (changed) {
        _selectedId = nil;  // the new tab starts on its first app (LAST PLAYED first)
    }
    for (NSInteger i = 0; i < 3; i++) {
        UIColor* c = i == t ? [DuoTheme text] : [DuoTheme text3];
        _tabViews[i].attributedText = [DuoTheme spaced:DuoTabNames()[i] font:[DuoTheme semibold:12 * d] color:c em:0.15];
        _underlines[i].hidden = i != t;
    }
    [self renderList];
    if (changed) {
        _listScroll.contentOffset = CGPointZero;
        // The list slides in from the side of the new tab, rows rising one after the other.
        [DuoMotion slideIn:_listScroll dir:dir distance:28 * d];
        [DuoMotion stagger:[self rows]];
    }
}

- (NSArray<UIView*>*)rows {
    NSMutableArray* r = [NSMutableArray array];
    for (UIView* v in _list.arrangedSubviews) {
        if ([v.subviews.firstObject isKindOfClass:[DuoAppRow class]]) {
            [r addObject:v];
        }
    }
    return r;
}

- (TemporaryApp*)selectedApp {
    for (TemporaryApp* a in _apps) {
        if (_selectedId != nil && [a.id isEqualToString:_selectedId]) {
            return a;
        }
    }
    return nil;
}

- (void)renderList {
    for (UIView* v in _list.arrangedSubviews.copy) {
        [v removeFromSuperview];
    }
    TemporaryHost* c = _host;
    DuoLastPlayed* last = c == nil ? nil : [DuoPlayStats lastForHost:c.uuid];
    TemporaryApp* lastApp = nil;
    NSMutableArray<TemporaryApp*>* pinned = [NSMutableArray array];
    NSMutableArray<TemporaryApp*>* rest = [NSMutableArray array];
    for (TemporaryApp* a in _apps) {
        if (![self inTab:a]) {
            continue;
        }
        if (last != nil && [a.id isEqualToString:last.appId] && lastApp == nil) {
            lastApp = a;
        } else if (c != nil && [DuoPlayStats isPinnedHost:c.uuid app:a.id]) {
            [pinned addObject:a];
        } else {
            [rest addObject:a];
        }
    }
    // Opening the list starts on the last played app (or the first one).
    if (!_opened && _apps.count > 0) {
        _opened = YES;
        _selectedId = nil;
    }
    BOOL inThisTab = NO;
    for (TemporaryApp* a in _apps) {
        inThisTab |= (_selectedId != nil && [a.id isEqualToString:_selectedId] && [self inTab:a]);
    }
    if (_selectedId == nil || !inThisTab) {
        _selectedId = lastApp != nil ? lastApp.id : pinned.count > 0 ? pinned[0].id : rest.firstObject.id;
    }
    if (lastApp != nil) {
        [_list addArrangedSubview:[self section:@"LAST PLAYED" color:[DuoTheme accent]]];
        [_list addArrangedSubview:[self rowFor:lastApp]];
    }
    if (pinned.count > 0) {
        [_list addArrangedSubview:[self section:@"FAVOURITES" color:[DuoTheme text2]]];
        for (TemporaryApp* a in pinned) {
            [_list addArrangedSubview:[self rowFor:a]];
        }
    }
    if (rest.count > 0) {
        [_list addArrangedSubview:[self section:DuoTabNames()[_tab] color:[DuoTheme text2]]];
        for (TemporaryApp* a in rest) {
            [_list addArrangedSubview:[self rowFor:a]];
        }
    }
    if (lastApp == nil && rest.count == 0 && pinned.count == 0) {
        UILabel* empty = DuoText(_apps.count == 0 ? @"Loading apps…" : @"Nothing here", 13, [DuoTheme text2], NO);
        if (_apps.count == 0) {
            [DuoMotion pulse:empty];
        }
        UIView* wrap = [[UIView alloc] init];
        wrap.translatesAutoresizingMaskIntoConstraints = NO;
        [wrap addSubview:empty];
        [NSLayoutConstraint activateConstraints:@[
            [empty.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:18 * d],
            [empty.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
            [empty.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
        ]];
        [_list addArrangedSubview:wrap];
    }
    [self renderDetail];
    [_list layoutIfNeeded];
    [self moveRing:NO];
    if (!_staggered && _apps.count > 0) {
        _staggered = YES;
        [DuoMotion stagger:[self rows]];
    }
}

- (UIView*)section:(NSString*)title color:(UIColor*)color {
    UIView* w = [[UIView alloc] init];
    w.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel* t = DuoText(@"", 9.5, color, YES);
    t.attributedText = [DuoTheme spaced:title font:[DuoTheme semibold:9.5 * d] color:color em:0.15];
    [w addSubview:t];
    [NSLayoutConstraint activateConstraints:@[
        [t.topAnchor constraintEqualToAnchor:w.topAnchor constant:10 * d],
        [t.bottomAnchor constraintEqualToAnchor:w.bottomAnchor constant:-2 * d],
        [t.leadingAnchor constraintEqualToAnchor:w.leadingAnchor constant:2 * d],
    ]];
    return w;
}

- (UIView*)rowFor:(TemporaryApp*)a {
    DuoAppRow* r = [[DuoAppRow alloc] init];
    r.translatesAutoresizingMaskIntoConstraints = NO;
    r.app = a;
    r.layer.cornerRadius = 10 * d;
    UIView* thumb = [[UIView alloc] init];
    thumb.translatesAutoresizingMaskIntoConstraints = NO;
    thumb.layer.cornerRadius = 5 * d;
    thumb.clipsToBounds = YES;
    thumb.userInteractionEnabled = NO;
    CAGradientLayer* bg = DuoPlaceholderLayer();
    bg.frame = CGRectMake(0, 0, 38 * d, 54 * d);
    [thumb.layer addSublayer:bg];
    UIView* ph;
    if ([DuoPrefs isAppName:a.name]) {
        UIImageView* icon = [[UIImageView alloc] initWithImage:DuoMonitorIcon(26 * d, [DuoTheme text])];
        icon.contentMode = UIViewContentModeCenter;
        ph = icon;
    } else {
        UILabel* t = DuoText(DuoInitials2(a.name ?: @""), 9, [DuoTheme text], YES);
        t.textAlignment = NSTextAlignmentCenter;
        ph = t;
    }
    ph.translatesAutoresizingMaskIntoConstraints = NO;
    [thumb addSubview:ph];
    [self pin:ph to:thumb];
    UIImageView* iv = [[UIImageView alloc] init];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.image = [_cache objectForKey:a];
    [thumb addSubview:iv];
    [self pin:iv to:thumb];
    r.thumb = iv;
    [r addSubview:thumb];

    UIStackView* texts = [self col:3 * d];
    texts.userInteractionEnabled = NO;
    UILabel* n = DuoText([a.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] ?: @"", 14, [DuoTheme text], NO);
    n.lineBreakMode = NSLineBreakByTruncatingTail;
    [texts addArrangedSubview:n];
    NSString* sub = @"";
    UIColor* subColor = [DuoTheme text2];
    if ([self isRunning:a]) {
        sub = @"Running now";
        subColor = [DuoTheme accent];
    } else if (_host != nil) {
        NSTimeInterval t = [DuoPlayStats timeForHost:_host.uuid app:a.id];
        sub = t > 0 ? [DuoPlayStats duration:t] : @"";
    }
    if (sub.length > 0) {
        [texts addArrangedSubview:DuoText(sub, 11, subColor, NO)];
    }
    [r addSubview:texts];
    [NSLayoutConstraint activateConstraints:@[
        [r.heightAnchor constraintEqualToConstant:62 * d],
        [thumb.leadingAnchor constraintEqualToAnchor:r.leadingAnchor constant:10 * d],
        [thumb.centerYAnchor constraintEqualToAnchor:r.centerYAnchor],
        [thumb.widthAnchor constraintEqualToConstant:38 * d],
        [thumb.heightAnchor constraintEqualToConstant:54 * d],
        [texts.leadingAnchor constraintEqualToAnchor:thumb.trailingAnchor constant:12 * d],
        [texts.trailingAnchor constraintEqualToAnchor:r.trailingAnchor constant:-10 * d],
        [texts.centerYAnchor constraintEqualToAnchor:r.centerYAnchor],
    ]];
    [r addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
    [r addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(rowLong:)]];
    // 5 pt gap above each row.
    UIView* wrap = [[UIView alloc] init];
    wrap.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:r];
    [NSLayoutConstraint activateConstraints:@[
        [r.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:5 * d],
        [r.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
        [r.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
        [r.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor],
    ]];
    return wrap;
}

- (NSArray<DuoAppRow*>*)appRows {
    NSMutableArray* r = [NSMutableArray array];
    for (UIView* w in _list.arrangedSubviews) {
        DuoAppRow* row = w.subviews.firstObject;
        if ([row isKindOfClass:[DuoAppRow class]]) {
            [r addObject:row];
        }
    }
    return r;
}

- (DuoAppRow*)selectedRow {
    for (DuoAppRow* r in [self appRows]) {
        if (_selectedId != nil && [r.app.id isEqualToString:_selectedId]) {
            return r;
        }
    }
    return nil;
}

- (void)rowTapped:(DuoAppRow*)r {
    if (_selectedId != nil && [r.app.id isEqualToString:_selectedId]) {
        [self.delegate duoStartApp:r.app view:r];   // second tap on the selected row starts it
    } else {
        [self select:r.app];
    }
}

- (void)rowLong:(UILongPressGestureRecognizer*)g {
    if (g.state == UIGestureRecognizerStateBegan && [g.view isKindOfClass:[DuoAppRow class]]) {
        [self togglePin:((DuoAppRow*)g.view).app];
    }
}

- (void)select:(TemporaryApp*)a {
    if (_selectedId != nil && [a.id isEqualToString:_selectedId]) {
        return;
    }
    _selectedId = a.id;
    [self moveRing:YES];
    [self renderDetail];
}

- (void)togglePin:(TemporaryApp*)a {
    if (_host == nil) {
        return;
    }
    BOOL now = [DuoPlayStats isPinnedHost:_host.uuid app:a.id];
    [DuoPlayStats setPinned:!now host:_host.uuid app:a.id];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    _selectedId = a.id;
    [self renderList];
}

/// Glides the selection ring to the selected row.
- (void)moveRing:(BOOL)animate {
    DuoAppRow* row = [self selectedRow];
    if (row == nil) {
        [UIView animateWithDuration:0.18 animations:^{
            self->_ring.alpha = 0;
        }];
        return;
    }
    [_listFrame layoutIfNeeded];
    CGRect f = [row convertRect:row.bounds toView:_listFrame];
    if (f.size.height == 0) {
        return;
    }
    if (animate && _ring.alpha > 0.5) {
        [DuoMotion ease:0.3 delay:0 animations:^{
            self->_ring.frame = f;
            self->_ring.alpha = 1;
        } completion:nil];
    } else {
        _ring.frame = f;
        [DuoMotion ease:0.24 delay:0 animations:^{
            self->_ring.alpha = 1;
        } completion:nil];
    }
}

- (void)scrollToSelected {
    DuoAppRow* row = [self selectedRow];
    if (row == nil) {
        return;
    }
    CGRect f = [row convertRect:row.bounds toView:_listScroll];
    f = CGRectInset(f, 0, -24 * d);
    [_listScroll scrollRectToVisible:f animated:YES];
}

- (void)renderDetail {
    TemporaryApp* a = [self selectedApp];
    TemporaryHost* c = _host;
    BOOL has = a != nil;
    _play.hidden = !has;
    BOOL anyRunning = NO, terminate = NO;
    for (TemporaryApp* x in _apps) {
        anyRunning |= [self isRunning:x];
        terminate |= [[[x.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString] isEqualToString:@"terminate"];
    }
    BOOL online = c != nil && c.state == StateOnline;
    BOOL hostRunning = c != nil && c.currentGame != nil && ![c.currentGame isEqualToString:@"0"];
    _quitAll.hidden = !(online && (anyRunning || hostRunning || terminate));
    _fav.enabled = has;
    _options.enabled = has;
    if (has && c != nil) {
        BOOL pinned = [DuoPlayStats isPinnedHost:c.uuid app:a.id];
        // Narrow screens (iPhone): shorter labels so the bottom bar never overflows.
        [_fav setTitle:_narrow ? (pinned ? @"Unfavourite" : @"Favourite") : (pinned ? @"Remove favourite" : @"Add favourite")];
    }
    if (!has) {
        _bigName.text = @"";
        _statTime.text = @"–";
        _statSessions.text = @"–";
        _bigCover.image = nil;
        _bigPlaceholder.text = @"";
        _bigIcon.hidden = YES;
        return;
    }
    _bigName.text = a.name;
    BOOL newDetail = ![a.id isEqualToString:_shownDetailId];
    _shownDetailId = a.id;
    UIImage* art = [_cache objectForKey:a];
    BOOL isGame = ![DuoPrefs isAppName:a.name];
    if (newDetail) {
        // Cross dissolve: the old cover on top fades out while the new one is already underneath.
        if (_bigCover.image != nil) {
            _coverGhost.image = _bigCover.image;
            _coverGhost.alpha = 1;
            [UIView animateWithDuration:0.46 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self->_coverGhost.alpha = 0;
            } completion:nil];
        } else {
            [DuoMotion fadeIn:_coverBox duration:0.38];
        }
        _coverBox.transform = CGAffineTransformMakeScale(0.985, 0.985);
        [DuoMotion ease:0.46 delay:0 animations:^{
            self->_coverBox.transform = CGAffineTransformIdentity;
        } completion:nil];
        [DuoMotion fadeIn:_bigName duration:0.38];
        [self backdrop:isGame ? art : nil];
    }
    [_play setTitle:[self isRunning:a] ? @"Resume" : @"Open"];
    NSTimeInterval t = c == nil ? 0 : [DuoPlayStats timeForHost:c.uuid app:a.id];
    NSInteger sessions = c == nil ? 0 : [DuoPlayStats sessionsForHost:c.uuid app:a.id];
    _statTime.text = t > 0 ? [DuoPlayStats duration:t] : @"–";
    if (newDetail) {
        [DuoMotion countUp:_statSessions to:sessions];
    } else {
        _statSessions.text = [NSString stringWithFormat:@"%ld", (long)sessions];
    }
    _bigPlaceholder.text = isGame ? DuoInitials2(a.name) : [a.name uppercaseString];
    _bigPlaceholder.font = [DuoTheme semibold:(isGame ? 28 : 13) * d];
    _bigIcon.hidden = isGame;
    _bigCover.image = art;
    _bigCover.hidden = art == nil;
}

- (void)backdrop:(UIImage*)art {
    UIView* blur = [_backA.superview viewWithTag:77];
    if (art == nil) {
        // Apps (Desktop, Remote …): the normal background, no cover, no veil.
        [DuoMotion ease:0.7 delay:0 animations:^{
            self->_backA.alpha = 0;
            self->_backB.alpha = 0;
            self->_backScrim.alpha = 0;
            blur.alpha = 0;
            self->_frontWaves.alpha = 0;
        } completion:nil];
        return;
    }
    UIImageView* next = _backFlip ? _backA : _backB;
    UIImageView* prev = _backFlip ? _backB : _backA;
    _backFlip = !_backFlip;
    [next.layer removeAllAnimations];
    next.alpha = 0;
    next.image = art;
    next.transform = CGAffineTransformIdentity;
    // Soft blend (no flash): the new cover rises while the old one sinks, both slowly.
    [DuoMotion curve:CGPointMake(0.45, 0) :CGPointMake(0.25, 1) duration:1.1 delay:0 animations:^{
        next.alpha = 0.34;
        prev.alpha = 0;
    } completion:nil];
    [DuoMotion ease:0.9 delay:0 animations:^{
        self->_backScrim.alpha = 1;
        blur.alpha = 1;
        self->_frontWaves.alpha = 1;
    } completion:nil];
    // Slow, subtle zoom (Ken Burns) on the cover in the back.
    [UIView animateWithDuration:18 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        next.transform = CGAffineTransformMakeScale(1.09, 1.09);
    } completion:nil];
}

- (void)fillChips {
    for (UIView* v in _chips.arrangedSubviews.copy) {
        [v removeFromSuperview];
    }
    TemporaryHost* c = _host;
    NSString* addr = c == nil ? nil : (c.activeAddress ?: (c.localAddress ?: c.address));
    [_chips addArrangedSubview:[self chipLabel:@"HOST"]];
    [_chips addArrangedSubview:DuoInfoChip(addr ?: @"–")];
    UIView* sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [DuoTheme line];
    [NSLayoutConstraint activateConstraints:@[
        [sep.widthAnchor constraintEqualToConstant:1],
        [sep.heightAnchor constraintEqualToConstant:16 * d],
    ]];
    [_chips addArrangedSubview:sep];
    [_chips setCustomSpacing:10 * d afterView:sep];
    [_chips addArrangedSubview:[self chipLabel:@"STREAM"]];
    TemporarySettings* p = [[[DataManager alloc] init] getSettings];
    if (p == nil) {
        return;
    }
    NSInteger fps = [DuoPrefs customFps] > 0 ? [DuoPrefs customFps] : [p.framerate integerValue];
    NSString* codec = p.preferredCodec == CODEC_PREF_HEVC ? @"HEVC" : p.preferredCodec == CODEC_PREF_AV1 ? @"AV1"
        : p.preferredCodec == CODEC_PREF_H264 ? @"H.264" : @"Auto codec";
    int ch = [p.audioConfig intValue];
    for (NSString* s in @[[NSString stringWithFormat:@"%d×%d", [p.width intValue], [p.height intValue]],
                          [NSString stringWithFormat:@"%ld FPS", (long)fps],
                          [NSString stringWithFormat:@"%ld Mbps", lroundf([p.bitrate intValue] / 1000.0f)],
                          codec, ch >= 8 ? @"7.1" : ch >= 6 ? @"5.1" : @"Stereo"]) {
        [_chips addArrangedSubview:DuoInfoChip(s)];
    }
}

- (UILabel*)chipLabel:(NSString*)s {
    UILabel* t = DuoText(@"", 9.5, [DuoTheme text2], NO);
    t.attributedText = [DuoTheme spaced:s font:[DuoTheme regular:9.5 * d] color:[DuoTheme text2] em:0.15];
    return t;
}

#pragma mark clock, glyphs

- (void)updateClock {
    _clock.text = DuoClockText();
    _dateLine.text = DuoDateLine();
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_clockTimer invalidate];
    _clockTimer = nil;
    if (self.window != nil) {
        __weak DuoAppsView* weakSelf = self;
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
    for (DuoButton* b in @[_play, _back, _settings, _fav, _options, _quitAll]) {
        [b updateGlyphs:pad];
    }
}

#pragma mark controller

- (BOOL)duoPadKey:(DuoPadKey)key {
    if (self.hidden || self.window == nil) {
        return NO;
    }
    switch (key) {
        case DuoPadUp:
        case DuoPadDown: {
            // Step row by row in list order (LAST PLAYED → FAVOURITES → ALL), never skipping a section.
            NSArray<DuoAppRow*>* rows = [self appRows];
            NSInteger i = [rows indexOfObject:[self selectedRow]];
            if (i == NSNotFound) {
                i = -1;
            }
            NSInteger j = i + (key == DuoPadDown ? 1 : -1);
            if (j >= 0 && j < (NSInteger)rows.count) {
                [self select:rows[j].app];
                [self scrollToSelected];
                if (j == 0) {
                    [_listScroll setContentOffset:CGPointZero animated:YES];
                }
                [DuoMotion navTick];
            }
            return YES;
        }
        case DuoPadLeft:
        case DuoPadRight:
            return YES;
        case DuoPadLB:
            [self setTab:(_tab + 2) % 3];
            return YES;
        case DuoPadRB:
            [self setTab:(_tab + 1) % 3];
            return YES;
        case DuoPadY:
            [_settings fire];
            return YES;
        case DuoPadX:
            [_fav fire];
            return YES;
        case DuoPadStart:
            if (!_quitAll.hidden) {
                [_quitAll fire];
            }
            return YES;
        case DuoPadSelect:
            [_options fire];
            return YES;
        case DuoPadB:
            [_back fire];
            return YES;
        case DuoPadA: {
            DuoAppRow* r = [self selectedRow];
            if (r != nil) {
                [DuoMotion tap:r];
                [self.delegate duoStartApp:r.app view:r];
            }
            return YES;
        }
    }
    return NO;
}

- (void)dealloc {
    [_clockTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

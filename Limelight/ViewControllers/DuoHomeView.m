//
//  DuoHomeView.m
//  Artemide Duo for iOS
//

#import "DuoHomeView.h"
#import "DuoSupport.h"
#import "DuoWavesView.h"
#import "DataManager.h"
#import "TemporarySettings.h"

static NSString* const kSelectedHost = @"duo_home_selected_host";

#pragma mark - Small building blocks

static UILabel* DuoLabel(NSString* text, CGFloat size, UIFontWeight weight, UIColor* color) {
    UILabel* l = [[UILabel alloc] init];
    l.text = text;
    l.font = [DuoTheme font:size weight:weight];
    l.textColor = color;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

static UIView* DuoSpacer(void) {
    UIView* v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [v setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [v setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [v setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    return v;
}

static UIStackView* DuoStack(UILayoutConstraintAxis axis, CGFloat spacing) {
    UIStackView* s = [[UIStackView alloc] init];
    s.axis = axis;
    s.spacing = spacing;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    return s;
}

/// Pill button: outline (secondary) or accent filled (primary).
static UIButton* DuoButton(NSString* title, BOOL primary) {
    UIButtonConfiguration* c = primary ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration];
    c.title = title;
    c.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    c.contentInsets = NSDirectionalEdgeInsetsMake(10, 18, 10, 18);
    c.baseForegroundColor = primary ? [DuoTheme hex:0x00262C] : [DuoTheme text];
    c.baseBackgroundColor = primary ? [DuoTheme accent] : [UIColor colorWithWhite:1.0 alpha:0.09];
    if (!primary) {
        c.background.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
        c.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.16];
        c.background.strokeWidth = 1;
    }
    c.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id>* (NSDictionary<NSAttributedStringKey, id>* in) {
        NSMutableDictionary* out = [in mutableCopy];
        out[NSFontAttributeName] = [DuoTheme font:15 weight:primary ? UIFontWeightSemibold : UIFontWeightMedium];
        return out;
    };
    UIButton* b = [UIButton buttonWithConfiguration:c primaryAction:nil];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

static UILabel* DuoChip(NSString* text) {
    UILabel* l = DuoLabel([NSString stringWithFormat:@"  %@  ", text], 13, UIFontWeightMedium, [DuoTheme text]);
    l.layer.cornerRadius = 8;
    l.layer.borderWidth = 1;
    l.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    l.layer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25].CGColor;
    l.clipsToBounds = YES;
    [l.heightAnchor constraintEqualToConstant:30].active = YES;
    return l;
}

static NSString* DuoStateText(TemporaryHost* host) {
    switch (host.state) {
        case StateOnline: return @"ONLINE";
        case StateOffline: return @"OFFLINE";
        default: return @"CHECKING";
    }
}

static UIColor* DuoStateColor(TemporaryHost* host) {
    switch (host.state) {
        case StateOnline: return [DuoTheme online];
        case StateOffline: return [DuoTheme offline];
        default: return [DuoTheme warn];
    }
}

static BOOL DuoHostRunning(TemporaryHost* host) {
    return host.state == StateOnline && host.currentGame != nil && ![host.currentGame isEqualToString:@"0"];
}

#pragma mark - App row

@interface DuoAppRow : UIControl
@property (nonatomic, strong) TemporaryApp* app;
@property (nonatomic, strong) UIImageView* thumb;
@property (nonatomic, strong) UILabel* placeholder;
@property (nonatomic, strong) UILabel* name;
@property (nonatomic, strong) UILabel* sub;
@property (nonatomic) BOOL chosen;
@end

@implementation DuoAppRow

- (instancetype)initWithApp:(TemporaryApp*)app {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _app = app;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor clearColor].CGColor;

        UIView* box = [[UIView alloc] init];
        box.translatesAutoresizingMaskIntoConstraints = NO;
        box.backgroundColor = [[DuoTheme accent] colorWithAlphaComponent:0.25];
        box.layer.cornerRadius = 6;
        box.clipsToBounds = YES;
        box.userInteractionEnabled = NO;
        [self addSubview:box];

        _placeholder = DuoLabel(@"", 10, UIFontWeightBold, [DuoTheme text]);
        _placeholder.textAlignment = NSTextAlignmentCenter;
        [box addSubview:_placeholder];
        _thumb = [[UIImageView alloc] init];
        _thumb.translatesAutoresizingMaskIntoConstraints = NO;
        _thumb.contentMode = UIViewContentModeScaleAspectFill;
        _thumb.clipsToBounds = YES;
        [box addSubview:_thumb];

        UIStackView* texts = DuoStack(UILayoutConstraintAxisVertical, 2);
        texts.userInteractionEnabled = NO;
        _name = DuoLabel(app.name ?: @"", 16, UIFontWeightRegular, [DuoTheme text]);
        _name.lineBreakMode = NSLineBreakByTruncatingTail;
        _sub = DuoLabel(@"", 12, UIFontWeightRegular, [DuoTheme text2]);
        [texts addArrangedSubview:_name];
        [texts addArrangedSubview:_sub];
        [self addSubview:texts];

        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:66],
            [box.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [box.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [box.widthAnchor constraintEqualToConstant:40],
            [box.heightAnchor constraintEqualToConstant:56],
            [_placeholder.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],
            [_placeholder.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
            [_thumb.topAnchor constraintEqualToAnchor:box.topAnchor],
            [_thumb.bottomAnchor constraintEqualToAnchor:box.bottomAnchor],
            [_thumb.leadingAnchor constraintEqualToAnchor:box.leadingAnchor],
            [_thumb.trailingAnchor constraintEqualToAnchor:box.trailingAnchor],
            [texts.leadingAnchor constraintEqualToAnchor:box.trailingAnchor constant:14],
            [texts.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [texts.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
    }
    return self;
}

- (void)setChosen:(BOOL)chosen {
    _chosen = chosen;
    [UIView animateWithDuration:0.22 animations:^{
        self.backgroundColor = chosen ? [[DuoTheme accent] colorWithAlphaComponent:0.08] : [UIColor clearColor];
    }];
    self.layer.borderColor = chosen ? [DuoTheme accent].CGColor : [UIColor clearColor].CGColor;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    }];
}

@end

#pragma mark - Home view

@implementation DuoHomeView {
    DuoWavesView* _waves;
    UIImageView* _backdrop;
    UIView* _scrim;
    DuoWavesView* _frontWaves;

    UIView* _hostPage;
    UIView* _appPage;

    // host page
    UILabel* _clock;
    UILabel* _date;
    UIStackView* _hostChips;
    UIView* _card;
    UILabel* _badge;
    UILabel* _hostName;
    UILabel* _hostSub;
    UIStackView* _streamChips;
    UILabel* _address;
    UILabel* _tailscale;
    UIButton* _openButton;
    UIButton* _hostOptionsButton;
    UIButton* _hostQuitAll;
    UILabel* _searching;
    NSArray<TemporaryHost*>* _hosts;
    TemporaryHost* _selectedHost;

    // app page
    UILabel* _appHostName;
    UILabel* _appBadge;
    UILabel* _appClock;
    UILabel* _appDate;
    UIStackView* _appChips;
    NSArray<UIButton*>* _tabs;
    NSInteger _tab;
    UIScrollView* _listScroll;
    UIStackView* _list;
    UIImageView* _bigCover;
    UILabel* _bigPlaceholder;
    UILabel* _bigName;
    UILabel* _bigSub;
    UIButton* _playButton;
    UIButton* _appQuitAll;
    NSArray<TemporaryApp*>* _apps;
    TemporaryHost* _appHost;
    NSCache* _cache;
    TemporaryApp* _selectedApp;

    NSTimer* _clockTimer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [DuoTheme floor];
        self.clipsToBounds = YES;

        _waves = [[DuoWavesView alloc] initWithFrame:self.bounds];
        _waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_waves];

        _backdrop = [[UIImageView alloc] initWithFrame:self.bounds];
        _backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backdrop.contentMode = UIViewContentModeScaleAspectFill;
        _backdrop.clipsToBounds = YES;
        _backdrop.alpha = 0;
        [self addSubview:_backdrop];
        UIVisualEffectView* blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blur.frame = _backdrop.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.alpha = 0.55;
        [_backdrop addSubview:blur];

        _scrim = [[UIView alloc] initWithFrame:self.bounds];
        _scrim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _scrim.userInteractionEnabled = NO;
        _scrim.alpha = 0;
        CAGradientLayer* g = [CAGradientLayer layer];
        g.colors = @[(id)[[DuoTheme floor] colorWithAlphaComponent:0.9].CGColor,
                     (id)[[DuoTheme floor] colorWithAlphaComponent:0.55].CGColor,
                     (id)[[DuoTheme floor] colorWithAlphaComponent:0.35].CGColor];
        g.startPoint = CGPointMake(0, 0.5);
        g.endPoint = CGPointMake(1, 0.5);
        g.frame = CGRectMake(0, 0, 4000, 4000);
        [_scrim.layer addSublayer:g];
        [self addSubview:_scrim];

        _frontWaves = [[DuoWavesView alloc] initWithFrame:self.bounds];
        _frontWaves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _frontWaves.overlay = YES;
        _frontWaves.alpha = 0;
        [self addSubview:_frontWaves];

        [self buildHostPage];
        [self buildAppPage];
        _appPage.hidden = YES;

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [self updateClock];
    }
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_clockTimer invalidate];
    _clockTimer = nil;
    if (self.window != nil) {
        __weak DuoHomeView* weakSelf = self;
        _clockTimer = [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(NSTimer* t) {
            [weakSelf updateClock];
        }];
        [self updateClock];
    }
}

- (CGFloat)margin {
    return self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ? 28 : 16;
}

- (void)pin:(UIView*)page {
    page.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:page];
    UILayoutGuide* safe = self.safeAreaLayoutGuide;
    CGFloat m = [self margin];
    [NSLayoutConstraint activateConstraints:@[
        [page.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [page.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [page.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:m],
        [page.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-m],
    ]];
}

- (UIStackView*)clockStackClock:(UILabel* __strong *)clock date:(UILabel* __strong *)date {
    UIStackView* s = DuoStack(UILayoutConstraintAxisVertical, 2);
    s.alignment = UIStackViewAlignmentTrailing;
    *clock = DuoLabel(@"", 40, UIFontWeightLight, [DuoTheme text]);
    (*clock).font = [DuoTheme digits:40 weight:UIFontWeightLight];
    *date = DuoLabel(@"", 13, UIFontWeightRegular, [DuoTheme text2]);
    [s addArrangedSubview:*clock];
    [s addArrangedSubview:*date];
    return s;
}

#pragma mark Host page

- (void)buildHostPage {
    _hostPage = [[UIView alloc] init];
    [self pin:_hostPage];
    UIStackView* col = DuoStack(UILayoutConstraintAxisVertical, 18);
    [_hostPage addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
        [col.topAnchor constraintEqualToAnchor:_hostPage.topAnchor],
        [col.bottomAnchor constraintEqualToAnchor:_hostPage.bottomAnchor],
        [col.leadingAnchor constraintEqualToAnchor:_hostPage.leadingAnchor],
        [col.trailingAnchor constraintEqualToAnchor:_hostPage.trailingAnchor],
    ]];

    // ---- top: logo + brand ... clock
    UIStackView* top = DuoStack(UILayoutConstraintAxisHorizontal, 12);
    top.alignment = UIStackViewAlignmentCenter;
    UIView* logo = [[UIView alloc] init];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    logo.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    logo.layer.cornerRadius = 12;
    logo.layer.borderWidth = 1;
    logo.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    UIImageView* tv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.tv"]];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.tintColor = [DuoTheme accent];
    [logo addSubview:tv];
    [NSLayoutConstraint activateConstraints:@[
        [logo.widthAnchor constraintEqualToConstant:44], [logo.heightAnchor constraintEqualToConstant:44],
        [tv.centerXAnchor constraintEqualToAnchor:logo.centerXAnchor], [tv.centerYAnchor constraintEqualToAnchor:logo.centerYAnchor],
    ]];
    UIStackView* brand = DuoStack(UILayoutConstraintAxisVertical, 2);
    UILabel* title = DuoLabel(@"", 20, UIFontWeightSemibold, [DuoTheme text]);
    NSMutableAttributedString* t = [[NSMutableAttributedString alloc] initWithString:@"ARTEMIDE DUO"
        attributes:@{NSKernAttributeName: @4, NSForegroundColorAttributeName: [DuoTheme text]}];
    [t addAttribute:NSForegroundColorAttributeName value:[DuoTheme accent] range:NSMakeRange(9, 3)];
    title.attributedText = t;
    [brand addArrangedSubview:title];
    [brand addArrangedSubview:DuoLabel(@"an Artemide fork for iPad and iPhone", 13, UIFontWeightRegular, [DuoTheme text2])];
    [top addArrangedSubview:logo];
    [top addArrangedSubview:brand];
    [top addArrangedSubview:DuoSpacer()];
    [top addArrangedSubview:[self clockStackClock:&_clock date:&_date]];
    [col addArrangedSubview:top];

    // ---- host chips
    UIScrollView* chipScroll = [[UIScrollView alloc] init];
    chipScroll.translatesAutoresizingMaskIntoConstraints = NO;
    chipScroll.showsHorizontalScrollIndicator = NO;
    _hostChips = DuoStack(UILayoutConstraintAxisHorizontal, 10);
    [chipScroll addSubview:_hostChips];
    [NSLayoutConstraint activateConstraints:@[
        [chipScroll.heightAnchor constraintEqualToConstant:42],
        [_hostChips.topAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.topAnchor],
        [_hostChips.bottomAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.bottomAnchor],
        [_hostChips.leadingAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.leadingAnchor],
        [_hostChips.trailingAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.trailingAnchor],
        [_hostChips.heightAnchor constraintEqualToAnchor:chipScroll.frameLayoutGuide.heightAnchor],
    ]];
    [col addArrangedSubview:chipScroll];

    // ---- the big host card
    _card = [[UIView alloc] init];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.backgroundColor = [DuoTheme card];
    _card.layer.cornerRadius = 22;
    _card.layer.borderWidth = 1;
    _card.layer.borderColor = [DuoTheme line].CGColor;
    UIStackView* c = DuoStack(UILayoutConstraintAxisVertical, 10);
    c.alignment = UIStackViewAlignmentLeading;
    [_card addSubview:c];
    [NSLayoutConstraint activateConstraints:@[
        [c.topAnchor constraintEqualToAnchor:_card.topAnchor constant:24],
        [c.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-24],
        [c.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:26],
        [c.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-26],
    ]];
    _badge = DuoChip(@"");
    _badge.font = [DuoTheme font:12 weight:UIFontWeightBold];
    [c addArrangedSubview:_badge];
    _hostName = DuoLabel(@"", 40, UIFontWeightBold, [DuoTheme text]);
    _hostName.adjustsFontSizeToFitWidth = YES;
    _hostName.minimumScaleFactor = 0.6;
    [c addArrangedSubview:_hostName];
    _hostSub = DuoLabel(@"", 16, UIFontWeightRegular, [DuoTheme text2]);
    [c addArrangedSubview:_hostSub];
    _streamChips = DuoStack(UILayoutConstraintAxisHorizontal, 8);
    [c addArrangedSubview:_streamChips];
    [c setCustomSpacing:18 afterView:_streamChips];
    UILabel* addrCaption = DuoLabel(@"ADDRESS", 11, UIFontWeightSemibold, [DuoTheme text3]);
    [addrCaption setAttributedText:[[NSAttributedString alloc] initWithString:@"ADDRESS" attributes:@{NSKernAttributeName: @2}]];
    [c addArrangedSubview:addrCaption];
    [c setCustomSpacing:2 afterView:addrCaption];
    _address = DuoLabel(@"", 22, UIFontWeightSemibold, [DuoTheme text]);
    _address.font = [DuoTheme digits:22 weight:UIFontWeightSemibold];
    [c addArrangedSubview:_address];
    _tailscale = DuoLabel(@"", 14, UIFontWeightRegular, [DuoTheme text2]);
    [c addArrangedSubview:_tailscale];
    [c setCustomSpacing:22 afterView:_tailscale];
    UIStackView* buttons = DuoStack(UILayoutConstraintAxisHorizontal, 10);
    _openButton = DuoButton(@"Open", YES);
    [_openButton addTarget:self action:@selector(openTapped:) forControlEvents:UIControlEventTouchUpInside];
    _hostOptionsButton = DuoButton(@"Options", NO);
    [_hostOptionsButton addTarget:self action:@selector(hostOptionsTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttons addArrangedSubview:_openButton];
    [buttons addArrangedSubview:_hostOptionsButton];
    [c addArrangedSubview:buttons];
    [col addArrangedSubview:_card];

    _searching = DuoLabel(@"Searching for PCs on your network …", 16, UIFontWeightRegular, [DuoTheme text2]);
    _searching.textAlignment = NSTextAlignmentCenter;
    [col addArrangedSubview:_searching];

    [col addArrangedSubview:DuoSpacer()];

    // ---- bottom bar
    UIStackView* bottom = DuoStack(UILayoutConstraintAxisHorizontal, 10);
    UIButton* settings = DuoButton(@"Settings", NO);
    [settings addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottom addArrangedSubview:settings];
    [bottom addArrangedSubview:DuoSpacer()];
    _hostQuitAll = DuoButton(@"Quit all sessions", NO);
    [_hostQuitAll addTarget:self action:@selector(hostQuitAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottom addArrangedSubview:_hostQuitAll];
    [col addArrangedSubview:bottom];

    [self renderHostPage];
}

- (void)setHosts:(NSArray<TemporaryHost*>*)hosts {
    _hosts = [hosts sortedArrayUsingSelector:@selector(compareName:)];
    TemporaryHost* keep = nil;
    NSString* saved = [[NSUserDefaults standardUserDefaults] stringForKey:kSelectedHost];
    for (TemporaryHost* h in _hosts) {
        if (_selectedHost != nil && [h.uuid isEqualToString:_selectedHost.uuid]) {
            keep = h;
            break;
        }
        if (keep == nil && saved != nil && [h.uuid isEqualToString:saved]) {
            keep = h;
        }
    }
    _selectedHost = keep ?: _hosts.firstObject;
    [self renderHostPage];
    if (_showingApps) {
        [self renderAppPage];
    }
}

- (void)selectHost:(TemporaryHost*)host {
    _selectedHost = host;
    if (host.uuid != nil) {
        [[NSUserDefaults standardUserDefaults] setObject:host.uuid forKey:kSelectedHost];
    }
    [self renderHostPage];
    _card.alpha = 0.4;
    [UIView animateWithDuration:0.3 animations:^{ self->_card.alpha = 1; }];
}

- (void)fillStreamChips:(UIStackView*)row {
    for (UIView* v in row.arrangedSubviews) {
        [v removeFromSuperview];
    }
    TemporarySettings* s = [[[DataManager alloc] init] getSettings];
    if (s == nil) {
        return;
    }
    [row addArrangedSubview:DuoChip([NSString stringWithFormat:@"%d×%d", [s.width intValue], [s.height intValue]])];
    [row addArrangedSubview:DuoChip([NSString stringWithFormat:@"%d FPS", [s.framerate intValue]])];
    [row addArrangedSubview:DuoChip([NSString stringWithFormat:@"%d Mbps", [s.bitrate intValue] / 1000])];
    [row addArrangedSubview:DuoChip([DuoPrefs virtualDisplay] ? @"Virtual display" : @"Host display")];
}

- (void)renderHostPage {
    for (UIView* v in _hostChips.arrangedSubviews) {
        [v removeFromSuperview];
    }
    for (TemporaryHost* h in _hosts) {
        UIButtonConfiguration* cfg = [UIButtonConfiguration plainButtonConfiguration];
        BOOL sel = (h == _selectedHost);
        cfg.title = [h.name uppercaseString];
        cfg.image = [UIImage systemImageNamed:@"circle.fill"];
        cfg.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:8];
        cfg.imagePadding = 8;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 14, 8, 14);
        cfg.baseForegroundColor = sel ? [DuoTheme text] : [DuoTheme text2];
        cfg.background.backgroundColor = sel ? [[DuoTheme accent] colorWithAlphaComponent:0.14] : [UIColor clearColor];
        cfg.background.strokeColor = sel ? [DuoTheme accent] : [UIColor colorWithWhite:1 alpha:0.12];
        cfg.background.strokeWidth = sel ? 1.5 : 1;
        cfg.background.cornerRadius = 12;
        cfg.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id>* (NSDictionary<NSAttributedStringKey, id>* in) {
            NSMutableDictionary* out = [in mutableCopy];
            out[NSFontAttributeName] = [DuoTheme font:14 weight:UIFontWeightSemibold];
            out[NSKernAttributeName] = @1.5;
            return out;
        };
        UIButton* chip = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        chip.tintColor = DuoStateColor(h);
        UIImageSymbolConfiguration* dot = [UIImageSymbolConfiguration configurationWithPointSize:8];
        [chip setImage:[[UIImage systemImageNamed:@"circle.fill" withConfiguration:dot] imageWithTintColor:DuoStateColor(h) renderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
        __weak DuoHomeView* weakSelf = self;
        __weak TemporaryHost* weakHost = h;
        [chip addAction:[UIAction actionWithHandler:^(__kindof UIAction* a) {
            if (weakHost != nil) {
                [weakSelf selectHost:weakHost];
            }
        }] forControlEvents:UIControlEventTouchUpInside];
        [_hostChips addArrangedSubview:chip];
    }
    UIButton* add = DuoButton(@"+  Add a host", NO);
    [add addTarget:self action:@selector(addHostTapped) forControlEvents:UIControlEventTouchUpInside];
    [_hostChips addArrangedSubview:add];

    TemporaryHost* h = _selectedHost;
    _card.hidden = (h == nil);
    _searching.hidden = (h != nil);
    _hostQuitAll.hidden = !(h != nil && DuoHostRunning(h));
    if (h == nil) {
        return;
    }
    _badge.text = [NSString stringWithFormat:@"  ●  %@  ", DuoStateText(h)];
    _badge.textColor = DuoStateColor(h);
    _hostName.text = h.name;
    if (h.state == StateOffline) {
        _hostSub.text = @"Offline – wake it with Options, or check the network";
    } else if (h.state == StateOnline && h.pairState == PairStateUnpaired) {
        _hostSub.text = @"Not paired yet – tap Open to pair";
    } else if (DuoHostRunning(h)) {
        _hostSub.text = @"A session is running";
    } else if (h.state == StateOnline) {
        _hostSub.text = @"Ready to stream";
    } else {
        _hostSub.text = @"Checking …";
    }
    [self fillStreamChips:_streamChips];
    NSString* addr = h.activeAddress ?: (h.localAddress ?: h.address);
    _address.text = addr ?: @"–";
    NSString* ts = [DuoPrefs tailscaleAddress];
    if (ts != nil) {
        _tailscale.text = [NSString stringWithFormat:@"●  Tailscale · connected (%@)%@", ts,
                           [DuoPrefs isTailscaleAddress:addr] ? @" · via Tailscale" : @""];
        _tailscale.textColor = [DuoTheme online];
    } else {
        _tailscale.text = @"●  Tailscale · not connected";
        _tailscale.textColor = [DuoTheme text3];
    }
    UIButtonConfiguration* oc = _openButton.configuration;
    oc.title = DuoHostRunning(h) ? @"Open · session running" : @"Open";
    _openButton.configuration = oc;
}

- (void)showHostPage {
    _showingApps = NO;
    _appHost = nil;
    _apps = nil;
    [self setBackdropImage:nil];
    [self renderHostPage];
    if (!_appPage.hidden) {
        _hostPage.hidden = NO;
        _hostPage.alpha = 0;
        _hostPage.transform = CGAffineTransformMakeTranslation(-30, 0);
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->_hostPage.alpha = 1;
            self->_hostPage.transform = CGAffineTransformIdentity;
            self->_appPage.alpha = 0;
        } completion:^(BOOL finished) {
            self->_appPage.hidden = YES;
            self->_appPage.alpha = 1;
        }];
    } else {
        _hostPage.hidden = NO;
    }
}

#pragma mark App page

- (void)buildAppPage {
    _appPage = [[UIView alloc] init];
    [self pin:_appPage];
    UIStackView* col = DuoStack(UILayoutConstraintAxisVertical, 14);
    [_appPage addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
        [col.topAnchor constraintEqualToAnchor:_appPage.topAnchor],
        [col.bottomAnchor constraintEqualToAnchor:_appPage.bottomAnchor],
        [col.leadingAnchor constraintEqualToAnchor:_appPage.leadingAnchor],
        [col.trailingAnchor constraintEqualToAnchor:_appPage.trailingAnchor],
    ]];

    UIStackView* top = DuoStack(UILayoutConstraintAxisHorizontal, 12);
    top.alignment = UIStackViewAlignmentCenter;
    _appHostName = DuoLabel(@"", 30, UIFontWeightBold, [DuoTheme text]);
    _appBadge = DuoChip(@"");
    _appBadge.font = [DuoTheme font:12 weight:UIFontWeightBold];
    [top addArrangedSubview:_appHostName];
    [top addArrangedSubview:_appBadge];
    [top addArrangedSubview:DuoSpacer()];
    [top addArrangedSubview:[self clockStackClock:&_appClock date:&_appDate]];
    [col addArrangedSubview:top];

    _appChips = DuoStack(UILayoutConstraintAxisHorizontal, 8);
    UIStackView* chipRow = DuoStack(UILayoutConstraintAxisHorizontal, 0);
    [chipRow addArrangedSubview:_appChips];
    [chipRow addArrangedSubview:DuoSpacer()];
    [col addArrangedSubview:chipRow];

    UIStackView* tabs = DuoStack(UILayoutConstraintAxisHorizontal, 26);
    NSMutableArray* tabButtons = [NSMutableArray array];
    NSArray* names = @[@"ALL", @"GAMES", @"APPS"];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.translatesAutoresizingMaskIntoConstraints = NO;
        b.tag = i;
        [b setAttributedTitle:[[NSAttributedString alloc] initWithString:names[i] attributes:@{
            NSKernAttributeName: @3, NSFontAttributeName: [DuoTheme font:16 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: [DuoTheme text3]}] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        UIView* underline = [[UIView alloc] init];
        underline.translatesAutoresizingMaskIntoConstraints = NO;
        underline.backgroundColor = [DuoTheme accent];
        underline.layer.cornerRadius = 1.5;
        underline.tag = 99;
        underline.userInteractionEnabled = NO;
        [b addSubview:underline];
        [NSLayoutConstraint activateConstraints:@[
            [underline.heightAnchor constraintEqualToConstant:3],
            [underline.leadingAnchor constraintEqualToAnchor:b.leadingAnchor],
            [underline.trailingAnchor constraintEqualToAnchor:b.trailingAnchor],
            [underline.bottomAnchor constraintEqualToAnchor:b.bottomAnchor constant:2],
        ]];
        [tabs addArrangedSubview:b];
        [tabButtons addObject:b];
    }
    _tabs = tabButtons;
    UIStackView* tabRow = DuoStack(UILayoutConstraintAxisHorizontal, 0);
    [tabRow addArrangedSubview:tabs];
    [tabRow addArrangedSubview:DuoSpacer()];
    [col addArrangedSubview:tabRow];

    // ---- body: list | detail
    UIStackView* body = DuoStack(UILayoutConstraintAxisHorizontal, 24);
    body.alignment = UIStackViewAlignmentFill;
    _listScroll = [[UIScrollView alloc] init];
    _listScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _listScroll.showsVerticalScrollIndicator = NO;
    _listScroll.alwaysBounceVertical = YES;
    _list = DuoStack(UILayoutConstraintAxisVertical, 4);
    [_listScroll addSubview:_list];
    [NSLayoutConstraint activateConstraints:@[
        [_list.topAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.topAnchor],
        [_list.bottomAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.bottomAnchor],
        [_list.leadingAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.leadingAnchor],
        [_list.trailingAnchor constraintEqualToAnchor:_listScroll.contentLayoutGuide.trailingAnchor],
        [_list.widthAnchor constraintEqualToAnchor:_listScroll.frameLayoutGuide.widthAnchor],
    ]];
    [body addArrangedSubview:_listScroll];

    UIStackView* detail = DuoStack(UILayoutConstraintAxisVertical, 10);
    detail.alignment = UIStackViewAlignmentCenter;
    UIView* cover = [[UIView alloc] init];
    cover.translatesAutoresizingMaskIntoConstraints = NO;
    cover.backgroundColor = [[DuoTheme accent] colorWithAlphaComponent:0.22];
    cover.layer.cornerRadius = 16;
    cover.clipsToBounds = YES;
    cover.layer.borderWidth = 1;
    cover.layer.borderColor = [DuoTheme line].CGColor;
    _bigPlaceholder = DuoLabel(@"", 18, UIFontWeightBold, [DuoTheme text]);
    _bigPlaceholder.textAlignment = NSTextAlignmentCenter;
    _bigPlaceholder.numberOfLines = 3;
    [cover addSubview:_bigPlaceholder];
    _bigCover = [[UIImageView alloc] init];
    _bigCover.translatesAutoresizingMaskIntoConstraints = NO;
    _bigCover.contentMode = UIViewContentModeScaleAspectFill;
    _bigCover.clipsToBounds = YES;
    [cover addSubview:_bigCover];
    [NSLayoutConstraint activateConstraints:@[
        [cover.widthAnchor constraintEqualToConstant:180],
        [cover.heightAnchor constraintEqualToConstant:254],
        [_bigPlaceholder.leadingAnchor constraintEqualToAnchor:cover.leadingAnchor constant:10],
        [_bigPlaceholder.trailingAnchor constraintEqualToAnchor:cover.trailingAnchor constant:-10],
        [_bigPlaceholder.centerYAnchor constraintEqualToAnchor:cover.centerYAnchor],
        [_bigCover.topAnchor constraintEqualToAnchor:cover.topAnchor],
        [_bigCover.bottomAnchor constraintEqualToAnchor:cover.bottomAnchor],
        [_bigCover.leadingAnchor constraintEqualToAnchor:cover.leadingAnchor],
        [_bigCover.trailingAnchor constraintEqualToAnchor:cover.trailingAnchor],
    ]];
    [detail addArrangedSubview:cover];
    [detail setCustomSpacing:16 afterView:cover];
    _bigName = DuoLabel(@"", 24, UIFontWeightBold, [DuoTheme text]);
    _bigName.textAlignment = NSTextAlignmentCenter;
    _bigName.adjustsFontSizeToFitWidth = YES;
    _bigName.minimumScaleFactor = 0.6;
    [detail addArrangedSubview:_bigName];
    _bigSub = DuoLabel(@"", 14, UIFontWeightRegular, [DuoTheme text2]);
    [detail addArrangedSubview:_bigSub];
    [detail setCustomSpacing:16 afterView:_bigSub];
    _playButton = DuoButton(@"Open", YES);
    [_playButton addTarget:self action:@selector(playTapped:) forControlEvents:UIControlEventTouchUpInside];
    [detail addArrangedSubview:_playButton];
    UIStackView* detailWrap = DuoStack(UILayoutConstraintAxisVertical, 0);
    [detailWrap addArrangedSubview:detail];
    [detailWrap addArrangedSubview:DuoSpacer()];
    [body addArrangedSubview:detailWrap];
    [_listScroll.widthAnchor constraintEqualToAnchor:body.widthAnchor multiplier:0.58].active = YES;
    [col addArrangedSubview:body];

    // ---- bottom bar
    UIStackView* bottom = DuoStack(UILayoutConstraintAxisHorizontal, 10);
    UIButton* back = DuoButton(@"‹  Back", NO);
    [back addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    UIButton* settings = DuoButton(@"Settings", NO);
    [settings addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    UIButton* options = DuoButton(@"Options", NO);
    [options addTarget:self action:@selector(appOptionsTapped:) forControlEvents:UIControlEventTouchUpInside];
    _appQuitAll = DuoButton(@"Quit all sessions", NO);
    [_appQuitAll addTarget:self action:@selector(appQuitAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottom addArrangedSubview:back];
    [bottom addArrangedSubview:settings];
    [bottom addArrangedSubview:options];
    [bottom addArrangedSubview:DuoSpacer()];
    [bottom addArrangedSubview:_appQuitAll];
    [col addArrangedSubview:bottom];
}

- (BOOL)inTab:(TemporaryApp*)app {
    if (_tab == 0) {
        return YES;
    }
    BOOL isApp = [DuoPrefs isAppName:app.name];
    return _tab == 1 ? !isApp : isApp;
}

- (BOOL)isRunning:(TemporaryApp*)app {
    return _appHost != nil && app.id != nil && [app.id isEqualToString:_appHost.currentGame];
}

- (void)showApps:(NSArray<TemporaryApp*>*)apps host:(TemporaryHost*)host cache:(NSCache*)cache {
    BOOL wasShowing = _showingApps;
    BOOL sameHost = (_appHost == host);
    _showingApps = YES;
    _appHost = host;
    _cache = cache;
    _apps = apps;
    if (!sameHost) {
        _tab = 0;
        _selectedApp = nil;
    }
    [self renderAppPage];
    if (!wasShowing) {
        _appPage.hidden = NO;
        _appPage.alpha = 0;
        _appPage.transform = CGAffineTransformMakeTranslation(30, 0);
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->_appPage.alpha = 1;
            self->_appPage.transform = CGAffineTransformIdentity;
            self->_hostPage.alpha = 0;
        } completion:^(BOOL finished) {
            self->_hostPage.hidden = YES;
            self->_hostPage.alpha = 1;
        }];
    }
}

- (NSArray<TemporaryApp*>*)visibleApps {
    NSMutableArray* running = [NSMutableArray array];
    NSMutableArray* rest = [NSMutableArray array];
    for (TemporaryApp* a in _apps) {
        if (![self inTab:a]) {
            continue;
        }
        if ([self isRunning:a]) {
            [running addObject:a];
        } else {
            [rest addObject:a];
        }
    }
    [running addObjectsFromArray:rest];
    return running;
}

- (UILabel*)sectionTitle:(NSString*)text color:(UIColor*)color {
    UILabel* l = DuoLabel(@"", 12, UIFontWeightSemibold, color);
    l.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{NSKernAttributeName: @2.5,
        NSFontAttributeName: [DuoTheme font:12 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: color}];
    [l.heightAnchor constraintEqualToConstant:30].active = YES;
    return l;
}

- (void)renderAppPage {
    TemporaryHost* h = _appHost;
    if (h == nil) {
        return;
    }
    _appHostName.text = h.name;
    _appBadge.text = [NSString stringWithFormat:@"  ●  %@  ", DuoStateText(h)];
    _appBadge.textColor = DuoStateColor(h);
    [self fillStreamChips:_appChips];
    _appQuitAll.hidden = !DuoHostRunning(h);
    for (UIButton* b in _tabs) {
        BOOL on = (b.tag == _tab);
        NSString* title = [[b attributedTitleForState:UIControlStateNormal] string];
        [b setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{
            NSKernAttributeName: @3, NSFontAttributeName: [DuoTheme font:16 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: on ? [DuoTheme text] : [DuoTheme text3]}] forState:UIControlStateNormal];
        [b viewWithTag:99].hidden = !on;
    }

    for (UIView* v in _list.arrangedSubviews) {
        [v removeFromSuperview];
    }
    NSArray<TemporaryApp*>* visible = [self visibleApps];
    BOOL keep = NO;
    for (TemporaryApp* a in visible) {
        keep |= (a == _selectedApp);
    }
    if (!keep) {
        _selectedApp = visible.firstObject;
    }
    BOOL sectionRunning = NO, sectionAll = NO;
    for (TemporaryApp* a in visible) {
        if ([self isRunning:a] && !sectionRunning) {
            sectionRunning = YES;
            [_list addArrangedSubview:[self sectionTitle:@"RUNNING NOW" color:[DuoTheme accent]]];
        } else if (![self isRunning:a] && !sectionAll) {
            sectionAll = YES;
            NSArray* names = @[@"ALL", @"GAMES", @"APPS"];
            [_list addArrangedSubview:[self sectionTitle:names[_tab] color:[DuoTheme text2]]];
        }
        DuoAppRow* row = [[DuoAppRow alloc] initWithApp:a];
        UIImage* art = [_cache objectForKey:a];
        row.thumb.image = art;
        row.placeholder.text = [self initialsOf:a.name];
        row.placeholder.hidden = (art != nil);
        if ([self isRunning:a]) {
            row.sub.text = @"Running now";
            row.sub.textColor = [DuoTheme accent];
        } else {
            row.sub.text = [DuoPrefs isAppName:a.name] ? @"App" : @"";
        }
        row.chosen = (a == _selectedApp);
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer* lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(rowLongPressed:)];
        [row addGestureRecognizer:lp];
        [_list addArrangedSubview:row];
    }
    if (visible.count == 0) {
        UILabel* empty = DuoLabel(_apps.count == 0 ? @"Loading apps …" : @"Nothing here", 15, UIFontWeightRegular, [DuoTheme text2]);
        [empty.heightAnchor constraintEqualToConstant:60].active = YES;
        [_list addArrangedSubview:empty];
    }
    [self renderDetailAnimated:NO];
}

- (NSString*)initialsOf:(NSString*)name {
    NSMutableString* s = [NSMutableString string];
    for (NSString* w in [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
        if (w.length > 0 && s.length < 3) {
            [s appendString:[[w substringToIndex:1] uppercaseString]];
        }
    }
    return s;
}

- (void)renderDetailAnimated:(BOOL)animated {
    TemporaryApp* a = _selectedApp;
    _playButton.hidden = (a == nil);
    if (a == nil) {
        _bigName.text = @"";
        _bigSub.text = @"";
        _bigCover.image = nil;
        _bigPlaceholder.text = @"";
        [self setBackdropImage:nil];
        return;
    }
    UIImage* art = [_cache objectForKey:a];
    _bigName.text = a.name;
    _bigCover.image = art;
    BOOL isApp = [DuoPrefs isAppName:a.name];
    _bigPlaceholder.text = isApp ? [a.name uppercaseString] : [self initialsOf:a.name];
    _bigPlaceholder.hidden = (art != nil);
    BOOL running = [self isRunning:a];
    _bigSub.text = running ? @"Running now" : (isApp ? @"App" : @"Game");
    _bigSub.textColor = running ? [DuoTheme accent] : [DuoTheme text2];
    UIButtonConfiguration* pc = _playButton.configuration;
    pc.title = running ? @"Resume" : @"Open";
    _playButton.configuration = pc;
    // Games get their cover softly in the back; apps keep the plain waves.
    [self setBackdropImage:isApp ? nil : art];
    if (animated) {
        UIView* box = _bigCover.superview;
        box.transform = CGAffineTransformMakeScale(0.97, 0.97);
        box.alpha = 0.6;
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            box.transform = CGAffineTransformIdentity;
            box.alpha = 1;
        } completion:nil];
    }
}

- (void)setBackdropImage:(UIImage*)image {
    if (image != nil && _backdrop.image != image) {
        [UIView transitionWithView:_backdrop duration:0.9 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            self->_backdrop.image = image;
        } completion:nil];
        // Slow, subtle zoom (Ken Burns).
        _backdrop.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:18 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            self->_backdrop.transform = CGAffineTransformMakeScale(1.09, 1.09);
        } completion:nil];
    }
    CGFloat target = image != nil ? 1 : 0;
    [UIView animateWithDuration:0.8 animations:^{
        self->_backdrop.alpha = image != nil ? 0.42 : 0;
        self->_scrim.alpha = target;
        self->_frontWaves.alpha = target;
    }];
}

- (void)refresh {
    if (_showingApps) {
        [self renderAppPage];
    } else {
        [self renderHostPage];
    }
}

#pragma mark Actions

- (void)openTapped:(UIButton*)sender {
    if (_selectedHost != nil) {
        [self.delegate duoOpenHost:_selectedHost view:sender];
    }
}

- (void)hostOptionsTapped:(UIButton*)sender {
    if (_selectedHost != nil) {
        [self.delegate duoHostOptions:_selectedHost view:sender];
    }
}

- (void)addHostTapped {
    [self.delegate duoAddHost];
}

- (void)settingsTapped {
    [self.delegate duoOpenSettings];
}

- (void)hostQuitAllTapped {
    if (_selectedHost != nil) {
        [self.delegate duoQuitAll:_selectedHost];
    }
}

- (void)appQuitAllTapped {
    if (_appHost != nil) {
        [self.delegate duoQuitAll:_appHost];
    }
}

- (void)backTapped {
    [self.delegate duoBackToHosts];
}

- (void)tabTapped:(UIButton*)sender {
    if (sender.tag == _tab) {
        return;
    }
    _tab = sender.tag;
    _selectedApp = nil;
    [self renderAppPage];
    _listScroll.contentOffset = CGPointZero;
    _listScroll.alpha = 0;
    _listScroll.transform = CGAffineTransformMakeTranslation(20, 0);
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self->_listScroll.alpha = 1;
        self->_listScroll.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)rowTapped:(DuoAppRow*)row {
    if (row.app == _selectedApp) {
        // Second tap on the selected app starts it.
        [self.delegate duoOpenApp:row.app view:row];
        return;
    }
    _selectedApp = row.app;
    for (UIView* v in _list.arrangedSubviews) {
        if ([v isKindOfClass:[DuoAppRow class]]) {
            ((DuoAppRow*)v).chosen = (((DuoAppRow*)v).app == _selectedApp);
        }
    }
    [self renderDetailAnimated:YES];
}

- (void)rowLongPressed:(UILongPressGestureRecognizer*)g {
    if (g.state == UIGestureRecognizerStateBegan && [g.view isKindOfClass:[DuoAppRow class]]) {
        [self.delegate duoAppOptions:((DuoAppRow*)g.view).app view:g.view];
    }
}

- (void)playTapped:(UIButton*)sender {
    if (_selectedApp != nil) {
        [self.delegate duoOpenApp:_selectedApp view:sender];
    }
}

- (void)appOptionsTapped:(UIButton*)sender {
    if (_selectedApp != nil) {
        [self.delegate duoAppOptions:_selectedApp view:sender];
    }
}

#pragma mark Clock

- (void)updateClock {
    NSDate* now = [NSDate date];
    NSString* time = [NSDateFormatter localizedStringFromDate:now dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
    NSString* date = [NSDateFormatter localizedStringFromDate:now dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
    float level = [UIDevice currentDevice].batteryLevel;
    NSString* line = level >= 0 ? [NSString stringWithFormat:@"%@  ·  %d %%", date, (int)roundf(level * 100)] : date;
    _clock.text = time;
    _appClock.text = time;
    _date.text = line;
    _appDate.text = line;
}

- (void)dealloc {
    [_clockTimer invalidate];
}

@end

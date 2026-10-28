//
//  DuoSettingsViewController.m
//  Artemide Duo for iOS
//

#import "DuoSettingsViewController.h"
#import "DuoSupport.h"
#import "DuoWavesView.h"
#import "DataManager.h"
#import "TemporarySettings.h"

#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>

extern NSString* DuoClockText(void);
extern NSString* DuoDateLine(void);

static NSInteger sLastTab = 0;

static const int kBitrates[] = {500, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 12000,
                                15000, 18000, 20000, 30000, 40000, 50000, 60000, 70000, 80000, 100000, 120000, 150000};
static const int kBitrateCount = sizeof(kBitrates) / sizeof(kBitrates[0]);

typedef NS_ENUM(NSInteger, DuoRowKind) {
    DuoRowToggle,
    DuoRowPills,
    DuoRowList,
    DuoRowSlider,
    DuoRowInfo,
    DuoRowAction,
};

#pragma mark - Model

@interface DuoSetting : NSObject
@property (nonatomic) DuoRowKind kind;
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy, nullable) NSString* summary;
@property (nonatomic, copy) NSArray<NSString*>* names;     // pills / list
@property (nonatomic, copy, nullable) NSInteger (^getIndex)(void);
@property (nonatomic, copy, nullable) void (^setIndex)(NSInteger i);
@property (nonatomic, copy, nullable) BOOL (^getOn)(void);
@property (nonatomic, copy, nullable) void (^setOn)(BOOL on);
@property (nonatomic) float min, max, step;
@property (nonatomic, copy, nullable) float (^getValue)(void);
@property (nonatomic, copy, nullable) void (^setValue)(float v);
@property (nonatomic, copy, nullable) NSString* (^format)(float v);
@property (nonatomic, copy, nullable) void (^action)(void);
@property (nonatomic, copy, nullable) BOOL (^enabled)(void);
@end

@implementation DuoSetting
@end

@interface DuoSection : NSObject
@property (nonatomic, copy) NSString* title;
@property (nonatomic, strong) NSArray<DuoSetting*>* rows;
@end

@implementation DuoSection
@end

static DuoSection* DuoSec(NSString* title, NSArray<DuoSetting*>* rows) {
    DuoSection* s = [[DuoSection alloc] init];
    s.title = title;
    s.rows = rows;
    return s;
}

#pragma mark - Controls

/// iOS/StreamLight-like switch: 40 x 22 track with a 16 knob.
@interface DuoSwitch : UIControl
@property (nonatomic) BOOL on;
@end

@implementation DuoSwitch {
    UIView* _knob;
}

- (instancetype)init {
    CGFloat d = [DuoTheme scale];
    self = [super initWithFrame:CGRectMake(0, 0, 40 * d, 22 * d)];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 11 * d;
        self.layer.borderWidth = 1;
        self.userInteractionEnabled = NO;
        _knob = [[UIView alloc] initWithFrame:CGRectMake(3 * d, 3 * d, 16 * d, 16 * d)];
        _knob.layer.cornerRadius = 8 * d;
        [self addSubview:_knob];
        [NSLayoutConstraint activateConstraints:@[
            [self.widthAnchor constraintEqualToConstant:40 * d],
            [self.heightAnchor constraintEqualToConstant:22 * d],
        ]];
        [self apply];
    }
    return self;
}

- (void)setOn:(BOOL)on {
    _on = on;
    [UIView animateWithDuration:0.16 animations:^{
        [self apply];
    }];
}

- (void)apply {
    CGFloat d = [DuoTheme scale];
    UIColor* a = [DuoTheme accent];
    self.backgroundColor = _on ? [DuoTheme mix:a with:[DuoTheme card] k:0.35] : [DuoTheme hex:0x0A0E11];
    self.layer.borderColor = (_on ? a : [UIColor colorWithWhite:1 alpha:0x29 / 255.0]).CGColor;
    _knob.backgroundColor = _on ? a : [DuoTheme text3];
    _knob.frame = CGRectMake(_on ? (40 - 16 - 3) * d : 3 * d, 3 * d, 16 * d, 16 * d);
}

@end

/// Pill selector for short lists.
@interface DuoPills : UIView
@property (nonatomic, copy) void (^onPick)(NSInteger i);
- (instancetype)initWithNames:(NSArray<NSString*>*)names selected:(NSInteger)sel;
- (void)select:(NSInteger)i;
@end

@implementation DuoPills {
    NSArray<UIButton*>* _items;
}

- (instancetype)initWithNames:(NSArray<NSString*>*)names selected:(NSInteger)sel {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        CGFloat d = [DuoTheme scale];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0x59 / 255.0];
        self.layer.cornerRadius = 9 * d;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [DuoTheme line].CGColor;
        UIStackView* row = [[UIStackView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.spacing = 2 * d;
        [self addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.topAnchor constraintEqualToAnchor:self.topAnchor constant:2 * d],
            [row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2 * d],
            [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2 * d],
            [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2 * d],
        ]];
        NSMutableArray* items = [NSMutableArray array];
        for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
            UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.translatesAutoresizingMaskIntoConstraints = NO;
            b.tag = i;
            [b setTitle:names[i] forState:UIControlStateNormal];
            b.contentEdgeInsets = UIEdgeInsetsMake(0, 10 * d, 0, 10 * d);
            b.layer.cornerRadius = 7 * d;
            [b.heightAnchor constraintEqualToConstant:28 * d].active = YES;
            [b addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
            [row addArrangedSubview:b];
            [items addObject:b];
        }
        _items = items;
        [self select:sel];
    }
    return self;
}

- (void)tapped:(UIButton*)b {
    [DuoMotion tap:b];
    [self select:b.tag];
    if (self.onPick != nil) {
        self.onPick(b.tag);
    }
}

- (void)select:(NSInteger)sel {
    CGFloat d = [DuoTheme scale];
    UIColor* a = [DuoTheme accent];
    for (UIButton* b in _items) {
        BOOL on = b.tag == sel;
        [UIView animateWithDuration:0.16 animations:^{
            b.backgroundColor = on ? a : [UIColor clearColor];
        }];
        [b setTitleColor:on ? [DuoTheme onColor:a] : [DuoTheme text] forState:UIControlStateNormal];
        b.titleLabel.font = on ? [DuoTheme semibold:11.5 * d] : [DuoTheme medium:11.5 * d];
    }
}

@end

#pragma mark - Row view

@interface DuoSettingRowView : UIControl
@property (nonatomic, strong) DuoSetting* setting;
@property (nonatomic, strong, nullable) DuoSwitch* toggle;
@property (nonatomic, strong, nullable) DuoPills* pills;
@property (nonatomic, strong, nullable) UISlider* slider;
@property (nonatomic, strong, nullable) UILabel* value;
@property (nonatomic) BOOL duoFocused;
@property (nonatomic) BOOL first, last;
@end

@implementation DuoSettingRowView {
    UIView* _line;
}

- (void)setDuoFocused:(BOOL)f {
    _duoFocused = f;
    [UIView animateWithDuration:f ? 0.14 : 0.18 animations:^{
        [self applyBackground:NO];
    }];
}

- (void)applyBackground:(BOOL)pressed {
    UIColor* card = [[DuoTheme card] colorWithAlphaComponent:0.72];
    if (pressed) {
        card = [DuoTheme cardHigh];
    } else if (_duoFocused) {
        card = [[DuoTheme mix:[DuoTheme accent] with:[DuoTheme card] k:0.18] colorWithAlphaComponent:0.72];
    }
    self.backgroundColor = card;
}

- (void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    [self applyBackground:h];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat d = [DuoTheme scale];
    CGFloat r = 14 * d;
    self.layer.cornerRadius = (_first || _last) ? r : 0;
    CACornerMask m = 0;
    if (_first) m |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (_last) m |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.layer.maskedCorners = m;
    if (!_last) {
        if (_line == nil) {
            _line = [[UIView alloc] init];
            _line.backgroundColor = [UIColor colorWithWhite:1 alpha:0x12 / 255.0];
            [self addSubview:_line];
        }
        CGFloat px = 1.0 / [UIScreen mainScreen].scale;
        _line.frame = CGRectMake(14 * d, self.bounds.size.height - MAX(px, 1), self.bounds.size.width - 28 * d, MAX(px, 1));
    }
}

@end

#pragma mark - Controller

@implementation DuoSettingsViewController {
    CGFloat d;
    NSArray<NSString*>* _tabs;
    NSArray<UILabel*>* _tabViews;
    NSArray<UIView*>* _underlines;
    UIScrollView* _tabScroll;
    UIScrollView* _scroll;
    UIStackView* _list;
    NSArray<DuoSettingRowView*>* _rows;
    NSInteger _focus;
    NSInteger _tab;
    UILabel* _clock;
    UILabel* _dateLine;
    DuoButton* _back;
    NSArray<UIView*>* _pills;
    NSTimer* _clockTimer;
    CAGradientLayer* _tabFade;

    // Moonlight's own settings (saved through DataManager).
    NSInteger _bitrate, _framerate, _width, _height, _audio, _osc;
    BOOL _optimize, _multi, _swapABXY, _audioOnPC, _pacing, _hdr, _btMouse, _absolute, _stats;
    uint32_t _codec;
    CGSize _device;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    d = [DuoTheme scale];
    self.view.backgroundColor = [DuoTheme floor];
    [self load];
    _tabs = @[@"Duo", @"Video", @"Audio", @"Input", @"Controller", @"Shortcuts", @"Overlay", @"Interface", @"Advanced", @"General"];
    _tab = MAX(0, MIN((NSInteger)_tabs.count - 1, sLastTab));

    DuoWavesView* waves = [[DuoWavesView alloc] initWithFrame:self.view.bounds rise:NO];
    waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:waves];

    UIStackView* col = [[UIStackView alloc] init];
    col.axis = UILayoutConstraintAxisVertical;
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:col];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [col.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [col.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [col.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [col.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    ]];

    // header
    UIStackView* header = [[UIStackView alloc] init];
    header.alignment = UIStackViewAlignmentCenter;
    header.layoutMarginsRelativeArrangement = YES;
    header.layoutMargins = UIEdgeInsetsMake(14 * d, 20 * d, 0, 16 * d);
    UILabel* title = DuoText(@"Settings", 22, [DuoTheme text], YES);
    [header addArrangedSubview:title];
    UIView* flex = [[UIView alloc] init];
    [flex setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:flex];
    UIStackView* clockCol = [[UIStackView alloc] init];
    clockCol.axis = UILayoutConstraintAxisVertical;
    clockCol.alignment = UIStackViewAlignmentTrailing;
    _clock = DuoText(@"", 30, [DuoTheme text], NO);
    _clock.font = [DuoTheme digits:30 * d weight:UIFontWeightMedium];
    _dateLine = DuoText(@"", 12, [DuoTheme text2], NO);
    [clockCol addArrangedSubview:_clock];
    [clockCol addArrangedSubview:_dateLine];
    [header addArrangedSubview:clockCol];
    [col addArrangedSubview:header];

    // tabs
    UIStackView* tabRow = [[UIStackView alloc] init];
    tabRow.alignment = UIStackViewAlignmentCenter;
    tabRow.layoutMarginsRelativeArrangement = YES;
    tabRow.layoutMargins = UIEdgeInsetsMake(0, 12 * d, 0, 12 * d);
    UILabel* lb = DuoKeyPill(@"LB");
    UILabel* rb = DuoKeyPill(@"RB");
    _pills = @[lb, rb];
    _tabScroll = [[DuoScrollView alloc] init];
    _tabScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _tabScroll.showsHorizontalScrollIndicator = NO;
    UIStackView* tabs = [[UIStackView alloc] init];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;
    tabs.spacing = 4 * d;
    tabs.layoutMarginsRelativeArrangement = YES;
    tabs.layoutMargins = UIEdgeInsetsMake(10 * d, 16 * d, 6 * d, 16 * d);
    [_tabScroll addSubview:tabs];
    NSMutableArray* tv = [NSMutableArray array];
    NSMutableArray* ul = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)_tabs.count; i++) {
        UIControl* t = [[UIControl alloc] init];
        t.translatesAutoresizingMaskIntoConstraints = NO;
        t.tag = i;
        UILabel* l = DuoText(@"", 12, [DuoTheme text2], YES);
        [t addSubview:l];
        UIView* u = [[UIView alloc] init];
        u.translatesAutoresizingMaskIntoConstraints = NO;
        u.backgroundColor = [DuoTheme accent];
        [t addSubview:u];
        [NSLayoutConstraint activateConstraints:@[
            [l.leadingAnchor constraintEqualToAnchor:t.leadingAnchor constant:11 * d],
            [l.trailingAnchor constraintEqualToAnchor:t.trailingAnchor constant:-11 * d],
            [l.centerYAnchor constraintEqualToAnchor:t.centerYAnchor],
            [t.heightAnchor constraintEqualToConstant:30 * d],
            [u.leadingAnchor constraintEqualToAnchor:t.leadingAnchor],
            [u.trailingAnchor constraintEqualToAnchor:t.trailingAnchor],
            [u.bottomAnchor constraintEqualToAnchor:t.bottomAnchor],
            [u.heightAnchor constraintEqualToConstant:2 * d],
        ]];
        [t addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tabs addArrangedSubview:t];
        [tv addObject:l];
        [ul addObject:u];
    }
    _tabViews = tv;
    _underlines = ul;
    [NSLayoutConstraint activateConstraints:@[
        [tabs.topAnchor constraintEqualToAnchor:_tabScroll.contentLayoutGuide.topAnchor],
        [tabs.bottomAnchor constraintEqualToAnchor:_tabScroll.contentLayoutGuide.bottomAnchor],
        [tabs.leadingAnchor constraintEqualToAnchor:_tabScroll.contentLayoutGuide.leadingAnchor],
        [tabs.trailingAnchor constraintEqualToAnchor:_tabScroll.contentLayoutGuide.trailingAnchor],
        [tabs.heightAnchor constraintEqualToAnchor:_tabScroll.frameLayoutGuide.heightAnchor],
        [_tabScroll.heightAnchor constraintEqualToConstant:46 * d],
    ]];
    // Tabs fade out softly at the left / right edge.
    CAGradientLayer* fade = [CAGradientLayer layer];
    fade.startPoint = CGPointMake(0, 0.5);
    fade.endPoint = CGPointMake(1, 0.5);
    fade.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor blackColor].CGColor, (id)[UIColor blackColor].CGColor, (id)[UIColor clearColor].CGColor];
    fade.locations = @[@0, @0.05, @0.95, @1];
    fade.frame = CGRectMake(0, 0, 4000, 200);
    UIView* tabWrap = [[UIView alloc] init];
    tabWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [tabWrap addSubview:_tabScroll];
    [NSLayoutConstraint activateConstraints:@[
        [_tabScroll.topAnchor constraintEqualToAnchor:tabWrap.topAnchor],
        [_tabScroll.bottomAnchor constraintEqualToAnchor:tabWrap.bottomAnchor],
        [_tabScroll.leadingAnchor constraintEqualToAnchor:tabWrap.leadingAnchor],
        [_tabScroll.trailingAnchor constraintEqualToAnchor:tabWrap.trailingAnchor],
    ]];
    [tabWrap setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [tabRow addArrangedSubview:lb];
    [tabRow addArrangedSubview:tabWrap];
    [tabRow addArrangedSubview:rb];
    [col addArrangedSubview:tabRow];
    _tabFade = fade;

    // content
    _scroll = [[DuoScrollView alloc] init];
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _scroll.alwaysBounceVertical = YES;
    _scroll.delaysContentTouches = NO;
    _scroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    _list = [[UIStackView alloc] init];
    _list.axis = UILayoutConstraintAxisVertical;
    _list.translatesAutoresizingMaskIntoConstraints = NO;
    [_scroll addSubview:_list];
    [NSLayoutConstraint activateConstraints:@[
        [_list.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor],
        [_list.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor constant:-16 * d],
        [_list.leadingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.leadingAnchor constant:16 * d],
        [_list.trailingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.trailingAnchor constant:-16 * d],
        [_list.widthAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.widthAnchor constant:-32 * d],
    ]];
    [_scroll setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [col addArrangedSubview:_scroll];

    // bottom: Back (B)
    UIStackView* bottom = [[UIStackView alloc] init];
    bottom.alignment = UIStackViewAlignmentCenter;
    bottom.layoutMarginsRelativeArrangement = YES;
    bottom.layoutMargins = UIEdgeInsetsMake(8 * d, 20 * d, 12 * d, 20 * d);
    _back = [[DuoButton alloc] initWithTitle:@"‹  Back" glyph:@"B" primary:NO];
    [_back.heightAnchor constraintEqualToConstant:36 * d].active = YES;
    __weak DuoSettingsViewController* weakSelf = self;
    _back.onTap = ^{
        [weakSelf close];
    };
    [bottom addArrangedSubview:_back];
    UIView* f2 = [[UIView alloc] init];
    [f2 setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [bottom addArrangedSubview:f2];
    [col addArrangedSubview:bottom];

    [self styleTabs];
    [self buildTab:NO dir:0];
    [self updateGlyphs];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateGlyphs) name:DuoPadChangedNotification object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _tabFade.frame = _tabScroll.superview.bounds;
    _tabScroll.superview.layer.mask = _tabFade;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[DuoPad shared] push:self];
    __weak DuoSettingsViewController* weakSelf = self;
    _clockTimer = [NSTimer scheduledTimerWithTimeInterval:10 repeats:YES block:^(NSTimer* t) {
        [weakSelf updateClock];
    }];
    [self updateClock];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[DuoPad shared] remove:self];
    [_clockTimer invalidate];
    _clockTimer = nil;
    [self save];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)updateClock {
    _clock.text = DuoClockText();
    _dateLine.text = DuoDateLine();
}

- (void)updateGlyphs {
    BOOL pad = [DuoPad shared].hasGamepad;
    for (UIView* p in _pills) {
        p.hidden = !pad;
    }
    [_back updateGlyphs:pad];
    [self showFocus];
}

- (void)close {
    [self save];
    void (^done)(void) = self.onClose;
    [self dismissViewControllerAnimated:YES completion:^{
        if (done != nil) {
            done();
        }
    }];
}

#pragma mark Moonlight values

- (void)load {
    TemporarySettings* s = [[[DataManager alloc] init] getSettings];
    _bitrate = [s.bitrate integerValue];
    _framerate = [s.framerate integerValue];
    _width = [s.width integerValue];
    _height = [s.height integerValue];
    _audio = MAX(2, [s.audioConfig integerValue]);
    _osc = [s.onscreenControls integerValue];
    _optimize = s.optimizeGames;
    _multi = s.multiController;
    _swapABXY = s.swapABXYButtons;
    _audioOnPC = s.playAudioOnPC;
    _codec = s.preferredCodec;
    _pacing = s.useFramePacing;
    _hdr = s.enableHdr;
    _btMouse = s.btMouseSupport;
    _absolute = s.absoluteTouchMode;
    _stats = s.statsOverlay;
    CGSize n = [UIScreen mainScreen].nativeBounds.size;
    _device = CGSizeMake(MAX(n.width, n.height), MIN(n.width, n.height));
    if ([DuoPrefs isIPadPro11FirstGen]) {
        _device = CGSizeMake(2388, 1668);
    }
}

- (void)save {
    [[[DataManager alloc] init] saveSettingsWithBitrate:_bitrate
                                              framerate:_framerate
                                                 height:_height
                                                  width:_width
                                            audioConfig:_audio
                                       onscreenControls:_osc
                                          optimizeGames:_optimize
                                        multiController:_multi
                                        swapABXYButtons:_swapABXY
                                              audioOnPC:_audioOnPC
                                         preferredCodec:_codec
                                         useFramePacing:_pacing
                                              enableHdr:_hdr
                                         btMouseSupport:_btMouse
                                      absoluteTouchMode:_absolute
                                           statsOverlay:_stats];
}

#pragma mark Row builders

- (DuoSetting*)toggle:(NSString*)title summary:(NSString*)summary get:(BOOL (^)(void))get set:(void (^)(BOOL))set {
    DuoSetting* s = [[DuoSetting alloc] init];
    s.kind = DuoRowToggle;
    s.title = title;
    s.summary = summary;
    s.getOn = get;
    s.setOn = set;
    return s;
}

- (DuoSetting*)prefToggle:(NSString*)title summary:(NSString*)summary key:(NSString*)key fallback:(BOOL)fallback {
    return [self toggle:title summary:summary get:^BOOL{
        return [DuoPrefs boolFor:key fallback:fallback];
    } set:^(BOOL on) {
        [DuoPrefs setBool:on forKey:key];
    }];
}

- (DuoSetting*)choice:(NSString*)title summary:(NSString*)summary names:(NSArray<NSString*>*)names
                  get:(NSInteger (^)(void))get set:(void (^)(NSInteger))set {
    DuoSetting* s = [[DuoSetting alloc] init];
    NSInteger total = 0;
    BOOL fits = names.count >= 2 && names.count <= 5;
    for (NSString* n in names) {
        total += n.length;
        fits &= n.length <= 16;
    }
    s.kind = fits && total <= 40 ? DuoRowPills : DuoRowList;
    s.title = title;
    s.summary = summary;
    s.names = names;
    s.getIndex = get;
    s.setIndex = set;
    return s;
}

- (DuoSetting*)prefChoice:(NSString*)title summary:(NSString*)summary names:(NSArray<NSString*>*)names
                   values:(NSArray*)values key:(NSString*)key fallback:(id)fallback {
    BOOL ints = [fallback isKindOfClass:[NSNumber class]];
    return [self choice:title summary:summary names:names get:^NSInteger{
        id v = ints ? (id)@([DuoPrefs intFor:key fallback:[fallback integerValue]]) : (id)[DuoPrefs stringFor:key fallback:fallback];
        NSUInteger i = [values indexOfObject:v];
        return i == NSNotFound ? 0 : (NSInteger)i;
    } set:^(NSInteger i) {
        if (ints) {
            [DuoPrefs setInt:[values[i] integerValue] forKey:key];
        } else {
            [DuoPrefs setString:values[i] forKey:key];
        }
    }];
}

- (DuoSetting*)slider:(NSString*)title summary:(NSString*)summary min:(float)min max:(float)max step:(float)step
                  get:(float (^)(void))get set:(void (^)(float))set format:(NSString* (^)(float))format {
    DuoSetting* s = [[DuoSetting alloc] init];
    s.kind = DuoRowSlider;
    s.title = title;
    s.summary = summary;
    s.min = min;
    s.max = max;
    s.step = step;
    s.getValue = get;
    s.setValue = set;
    s.format = format;
    return s;
}

- (DuoSetting*)prefSlider:(NSString*)title summary:(NSString*)summary key:(NSString*)key fallback:(NSInteger)fallback
                      min:(float)min max:(float)max step:(float)step suffix:(NSString*)suffix {
    return [self slider:title summary:summary min:min max:max step:step get:^float{
        return [DuoPrefs intFor:key fallback:fallback];
    } set:^(float v) {
        [DuoPrefs setInt:lroundf(v) forKey:key];
    } format:^NSString*(float v) {
        return [NSString stringWithFormat:@"%ld%@", lroundf(v), suffix];
    }];
}

- (DuoSetting*)info:(NSString*)title summary:(NSString*)summary {
    DuoSetting* s = [[DuoSetting alloc] init];
    s.kind = DuoRowInfo;
    s.title = title;
    s.summary = summary;
    return s;
}

- (DuoSetting*)action:(NSString*)title summary:(NSString*)summary run:(void (^)(void))run {
    DuoSetting* s = [[DuoSetting alloc] init];
    s.kind = DuoRowAction;
    s.title = title;
    s.summary = summary;
    s.action = run;
    return s;
}

#pragma mark Tabs content

- (NSArray<DuoSection*>*)sectionsFor:(NSInteger)tab {
    // The rows (and their blocks) belong to this screen, so it outlives them.
    __unsafe_unretained DuoSettingsViewController* w = self;
    switch (tab) {
        case 0: {
            NSArray* accentNames = [DuoTheme accentNames];
            NSArray* accentValues = [DuoTheme accentValues];
            return @[
                DuoSec(@"Look", @[
                    [self prefChoice:@"Accent color" summary:@"Buttons, waves, focus and progress" names:accentNames values:accentValues key:@"duo_accent" fallback:@"#00D3F2"],
                    [self prefChoice:@"Start screen" summary:@"Logo when the app opens" names:@[@"Off", @"1 s", @"2 s", @"3 s"] values:@[@0, @1, @2, @3] key:@"duo_splash" fallback:@2],
                ]),
                DuoSec(@"Controller", @[
                    [self prefToggle:@"Haptic tick" summary:@"A fine tick when the controller moves the selection" key:@"duo_nav_haptic" fallback:YES],
                ]),
                DuoSec(@"New in Artemide Duo (also in their own tabs)", @[
                    [self prefToggle:@"Virtual display" summary:@"Apollo / Vibeshine create a display in exactly the stream resolution" key:@"duo_virtual_display" fallback:YES],
                    [self prefToggle:@"Clipboard sync" summary:@"Copy on one side, paste on the other (Apollo / Vibeshine)" key:@"duo_clipboard_sync" fallback:YES],
                    [self prefChoice:@"Overlay style" summary:nil names:@[@"New", @"Detailed", @"Classic"] values:@[@"new", @"detailed", @"classic"] key:@"duo_overlay_style" fallback:@"new"],
                ]),
            ];
        }
        case 1: {
            NSMutableArray* resNames = [NSMutableArray arrayWithArray:@[@"720p", @"1080p", @"1440p", @"4K"]];
            NSString* devName = [DuoPrefs isIPadPro11FirstGen] ? @"iPad Pro 11\"" : [NSString stringWithFormat:@"This device (%d×%d)", (int)_device.width, (int)_device.height];
            [resNames addObject:devName];
            BOOL custom = [self resolutionIndex] == 5;
            [resNames addObject:custom ? [NSString stringWithFormat:@"Custom (%ld×%ld)", (long)_width, (long)_height] : @"Custom…"];
            BOOL fps120 = [UIScreen mainScreen].maximumFramesPerSecond > 62;
            NSArray* fpsNames = fps120 ? @[@"30", @"60", @"120"] : @[@"30", @"60"];
            NSMutableArray* codecNames = [NSMutableArray arrayWithObject:@"H.264"];
            NSMutableArray* codecValues = [NSMutableArray arrayWithObject:@(CODEC_PREF_H264)];
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                [codecNames addObject:@"HEVC"];
                [codecValues addObject:@(CODEC_PREF_HEVC)];
            }
#if defined(__IPHONE_16_0)
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)) {
                [codecNames addObject:@"AV1"];
                [codecValues addObject:@(CODEC_PREF_AV1)];
            }
#endif
            [codecNames addObject:@"Auto"];
            [codecValues addObject:@(CODEC_PREF_AUTO)];
            BOOL hdrOk = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10);
            NSMutableArray* stream = [NSMutableArray arrayWithArray:@[
                [self choice:@"Resolution" summary:@"Stream resolution (the virtual display uses it too)" names:resNames get:^NSInteger{
                    return [w resolutionIndex];
                } set:^(NSInteger i) {
                    [w setResolutionIndex:i];
                }],
                [self choice:@"Frame rate" summary:@"FPS" names:fpsNames get:^NSInteger{
                    DuoSettingsViewController* s = w;
                    return s->_framerate >= 120 ? 2 : s->_framerate <= 30 ? 0 : 1;
                } set:^(NSInteger i) {
                    DuoSettingsViewController* s = w;
                    s->_framerate = i == 0 ? 30 : i == 1 ? 60 : 120;
                    [s defaultBitrate];
                }],
                [self prefChoice:@"Custom refresh rate" summary:@"Overrides the frame rate above (e.g. 90 Hz on the PC)" names:@[@"Off", @"48", @"50", @"72", @"90", @"100", @"144"]
                          values:@[@0, @48, @50, @72, @90, @100, @144] key:@"duo_custom_fps" fallback:@0],
                [self slider:@"Video bitrate" summary:@"Higher = sharper, needs a faster network" min:0 max:kBitrateCount - 1 step:1 get:^float{
                    return [w bitrateIndex:w ? ((DuoSettingsViewController*)w)->_bitrate : 20000];
                } set:^(float v) {
                    DuoSettingsViewController* s = w;
                    s->_bitrate = kBitrates[MAX(0, MIN(kBitrateCount - 1, lroundf(v)))];
                } format:^NSString*(float v) {
                    return [NSString stringWithFormat:@"%.1f Mbps", kBitrates[MAX(0, MIN(kBitrateCount - 1, lroundf(v)))] / 1000.0];
                }],
                [self slider:@"Bitrate on mobile data" summary:@"Used automatically when there's no Wi-Fi" min:-1 max:kBitrateCount - 1 step:1 get:^float{
                    NSInteger m = [DuoPrefs mobileBitrate];
                    return m <= 0 ? -1 : [w bitrateIndex:m];
                } set:^(float v) {
                    NSInteger i = lroundf(v);
                    [DuoPrefs setInt:i < 0 ? 0 : kBitrates[MIN(kBitrateCount - 1, i)] forKey:@"duo_mobile_bitrate"];
                } format:^NSString*(float v) {
                    NSInteger i = lroundf(v);
                    return i < 0 ? @"Same as Wi-Fi" : [NSString stringWithFormat:@"%.1f Mbps", kBitrates[MIN(kBitrateCount - 1, i)] / 1000.0];
                }],
                [self choice:@"Video codec" summary:nil names:codecNames get:^NSInteger{
                    NSUInteger i = [codecValues indexOfObject:@(((DuoSettingsViewController*)w)->_codec)];
                    return i == NSNotFound ? (NSInteger)codecValues.count - 1 : (NSInteger)i;
                } set:^(NSInteger i) {
                    ((DuoSettingsViewController*)w)->_codec = [codecValues[i] unsignedIntValue];
                }],
            ]];
            if (hdrOk) {
                [stream addObject:[self toggle:@"HDR" summary:@"10-bit HDR when the PC and the game support it" get:^BOOL{
                    return ((DuoSettingsViewController*)w)->_hdr;
                } set:^(BOOL on) {
                    ((DuoSettingsViewController*)w)->_hdr = on;
                }]];
            }
            [stream addObject:[self choice:@"Frame pacing" summary:nil names:@[@"Lowest latency", @"Smoothest video"] get:^NSInteger{
                return ((DuoSettingsViewController*)w)->_pacing ? 1 : 0;
            } set:^(NSInteger i) {
                ((DuoSettingsViewController*)w)->_pacing = i == 1;
            }]];
            return @[
                DuoSec(@"Stream", stream),
                DuoSec(@"Display", @[
                    [self prefToggle:@"Virtual display" summary:@"Apollo / Vibeshine add a display in the stream resolution and remove it when you quit" key:@"duo_virtual_display" fallback:YES],
                    [self prefSlider:@"Resolution scale factor" summary:@"Apollo renders the virtual display at this scale" key:@"duo_scale_factor" fallback:100 min:50 max:200 step:10 suffix:@" %"],
                    [self prefChoice:@"Video scale mode" summary:@"How the picture fills the screen" names:@[@"Fit", @"Fill", @"Stretch"] values:@[@0, @1, @2] key:@"duo_video_scale" fallback:@0],
                    [self prefToggle:@"Portrait streaming" summary:@"Held upright, the stream starts in portrait (resolution turned)" key:@"duo_auto_orientation" fallback:NO],
                ]),
            ];
        }
        case 2:
            return @[DuoSec(@"Audio", @[
                [self choice:@"Audio" summary:@"Speaker setup sent to the PC" names:@[@"Stereo", @"5.1", @"7.1"] get:^NSInteger{
                    NSInteger a = ((DuoSettingsViewController*)w)->_audio;
                    return a >= 8 ? 2 : a >= 6 ? 1 : 0;
                } set:^(NSInteger i) {
                    ((DuoSettingsViewController*)w)->_audio = i == 2 ? 8 : i == 1 ? 6 : 2;
                }],
                [self toggle:@"Play audio on the PC" summary:@"Sound stays on the PC's speakers too" get:^BOOL{
                    return ((DuoSettingsViewController*)w)->_audioOnPC;
                } set:^(BOOL on) {
                    ((DuoSettingsViewController*)w)->_audioOnPC = on;
                }],
            ])];
        case 3:
            return @[
                DuoSec(@"Touchscreen", @[
                    [self choice:@"Touch mode" summary:@"Trackpad: move the mouse like a laptop pad · Direct: tap where you point" names:@[@"Trackpad", @"Direct"] get:^NSInteger{
                        return ((DuoSettingsViewController*)w)->_absolute ? 1 : 0;
                    } set:^(NSInteger i) {
                        ((DuoSettingsViewController*)w)->_absolute = i == 1;
                    }],
                    [self prefToggle:@"Multi-touch gestures" summary:@"2 fingers: tap = right click, move = scroll · 3 fingers: move = drag, tap = keyboard" key:@"duo_touch_gestures" fallback:YES],
                    [self choice:@"On-screen gamepad" summary:@"Trackpad mode only" names:@[@"Off", @"Auto", @"Simple", @"Full"] get:^NSInteger{
                        return ((DuoSettingsViewController*)w)->_osc;
                    } set:^(NSInteger i) {
                        ((DuoSettingsViewController*)w)->_osc = i;
                    }],
                    [self prefToggle:@"Remember zoom and position" summary:@"Direct mode: the zoom stays for the next stream" key:@"duo_remember_zoom" fallback:NO],
                ]),
                DuoSec(@"Trackpad", @[
                    [self prefSlider:@"Speed horizontal" summary:nil key:@"duo_trackpad_x" fallback:100 min:20 max:300 step:10 suffix:@" %"],
                    [self prefSlider:@"Speed vertical" summary:nil key:@"duo_trackpad_y" fallback:100 min:20 max:300 step:10 suffix:@" %"],
                    [self prefToggle:@"Swap axes" summary:@"For a rotated picture" key:@"duo_trackpad_swap" fallback:NO],
                    [self prefSlider:@"Hold to drag" summary:@"Hold a finger this long to start dragging" key:@"duo_drag_hold" fallback:650 min:150 max:1500 step:50 suffix:@" ms"],
                ]),
                DuoSec(@"Mouse & Magic Keyboard trackpad", @[
                    [self prefToggle:@"Smooth local cursor in apps" summary:@"Desktop / remote apps: the iPad draws the pointer, so it never lags (the PC's own cursor follows it). Games always get the raw mouse." key:@"duo_local_cursor" fallback:YES],
                    [self prefSlider:@"Mouse / trackpad speed" summary:@"Games and pointer-locked apps" key:@"duo_mouse_speed" fallback:100 min:20 max:400 step:10 suffix:@" %"],
                    [self prefToggle:@"Natural scrolling" summary:@"Two-finger scroll direction like on the iPad" key:@"duo_natural_scroll" fallback:YES],
                    [self toggle:@"Citrix X1 mouse" summary:@"Bluetooth mouse support for Citrix X1 mice" get:^BOOL{
                        return ((DuoSettingsViewController*)w)->_btMouse;
                    } set:^(BOOL on) {
                        ((DuoSettingsViewController*)w)->_btMouse = on;
                    }],
                ]),
                DuoSec(@"Magic Keyboard (keys it doesn't have)", @[
                    [self info:@"Esc" summary:@"Cmd + .  or  Cmd + `  (or set Caps Lock to Escape in iPadOS: Settings → General → Keyboard → Hardware Keyboard → Modifier Keys)"],
                    [self info:@"F1 … F12" summary:@"Ctrl + Option + 1 … 0, - and ="],
                    [self info:@"Windows key" summary:@"Cmd. Alt + Tab: Option + Tab (Cmd + Tab stays with iPadOS)"],
                    [self info:@"In the app" summary:@"Arrows move, Return opens, Esc / Cmd + . goes back, Tab / Shift + Tab switch tabs, Cmd + , settings, Cmd + F favourite, Cmd + I options, Cmd + ⌫ quit all. "],
                ]),
            ];
        case 4:
            return @[
                DuoSec(@"Gamepad", @[
                    [self prefSlider:@"Stick deadzone" summary:@"Ignore small stick movements" key:@"duo_deadzone" fallback:5 min:0 max:20 step:1 suffix:@" %"],
                    [self toggle:@"Swap A/B and X/Y" summary:@"Nintendo layout" get:^BOOL{
                        return ((DuoSettingsViewController*)w)->_swapABXY;
                    } set:^(BOOL on) {
                        ((DuoSettingsViewController*)w)->_swapABXY = on;
                    }],
                    [self choice:@"Multiple controllers" summary:nil names:@[@"Single", @"Auto"] get:^NSInteger{
                        return ((DuoSettingsViewController*)w)->_multi ? 1 : 0;
                    } set:^(NSInteger i) {
                        ((DuoSettingsViewController*)w)->_multi = i == 1;
                    }],
                    [self prefToggle:@"Report battery to the PC" summary:@"Controller battery level on the host" key:@"duo_battery_report" fallback:YES],
                ]),
                DuoSec(@"Rumble", @[
                    [self prefToggle:@"iPhone vibration fallback" summary:@"Vibrates the iPhone when the controller can't rumble" key:@"duo_rumble_fallback" fallback:NO],
                ]),
                DuoSec(@"Mouse with the gamepad", @[
                    [self prefToggle:@"Controller as mouse" summary:@"Shortcut toggles: left stick = mouse, right stick = scroll, A = click, B = right click, X = Windows key, Y = Alt+Tab" key:@"duo_gamepad_mouse" fallback:YES],
                    [self prefToggle:@"Touchpad as mouse" summary:@"DualSense / DualShock touchpad moves the mouse" key:@"duo_touchpad_mouse" fallback:NO],
                ]),
                DuoSec(@"Motion sensors", @[
                    [self prefToggle:@"Device gyro fallback" summary:@"Uses the iPhone / iPad gyro when the controller has none" key:@"duo_motion_fallback" fallback:NO],
                ]),
            ];
        case 5: {
            NSMutableArray* rows = [NSMutableArray array];
            NSArray* buttons = [DuoPrefs shortcutButtons];
            for (NSString* act in [DuoPrefs shortcutActions]) {
                NSString* key = [@"duo_pad_sc_" stringByAppendingString:act];
                [rows addObject:[self prefChoice:[DuoPrefs shortcutTitle:act] summary:nil names:buttons values:buttons key:key fallback:[DuoPrefs shortcutButton:act]]];
            }
            return @[DuoSec(@"Controller (hold LB + RB + button)", rows)];
        }
        case 6:
            return @[DuoSec(@"Performance overlay", @[
                [self toggle:@"Show performance overlay" summary:@"Resolution, FPS, bitrate and latency while streaming" get:^BOOL{
                    return ((DuoSettingsViewController*)w)->_stats;
                } set:^(BOOL on) {
                    ((DuoSettingsViewController*)w)->_stats = on;
                }],
                [self prefChoice:@"Overlay style" summary:nil names:@[@"New", @"Detailed", @"Classic"] values:@[@"new", @"detailed", @"classic"] key:@"duo_overlay_style" fallback:@"new"],
                [self prefChoice:@"Overlay opacity" summary:@"Background of the new style" names:@[@"25 %", @"40 %", @"55 %", @"70 %"] values:@[@25, @40, @55, @70] key:@"duo_overlay_opacity" fallback:@25],
                [self prefChoice:@"Position" summary:nil names:@[@"Top", @"Bottom"] values:@[@0, @1] key:@"duo_overlay_bottom_i" fallback:@0],
                [self prefToggle:@"Host processing latency" summary:@"Encoder time on the PC (Sunshine / Apollo)" key:@"duo_overlay_host" fallback:NO],
            ])];
        case 7:
            return @[
                DuoSec(@"In the stream", @[
                    [self prefToggle:@"Resume without asking" summary:@"Tapping the running app resumes it, a different app replaces it" key:@"duo_resume_no_confirm" fallback:YES],
                    [self prefToggle:@"Ask before leaving the stream" summary:@"Edge swipe asks Disconnect / Quit" key:@"duo_quit_dialog" fallback:NO],
                    [self prefToggle:@"Floating menu button" summary:@"Small button in the stream: quit, keyboard, overlay, mouse mode" key:@"duo_floating_button" fallback:YES],
                    [self prefToggle:@"Picture in Picture" summary:@"Keep watching in a small window when you leave the app" key:@"duo_pip" fallback:NO],
                ]),
                DuoSec(@"App", @[
                    [self prefToggle:@"Session summary" summary:@"After a stream: play time and data used" key:@"duo_post_toast" fallback:YES],
                    [self prefToggle:@"Hide connection warnings" summary:@"No \"slow connection\" notes in the stream" key:@"duo_disable_warnings" fallback:NO],
                ]),
            ];
        case 8:
            return @[
                DuoSec(@"Host", @[
                    [self toggle:@"Optimize game settings" summary:@"Let the PC adjust game settings for the stream" get:^BOOL{
                        return ((DuoSettingsViewController*)w)->_optimize;
                    } set:^(BOOL on) {
                        ((DuoSettingsViewController*)w)->_optimize = on;
                    }],
                ]),
                DuoSec(@"Upscaling", @[
                    [DuoPrefs metalFXSupported]
                        ? [self prefToggle:@"MetalFX upscaling (experimental)" summary:@"Apple's upscaler sharpens a lower stream resolution to the full screen (SDR only; no Picture in Picture while on)" key:@"duo_metalfx" fallback:NO]
                        : [self info:@"MetalFX upscaling" summary:@"Not supported on this device (needs an A13 chip or newer; the iPad Pro 2018 has an A12X)."],
                ]),
            ];
        default: {
            NSString* version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
            return @[
                DuoSec(@"Clipboard", @[
                    [self prefToggle:@"Clipboard sync" summary:@"iPad / iPhone → PC when the stream starts or you come back; PC → here when you leave" key:@"duo_clipboard_sync" fallback:YES],
                    [self prefToggle:@"Show a note when syncing" summary:nil key:@"duo_clipboard_toast" fallback:YES],
                    [self prefToggle:@"Hide clipboard content" summary:@"The note doesn't show the copied text" key:@"duo_clipboard_hide" fallback:YES],
                ]),
                DuoSec(@"Other", @[
                    [self info:[NSString stringWithFormat:@"Artemide Duo v%@", version] summary:@"Developed by Chang Cao, 2026\nBased on Moonlight for iOS · Artemide · StreamLight"],
                ]),
            ];
        }
    }
}

#pragma mark Resolution, bitrate helpers

- (NSInteger)resolutionIndex {
    CGSize table[] = {{1280, 720}, {1920, 1080}, {2560, 1440}, {3840, 2160}, _device};
    for (NSInteger i = 0; i < 5; i++) {
        if ((NSInteger)table[i].width == _width && (NSInteger)table[i].height == _height) {
            return i;
        }
    }
    return 5;
}

- (void)setResolutionIndex:(NSInteger)i {
    CGSize table[] = {{1280, 720}, {1920, 1080}, {2560, 1440}, {3840, 2160}, _device};
    if (i < 5) {
        _width = (NSInteger)table[i].width;
        _height = (NSInteger)table[i].height;
        [self defaultBitrate];
        return;
    }
    UIAlertController* a = [UIAlertController alertControllerWithTitle:@"Custom resolution" message:@"Width × height in pixels" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField* t) {
        t.keyboardType = UIKeyboardTypeNumberPad;
        t.placeholder = @"Width";
        t.text = [NSString stringWithFormat:@"%ld", (long)self->_width];
    }];
    [a addTextFieldWithConfigurationHandler:^(UITextField* t) {
        t.keyboardType = UIKeyboardTypeNumberPad;
        t.placeholder = @"Height";
        t.text = [NSString stringWithFormat:@"%ld", (long)self->_height];
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* x) {
        [self buildTab:NO dir:0];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* x) {
        NSInteger wv = [a.textFields[0].text integerValue], hv = [a.textFields[1].text integerValue];
        if (wv >= 256 && hv >= 256 && wv <= 8192 && hv <= 8192) {
            self->_width = wv & ~1;
            self->_height = hv & ~1;
            [self defaultBitrate];
        }
        [self buildTab:NO dir:0];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (float)bitrateIndex:(NSInteger)kbps {
    for (int i = 0; i < kBitrateCount; i++) {
        if (kbps <= kBitrates[i]) {
            return i;
        }
    }
    return kBitrateCount - 1;
}

/// Moonlight's default bitrate for the resolution and frame rate (like its settings do).
- (void)defaultBitrate {
    NSInteger fps = _framerate;
    float k = (_width * _height) / (1920.0f * 1080.0f);
    float base = 20000 * k * (fps / 60.0f);
    NSInteger idx = (NSInteger)[self bitrateIndex:(NSInteger)base];
    _bitrate = kBitrates[idx];
}

#pragma mark Building

- (void)styleTabs {
    for (NSInteger i = 0; i < (NSInteger)_tabs.count; i++) {
        BOOL on = i == _tab;
        _tabViews[i].attributedText = [DuoTheme spaced:[_tabs[i] uppercaseString] font:[DuoTheme semibold:12 * d]
                                                  color:on ? [DuoTheme text] : [DuoTheme text2] em:0.12];
        _underlines[i].hidden = !on;
    }
    UIView* cur = _tabViews[_tab].superview;
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect f = [cur convertRect:cur.bounds toView:self->_tabScroll];
        [self->_tabScroll scrollRectToVisible:CGRectInset(f, -40 * self->d, 0) animated:YES];
    });
}

- (void)tabTapped:(UIControl*)t {
    [self selectTab:t.tag];
}

- (void)selectTab:(NSInteger)t {
    NSInteger old = _tab;
    _tab = (t + (NSInteger)_tabs.count) % (NSInteger)_tabs.count;
    sLastTab = _tab;
    [self styleTabs];
    if (old != _tab) {
        _focus = 0;
        [self buildTab:YES dir:_tab > old ? 1 : -1];
    }
}

- (void)buildTab:(BOOL)animate dir:(NSInteger)dir {
    for (UIView* v in _list.arrangedSubviews.copy) {
        [v removeFromSuperview];
    }
    NSMutableArray<DuoSettingRowView*>* rows = [NSMutableArray array];
    NSMutableArray<UIView*>* blocks = [NSMutableArray array];
    for (DuoSection* sec in [self sectionsFor:_tab]) {
        UIView* head = [[UIView alloc] init];
        head.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel* t = DuoText(@"", 10, [DuoTheme text2], YES);
        t.font = [DuoTheme bold:10 * d];
        t.attributedText = [DuoTheme spaced:[sec.title uppercaseString] font:[DuoTheme bold:10 * d] color:[DuoTheme text2] em:0.15];
        t.numberOfLines = 0;
        [head addSubview:t];
        [NSLayoutConstraint activateConstraints:@[
            [t.topAnchor constraintEqualToAnchor:head.topAnchor constant:16 * d],
            [t.bottomAnchor constraintEqualToAnchor:head.bottomAnchor constant:-6 * d],
            [t.leadingAnchor constraintEqualToAnchor:head.leadingAnchor constant:2 * d],
            [t.trailingAnchor constraintEqualToAnchor:head.trailingAnchor],
        ]];
        [_list addArrangedSubview:head];
        [blocks addObject:head];
        UIStackView* group = [[UIStackView alloc] init];
        group.axis = UILayoutConstraintAxisVertical;
        group.translatesAutoresizingMaskIntoConstraints = NO;
        for (NSUInteger i = 0; i < sec.rows.count; i++) {
            DuoSettingRowView* r = [self rowView:sec.rows[i]];
            r.first = i == 0;
            r.last = i == sec.rows.count - 1;
            [group addArrangedSubview:r];
            [rows addObject:r];
        }
        [_list addArrangedSubview:group];
        [blocks addObject:group];
    }
    _rows = rows;
    _focus = MIN(_focus, MAX(0, (NSInteger)rows.count - 1));
    [self showFocus];
    if (animate) {
        _scroll.contentOffset = CGPointZero;
        // Calm swap: the new tab glides in from its side, rows settle one after another.
        _scroll.alpha = 0;
        _scroll.transform = CGAffineTransformMakeTranslation(dir * 44 * d, 0);
        [DuoMotion ease:0.52 delay:0 animations:^{
            self->_scroll.alpha = 1;
            self->_scroll.transform = CGAffineTransformIdentity;
        } completion:nil];
        NSInteger i = 0;
        for (UIView* b in blocks) {
            if (i >= 10) {
                break;
            }
            b.alpha = 0;
            b.transform = CGAffineTransformMakeTranslation(0, 10 * d);
            [DuoMotion ease:0.42 delay:0.06 + i * 0.04 animations:^{
                b.alpha = 1;
                b.transform = CGAffineTransformIdentity;
            } completion:nil];
            i++;
        }
    }
}

- (DuoSettingRowView*)rowView:(DuoSetting*)s {
    DuoSettingRowView* r = [[DuoSettingRowView alloc] init];
    r.translatesAutoresizingMaskIntoConstraints = NO;
    r.setting = s;
    [r applyBackground:NO];
    UIStackView* h = [[UIStackView alloc] init];
    h.translatesAutoresizingMaskIntoConstraints = NO;
    h.alignment = UIStackViewAlignmentCenter;
    h.spacing = 10 * d;
    [r addSubview:h];
    UIStackView* texts = [[UIStackView alloc] init];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 2 * d;
    texts.userInteractionEnabled = NO;
    UILabel* title = DuoText(s.title, 13.5, [DuoTheme text], NO);
    title.font = [DuoTheme medium:13.5 * d];
    title.numberOfLines = 2;
    [texts addArrangedSubview:title];
    UILabel* sum = nil;
    if (s.summary.length > 0 || s.kind == DuoRowList || s.kind == DuoRowSlider) {
        sum = DuoText(s.summary ?: @"", 11, [DuoTheme text2], NO);
        sum.numberOfLines = s.kind == DuoRowInfo ? 0 : 4;
        [texts addArrangedSubview:sum];
    }
    [texts setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [texts setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [h addArrangedSubview:texts];
    __weak DuoSettingRowView* wr = r;
    switch (s.kind) {
        case DuoRowToggle: {
            DuoSwitch* sw = [[DuoSwitch alloc] init];
            sw.on = s.getOn();
            r.toggle = sw;
            [h addArrangedSubview:sw];
            [r addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case DuoRowPills: {
            DuoPills* p = [[DuoPills alloc] initWithNames:s.names selected:s.getIndex()];
            __weak DuoSettingsViewController* w = self;
            p.onPick = ^(NSInteger i) {
                s.setIndex(i);
                [w changed:wr];
            };
            r.pills = p;
            [h addArrangedSubview:p];
            break;
        }
        case DuoRowList: {
            NSInteger i = s.getIndex();
            UILabel* v = DuoText(i >= 0 && i < (NSInteger)s.names.count ? s.names[i] : @"", 12, [DuoTheme accent], YES);
            r.value = v;
            UILabel* chev = DuoText(@"›", 18, [DuoTheme text3], NO);
            [h addArrangedSubview:v];
            [h addArrangedSubview:chev];
            [r addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case DuoRowSlider: {
            // Title row with the value on the right; the slider below.
            UIStackView* v = [[UIStackView alloc] init];
            v.axis = UILayoutConstraintAxisVertical;
            v.spacing = 4 * d;
            [h removeArrangedSubview:texts];
            [texts removeFromSuperview];
            UIStackView* top = [[UIStackView alloc] init];
            top.alignment = UIStackViewAlignmentFirstBaseline;
            [top addArrangedSubview:texts];
            UILabel* value = DuoText(s.format(s.getValue()), 12, [DuoTheme accent], YES);
            [value setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [top addArrangedSubview:value];
            r.value = value;
            [v addArrangedSubview:top];
            UISlider* sl = [[UISlider alloc] init];
            sl.minimumValue = s.min;
            sl.maximumValue = s.max;
            sl.value = s.getValue();
            sl.minimumTrackTintColor = [DuoTheme focus];
            sl.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.25];
            sl.thumbTintColor = [DuoTheme accent];
            [sl addTarget:self action:@selector(sliderMoved:) forControlEvents:UIControlEventValueChanged];
            r.slider = sl;
            [v addArrangedSubview:sl];
            [h addArrangedSubview:v];
            break;
        }
        case DuoRowAction:
            [r addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
            break;
        case DuoRowInfo:
            break;
    }
    [NSLayoutConstraint activateConstraints:@[
        [h.topAnchor constraintEqualToAnchor:r.topAnchor constant:9 * d],
        [h.bottomAnchor constraintEqualToAnchor:r.bottomAnchor constant:-9 * d],
        [h.leadingAnchor constraintEqualToAnchor:r.leadingAnchor constant:14 * d],
        [h.trailingAnchor constraintEqualToAnchor:r.trailingAnchor constant:-12 * d],
        [r.heightAnchor constraintGreaterThanOrEqualToConstant:56 * d],
    ]];
    return r;
}

- (void)sliderMoved:(UISlider*)sl {
    DuoSettingRowView* r = (DuoSettingRowView*)sl.superview;
    while (r != nil && ![r isKindOfClass:[DuoSettingRowView class]]) {
        r = (DuoSettingRowView*)r.superview;
    }
    if (r == nil) {
        return;
    }
    DuoSetting* s = r.setting;
    float v = roundf((sl.value - s.min) / s.step) * s.step + s.min;
    s.setValue(v);
    r.value.text = s.format(v);
}

- (void)rowTapped:(DuoSettingRowView*)r {
    [self activate:r];
}

- (void)activate:(DuoSettingRowView*)r {
    DuoSetting* s = r.setting;
    switch (s.kind) {
        case DuoRowToggle:
            s.setOn(!s.getOn());
            r.toggle.on = s.getOn();
            [self changed:r];
            break;
        case DuoRowList: {
            UIAlertController* a = [UIAlertController alertControllerWithTitle:s.title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            NSInteger cur = s.getIndex();
            for (NSInteger i = 0; i < (NSInteger)s.names.count; i++) {
                NSString* n = i == cur ? [@"✓  " stringByAppendingString:s.names[i]] : s.names[i];
                [a addAction:[UIAlertAction actionWithTitle:n style:UIAlertActionStyleDefault handler:^(UIAlertAction* x) {
                    s.setIndex(i);
                    [self changed:r];
                }]];
            }
            [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            a.popoverPresentationController.sourceView = r.value ?: r;
            a.popoverPresentationController.sourceRect = (r.value ?: r).bounds;
            [self presentViewController:a animated:YES completion:nil];
            break;
        }
        case DuoRowAction:
            if (s.action != nil) {
                s.action();
            }
            break;
        default:
            break;
    }
}

/// A value changed: refresh the row (and the tab, where one value changes others).
- (void)changed:(DuoSettingRowView*)r {
    DuoSetting* s = r.setting;
    if (s.kind == DuoRowList) {
        NSInteger i = s.getIndex();
        r.value.text = i >= 0 && i < (NSInteger)s.names.count ? s.names[i] : @"";
    }
    if ([s.title isEqualToString:@"Accent color"]) {
        [self accentChanged];
        return;
    }
    if ([s.title isEqualToString:@"Resolution"] || [s.title isEqualToString:@"Frame rate"]) {
        // The bitrate follows the resolution / frame rate.
        for (DuoSettingRowView* x in _rows) {
            if (x.setting.kind == DuoRowSlider && [x.setting.title isEqualToString:@"Video bitrate"]) {
                x.slider.value = x.setting.getValue();
                x.value.text = x.setting.format(x.slider.value);
            }
        }
    }
}

- (void)accentChanged {
    // Colours are read when views are built: rebuild this screen in the new accent.
    UIView* snap = [self.view snapshotViewAfterScreenUpdates:NO];
    for (UIView* v in self.view.subviews.copy) {
        [v removeFromSuperview];
    }
    [self.view addSubview:snap];
    NSInteger keepFocus = _focus;
    [self viewDidLoad];
    _focus = keepFocus;
    [self showFocus];
    [self.view bringSubviewToFront:snap];
    [UIView animateWithDuration:0.35 animations:^{
        snap.alpha = 0;
    } completion:^(BOOL f) {
        [snap removeFromSuperview];
    }];
}

#pragma mark Focus / controller

- (void)showFocus {
    BOOL pad = [DuoPad shared].focusVisible;
    for (NSInteger i = 0; i < (NSInteger)_rows.count; i++) {
        _rows[i].duoFocused = pad && i == _focus;
    }
}

- (void)scrollToFocus {
    if (_focus < 0 || _focus >= (NSInteger)_rows.count) {
        return;
    }
    DuoSettingRowView* r = _rows[_focus];
    CGRect f = [r convertRect:r.bounds toView:_scroll];
    [_scroll scrollRectToVisible:CGRectInset(f, 0, -40 * d) animated:YES];
}

- (BOOL)duoPadKey:(DuoPadKey)key {
    if (self.presentedViewController != nil) {
        return NO;
    }
    DuoSettingRowView* r = _focus < (NSInteger)_rows.count ? _rows[_focus] : nil;
    switch (key) {
        case DuoPadUp:
        case DuoPadDown: {
            NSInteger n = _focus + (key == DuoPadDown ? 1 : -1);
            while (n >= 0 && n < (NSInteger)_rows.count && _rows[n].setting.kind == DuoRowInfo) {
                n += key == DuoPadDown ? 1 : -1;
            }
            if (n >= 0 && n < (NSInteger)_rows.count) {
                _focus = n;
                [DuoMotion navTick];
            }
            [self showFocus];
            [self scrollToFocus];
            return YES;
        }
        case DuoPadLeft:
        case DuoPadRight: {
            NSInteger step = key == DuoPadRight ? 1 : -1;
            DuoSetting* s = r.setting;
            if (s.kind == DuoRowPills || s.kind == DuoRowList) {
                NSInteger i = MAX(0, MIN((NSInteger)s.names.count - 1, s.getIndex() + step));
                if (i != s.getIndex()) {
                    s.setIndex(i);
                    [r.pills select:i];
                    [self changed:r];
                    [DuoMotion navTick];
                }
            } else if (s.kind == DuoRowSlider) {
                float v = MAX(s.min, MIN(s.max, s.getValue() + step * s.step));
                s.setValue(v);
                r.slider.value = v;
                r.value.text = s.format(v);
                [DuoMotion navTick];
            } else if (s.kind == DuoRowToggle) {
                if (s.getOn() != (step > 0)) {
                    [self activate:r];
                }
            }
            return YES;
        }
        case DuoPadA:
            if (r != nil) {
                [DuoMotion tap:r];
                [self activate:r];
            }
            return YES;
        case DuoPadB:
            [_back fire];
            return YES;
        case DuoPadLB:
            [self selectTab:_tab - 1];
            return YES;
        case DuoPadRB:
            [self selectTab:_tab + 1];
            return YES;
        default:
            return YES;
    }
}

- (void)dealloc {
    [_clockTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

//
//  DuoStreamMenu.m
//  Artemide Duo for iOS
//

#import "DuoStreamMenu.h"
#import "DuoSupport.h"

@implementation DuoStreamMenu {
    CGFloat d;
    UIView* _button;
    UIView* _dim;
    UIView* _panel;
    UIStackView* _items;
    NSArray<DuoButton*>* _buttons;
    NSInteger _focus;
}

- (instancetype)initWithFrame:(CGRect)frame showButton:(BOOL)showButton {
    self = [super initWithFrame:frame];
    if (self) {
        d = [DuoTheme scale];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];
        if (showButton) {
            CGFloat s = 40 * d;
            _button = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width - s - 14 * d, frame.size.height * 0.3, s, s)];
            _button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            _button.backgroundColor = [[DuoTheme card] colorWithAlphaComponent:0.55];
            _button.layer.cornerRadius = s / 2;
            _button.layer.borderWidth = 1;
            _button.layer.borderColor = [[DuoTheme accent] colorWithAlphaComponent:0.45].CGColor;
            _button.alpha = 0.55;
            DuoLogoView* logo = [[DuoLogoView alloc] initWithSize:26 * d];
            logo.backgroundColor = [UIColor clearColor];
            logo.layer.borderWidth = 0;
            logo.translatesAutoresizingMaskIntoConstraints = YES;
            logo.frame = CGRectMake((s - 26 * d) / 2, (s - 26 * d) / 2, 26 * d, 26 * d);
            [_button addSubview:logo];
            [_button addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openMenu)]];
            [_button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
            [self addSubview:_button];
        }
    }
    return self;
}

// Only the button and the open menu take touches; everything else goes to the stream.
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* v = [super hitTest:point withEvent:event];
    return v == self ? nil : v;
}

- (void)drag:(UIPanGestureRecognizer*)g {
    CGPoint t = [g translationInView:self];
    CGPoint c = _button.center;
    c.x += t.x;
    c.y += t.y;
    CGFloat r = _button.bounds.size.width / 2;
    UIEdgeInsets safe = self.safeAreaInsets;
    c.x = MAX(r + safe.left, MIN(self.bounds.size.width - r - safe.right, c.x));
    c.y = MAX(r + safe.top, MIN(self.bounds.size.height - r - safe.bottom, c.y));
    _button.center = c;
    [g setTranslation:CGPointZero inView:self];
    _button.alpha = g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled ? 0.55 : 0.9;
    if (g.state == UIGestureRecognizerStateEnded) {
        // Snap to the nearest side.
        CGFloat x = c.x < self.bounds.size.width / 2 ? r + 14 * d + safe.left : self.bounds.size.width - r - 14 * d - safe.right;
        [DuoMotion spring:0.4 animations:^{
            self->_button.center = CGPointMake(x, c.y);
        }];
    }
}

- (BOOL)menuOpen {
    return _panel != nil;
}

- (void)openMenu {
    if (_panel != nil) {
        return;
    }
    _dim = [[UIView alloc] initWithFrame:self.bounds];
    _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    [_dim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeMenu)]];
    [self addSubview:_dim];

    _panel = [[UIView alloc] init];
    _panel.translatesAutoresizingMaskIntoConstraints = NO;
    _panel.backgroundColor = [[DuoTheme card] colorWithAlphaComponent:0.92];
    _panel.layer.cornerRadius = 18 * d;
    _panel.layer.borderWidth = 1;
    _panel.layer.borderColor = [DuoTheme line].CGColor;
    [self addSubview:_panel];
    UIStackView* col = [[UIStackView alloc] init];
    col.translatesAutoresizingMaskIntoConstraints = NO;
    col.axis = UILayoutConstraintAxisVertical;
    col.spacing = 8 * d;
    [_panel addSubview:col];
    UILabel* title = DuoText(@"", 15, [DuoTheme text], YES);
    title.attributedText = [DuoTheme brand:YES size:13 * d];
    [col addArrangedSubview:title];
    [col setCustomSpacing:12 * d afterView:title];

    NSMutableArray* buttons = [NSMutableArray array];
    __weak DuoStreamMenu* w = self;
    id<DuoStreamMenuDelegate> del = self.delegate;
    void (^add)(NSString*, void (^)(void)) = ^(NSString* t, void (^run)(void)) {
        DuoButton* b = [[DuoButton alloc] initWithTitle:t glyph:nil primary:NO];
        [b.heightAnchor constraintEqualToConstant:40 * self->d].active = YES;
        b.onTap = ^{
            [w closeMenu];
            run();
        };
        [col addArrangedSubview:b];
        [buttons addObject:b];
    };
    add(@"Keyboard", ^{ [del duoMenuKeyboard]; });
    add([del duoMenuPerfOn] ? @"Hide performance overlay" : @"Show performance overlay", ^{ [del duoMenuTogglePerf]; });
    if ([del duoMenuMouseAvailable]) {
        add([del duoMenuMouseOn] ? @"Controller: back to gamepad" : @"Controller as mouse", ^{ [del duoMenuToggleMouse]; });
    }
    add(@"Disconnect (keep the session)", ^{ [del duoMenuDisconnect]; });
    add(@"Quit session", ^{ [del duoMenuQuit]; });
    _buttons = buttons;
    _focus = 0;
    [NSLayoutConstraint activateConstraints:@[
        [_panel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_panel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_panel.widthAnchor constraintEqualToConstant:300 * d],
        [col.topAnchor constraintEqualToAnchor:_panel.topAnchor constant:18 * d],
        [col.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor constant:-18 * d],
        [col.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor constant:18 * d],
        [col.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor constant:-18 * d],
    ]];
    [self showFocus];
    _dim.alpha = 0;
    _panel.alpha = 0;
    _panel.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
        self->_dim.alpha = 1;
        self->_panel.alpha = 1;
        self->_panel.transform = CGAffineTransformIdentity;
    } completion:nil];
    if (self.onOpenChange != nil) {
        self.onOpenChange(YES);
    }
}

- (void)closeMenu {
    if (_panel == nil) {
        return;
    }
    if (self.onOpenChange != nil) {
        self.onOpenChange(NO);
    }
    UIView* p = _panel, *dim = _dim;
    _panel = nil;
    _dim = nil;
    _buttons = nil;
    [DuoMotion ease:0.22 delay:0 animations:^{
        p.alpha = 0;
        dim.alpha = 0;
        p.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^{
        [p removeFromSuperview];
        [dim removeFromSuperview];
    }];
}

- (void)showFocus {
    BOOL pad = [DuoPad shared].hasGamepad;
    for (NSInteger i = 0; i < (NSInteger)_buttons.count; i++) {
        _buttons[i].duoFocused = pad && i == _focus;
    }
}

- (BOOL)duoPadKey:(DuoPadKey)key {
    if (_panel == nil) {
        return NO;
    }
    switch (key) {
        case DuoPadUp:
        case DuoPadDown:
            _focus = MAX(0, MIN((NSInteger)_buttons.count - 1, _focus + (key == DuoPadDown ? 1 : -1)));
            [DuoMotion navTick];
            [self showFocus];
            return YES;
        case DuoPadA:
            if (_focus < (NSInteger)_buttons.count) {
                [_buttons[_focus] fire];
            }
            return YES;
        case DuoPadB:
            [self closeMenu];
            return YES;
        default:
            return YES;
    }
}

@end

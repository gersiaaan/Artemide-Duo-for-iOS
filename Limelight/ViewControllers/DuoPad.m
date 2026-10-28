//
//  DuoPad.m
//  Artemide Duo for iOS
//

#import "DuoPad.h"

@import GameController;

NSString* const DuoPadChangedNotification = @"DuoPadChanged";

@implementation DuoPad {
    NSPointerArray* _targets;
    BOOL _attached;
    NSMutableDictionary<NSValue*, NSNumber*>* _last;   // controller -> pressed mask
    NSTimer* _repeat;
    DuoPadKey _repeatKey;
}

+ (instancetype)shared {
    static DuoPad* p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        p = [[DuoPad alloc] init];
    });
    return p;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _targets = [NSPointerArray weakObjectsPointerArray];
        _last = [NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changed:) name:GCControllerDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changed:) name:GCControllerDidDisconnectNotification object:nil];
    }
    return self;
}

- (BOOL)hasGamepad {
    for (GCController* c in [GCController controllers]) {
        if (c.extendedGamepad != nil) {
            return YES;
        }
    }
    return NO;
}

- (void)changed:(NSNotification*)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_attached) {
            [self install];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:DuoPadChangedNotification object:nil];
    });
}

- (void)push:(id<DuoPadTarget>)target {
    [self remove:target];
    [_targets compact];
    [_targets addPointer:(__bridge void*)target];
}

- (void)remove:(id<DuoPadTarget>)target {
    for (NSUInteger i = 0; i < _targets.count; i++) {
        if ([_targets pointerAtIndex:i] == (__bridge void*)target) {
            [_targets removePointerAtIndex:i];
            break;
        }
    }
    [_targets compact];
}

- (id<DuoPadTarget>)top {
    [_targets compact];
    for (NSInteger i = (NSInteger)_targets.count - 1; i >= 0; i--) {
        id t = (__bridge id)[_targets pointerAtIndex:i];
        if (t != nil) {
            return t;
        }
    }
    return nil;
}

- (void)attach {
    _attached = YES;
    [self install];
}

- (void)detach {
    _attached = NO;
    [self stopRepeat];
    for (GCController* c in [GCController controllers]) {
        if (c.extendedGamepad != nil) {
            c.extendedGamepad.valueChangedHandler = nil;
        }
    }
    [_last removeAllObjects];
}

- (void)install {
    for (GCController* c in [GCController controllers]) {
        GCExtendedGamepad* g = c.extendedGamepad;
        if (g == nil) {
            continue;
        }
        // The system's own Menu / Options gestures stay off while we navigate.
        if (@available(iOS 14.0, *)) {
            g.buttonMenu.preferredSystemGestureState = GCSystemGestureStateDisabled;
            g.buttonOptions.preferredSystemGestureState = GCSystemGestureStateDisabled;
        }
        __weak DuoPad* weakSelf = self;
        NSValue* key = [NSValue valueWithNonretainedObject:c];
        g.valueChangedHandler = ^(GCExtendedGamepad* pad, GCControllerElement* element) {
            [weakSelf update:pad key:key];
        };
    }
}

static const int B_UP = 1 << 0, B_DOWN = 1 << 1, B_LEFT = 1 << 2, B_RIGHT = 1 << 3, B_A = 1 << 4, B_B = 1 << 5,
                 B_X = 1 << 6, B_Y = 1 << 7, B_LB = 1 << 8, B_RB = 1 << 9, B_START = 1 << 10, B_SELECT = 1 << 11;

- (void)update:(GCExtendedGamepad*)p key:(NSValue*)key {
    int m = 0;
    float lx = p.leftThumbstick.xAxis.value, ly = p.leftThumbstick.yAxis.value;
    if (p.dpad.up.pressed || ly > 0.55) m |= B_UP;
    if (p.dpad.down.pressed || ly < -0.55) m |= B_DOWN;
    if (p.dpad.left.pressed || lx < -0.55) m |= B_LEFT;
    if (p.dpad.right.pressed || lx > 0.55) m |= B_RIGHT;
    if (p.buttonA.pressed) m |= B_A;
    if (p.buttonB.pressed) m |= B_B;
    if (p.buttonX.pressed) m |= B_X;
    if (p.buttonY.pressed) m |= B_Y;
    if (p.leftShoulder.pressed) m |= B_LB;
    if (p.rightShoulder.pressed) m |= B_RB;
    if (p.buttonMenu.pressed) m |= B_START;
    if (@available(iOS 13.0, *)) {
        if (p.buttonOptions.pressed) m |= B_SELECT;
    }
    int last = [_last[key] intValue];
    _last[key] = @(m);
    int pressed = m & ~last;
    int released = last & ~m;
    static const int dirs[] = {B_UP, B_DOWN, B_LEFT, B_RIGHT};
    static const DuoPadKey dirKeys[] = {DuoPadUp, DuoPadDown, DuoPadLeft, DuoPadRight};
    for (int i = 0; i < 4; i++) {
        if (pressed & dirs[i]) {
            [self fire:dirKeys[i]];
            [self startRepeat:dirKeys[i]];
        }
        if ((released & dirs[i]) && _repeat != nil && _repeatKey == dirKeys[i]) {
            [self stopRepeat];
        }
    }
    static const int btns[] = {B_A, B_B, B_X, B_Y, B_LB, B_RB, B_START, B_SELECT};
    static const DuoPadKey btnKeys[] = {DuoPadA, DuoPadB, DuoPadX, DuoPadY, DuoPadLB, DuoPadRB, DuoPadStart, DuoPadSelect};
    for (int i = 0; i < 8; i++) {
        if (pressed & btns[i]) {
            [self fire:btnKeys[i]];
        }
    }
}

- (void)fire:(DuoPadKey)k {
    [[self top] duoPadKey:k];
}

- (void)startRepeat:(DuoPadKey)k {
    [self stopRepeat];
    _repeatKey = k;
    __weak DuoPad* weakSelf = self;
    _repeat = [NSTimer scheduledTimerWithTimeInterval:0.42 repeats:NO block:^(NSTimer* t) {
        DuoPad* s = weakSelf;
        if (s == nil) {
            return;
        }
        s->_repeat = [NSTimer scheduledTimerWithTimeInterval:0.11 repeats:YES block:^(NSTimer* t2) {
            [weakSelf fire:k];
        }];
        [s fire:k];
    }];
}

- (void)stopRepeat {
    [_repeat invalidate];
    _repeat = nil;
}

@end

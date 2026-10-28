//
//  DuoSupport.m
//  Artemide Duo for iOS
//

#import "DuoSupport.h"

@import CoreText;
@import SystemConfiguration;

#include <sys/sysctl.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/in.h>

#pragma mark - Theme

@implementation DuoTheme

+ (UIColor*)hex:(uint32_t)rgb {
    return [self hex:rgb alpha:1.0];
}

+ (UIColor*)hex:(uint32_t)rgb alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:alpha];
}

+ (UIColor*)floor { return [self hex:0x0E0F10]; }
+ (UIColor*)card { return [self hex:0x0F1519]; }
+ (UIColor*)cardHigh { return [self hex:0x161F25]; }
+ (UIColor*)line { return [UIColor colorWithWhite:1.0 alpha:0x14 / 255.0]; }
+ (UIColor*)text { return [self hex:0xF3F7F8]; }
+ (UIColor*)text2 { return [self hex:0x9AA7AE]; }
+ (UIColor*)text3 { return [self hex:0x5B6C75]; }
+ (UIColor*)online { return [self hex:0x4ADE80]; }
+ (UIColor*)offline { return [self hex:0x5B6C75]; }
+ (UIColor*)warn { return [self hex:0xFFB300]; }

+ (NSArray<NSString*>*)accentNames {
    return @[@"Ion (cyan)", @"Duo blue", @"Rose", @"Ember", @"Amber", @"Lemon", @"Lime", @"Signal (green)",
             @"Mint", @"Azure", @"Indigo", @"Ultra", @"Magenta"];
}

+ (NSArray<NSString*>*)accentValues {
    return @[@"#00D3F2", @"#A9C1F0", @"#FF4D6D", @"#FF6A3D", @"#FFB300", @"#FFE14D", @"#A6E22E", @"#00E676",
             @"#2EE6B6", @"#3D9BFF", @"#6E74FF", @"#C060FF", @"#FF4FD8"];
}

+ (UIColor*)accent {
    NSString* v = [DuoPrefs accentHex];
    unsigned int rgb = 0x00D3F2;
    if ([v hasPrefix:@"#"] && v.length == 7) {
        [[NSScanner scannerWithString:[v substringFromIndex:1]] scanHexInt:&rgb];
    }
    return [self hex:rgb];
}

+ (UIColor*)mix:(UIColor*)a with:(UIColor*)b k:(CGFloat)k {
    CGFloat ar, ag, ab, aa, br, bg, bb, ba;
    [a getRed:&ar green:&ag blue:&ab alpha:&aa];
    [b getRed:&br green:&bg blue:&bb alpha:&ba];
    return [UIColor colorWithRed:ar * k + br * (1 - k) green:ag * k + bg * (1 - k) blue:ab * k + bb * (1 - k) alpha:1];
}

+ (UIColor*)focus {
    return [self mix:[UIColor blackColor] with:[self accent] k:0.15];
}

static double DuoLin(CGFloat s) {
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4);
}

+ (UIColor*)onColor:(UIColor*)c {
    CGFloat r, g, b, a;
    [c getRed:&r green:&g blue:&b alpha:&a];
    double l = 0.2126 * DuoLin(r) + 0.7152 * DuoLin(g) + 0.0722 * DuoLin(b);
    return l > 0.35 ? [self hex:0x08120C] : [UIColor whiteColor];
}

+ (CGFloat)scale {
    CGSize s = [UIScreen mainScreen].bounds.size;
    CGFloat w = MAX(s.width, s.height), h = MIN(s.width, s.height);
    CGFloat k = MIN(w / 720.0, h / 540.0);
    return MAX(1.0, MIN(1.5, k));
}

static BOOL sFontsRegistered;

+ (void)registerFonts {
    if (sFontsRegistered) {
        return;
    }
    sFontsRegistered = YES;
    for (NSString* n in @[@"inter_regular", @"inter_medium", @"inter_semibold", @"inter_bold"]) {
        NSURL* url = [[NSBundle mainBundle] URLForResource:n withExtension:@"ttf"];
        if (url != nil) {
            CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
        }
    }
}

+ (UIFont*)font:(NSString*)name size:(CGFloat)size weight:(UIFontWeight)weight {
    [self registerFonts];
    UIFont* f = [UIFont fontWithName:name size:size];
    return f ?: [UIFont systemFontOfSize:size weight:weight];
}

+ (UIFont*)font:(CGFloat)size weight:(UIFontWeight)weight {
    if (weight >= UIFontWeightBold) return [self bold:size];
    if (weight >= UIFontWeightSemibold) return [self semibold:size];
    if (weight >= UIFontWeightMedium) return [self medium:size];
    return [self regular:size];
}

+ (UIFont*)regular:(CGFloat)size { return [self font:@"Inter-Regular" size:size weight:UIFontWeightRegular]; }
+ (UIFont*)medium:(CGFloat)size { return [self font:@"Inter-Medium" size:size weight:UIFontWeightMedium]; }
+ (UIFont*)semibold:(CGFloat)size { return [self font:@"Inter-SemiBold" size:size weight:UIFontWeightSemibold]; }
+ (UIFont*)bold:(CGFloat)size { return [self font:@"Inter-Bold" size:size weight:UIFontWeightBold]; }

+ (UIFont*)digits:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont* base = weight >= UIFontWeightSemibold ? [self semibold:size] : weight >= UIFontWeightMedium ? [self medium:size] : [self regular:size];
    UIFontDescriptor* d = [base.fontDescriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
                                                     UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}]}];
    return [UIFont fontWithDescriptor:d size:size];
}

+ (NSAttributedString*)brand:(BOOL)upper size:(CGFloat)size {
    NSString* s = upper ? @"ARTEMIDE DUO" : @"Artemide Duo";
    NSMutableAttributedString* t = [[NSMutableAttributedString alloc] initWithString:s attributes:@{
        NSFontAttributeName: [self semibold:size], NSForegroundColorAttributeName: [self text],
        NSKernAttributeName: @(upper ? size * 0.18 : 0)}];
    [t addAttribute:NSForegroundColorAttributeName value:[self accent] range:NSMakeRange(9, 3)];
    return t;
}

+ (NSAttributedString*)spaced:(NSString*)text font:(UIFont*)font color:(UIColor*)color em:(CGFloat)em {
    return [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{
        NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSKernAttributeName: @(font.pointSize * em)}];
}

@end

#pragma mark - Preferences

@implementation DuoPrefs

+ (BOOL)boolFor:(NSString*)key fallback:(BOOL)fallback {
    NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
    return [d objectForKey:key] == nil ? fallback : [d boolForKey:key];
}

+ (void)setBool:(BOOL)on forKey:(NSString*)key {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:key];
}

+ (NSInteger)intFor:(NSString*)key fallback:(NSInteger)fallback {
    NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
    return [d objectForKey:key] == nil ? fallback : [d integerForKey:key];
}

+ (void)setInt:(NSInteger)v forKey:(NSString*)key {
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:key];
}

+ (NSString*)stringFor:(NSString*)key fallback:(NSString*)fallback {
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return s ?: fallback;
}

+ (void)setString:(NSString*)v forKey:(NSString*)key {
    [[NSUserDefaults standardUserDefaults] setObject:v forKey:key];
}

+ (NSString*)accentHex { return [self stringFor:@"duo_accent" fallback:@"#00D3F2"]; }
+ (NSInteger)splashSeconds { return MAX(0, MIN(3, [self intFor:@"duo_splash" fallback:2])); }
+ (BOOL)navHaptics { return [self boolFor:@"duo_nav_haptic" fallback:YES]; }

+ (BOOL)virtualDisplay { return [self boolFor:@"duo_virtual_display" fallback:YES]; }
+ (void)setVirtualDisplay:(BOOL)on { [self setBool:on forKey:@"duo_virtual_display"]; }
+ (NSInteger)scaleFactor { return MAX(50, MIN(200, [self intFor:@"duo_scale_factor" fallback:100])); }
+ (NSInteger)videoScaleMode { return [self intFor:@"duo_video_scale" fallback:0]; }
+ (BOOL)autoOrientation { return [self boolFor:@"duo_auto_orientation" fallback:NO]; }
+ (NSInteger)customFps { return [self intFor:@"duo_custom_fps" fallback:0]; }
+ (NSInteger)mobileBitrate { return [self intFor:@"duo_mobile_bitrate" fallback:0]; }

+ (BOOL)touchGestures { return [self boolFor:@"duo_touch_gestures" fallback:YES]; }
+ (NSInteger)trackpadSensX { return [self intFor:@"duo_trackpad_x" fallback:100]; }
+ (NSInteger)trackpadSensY { return [self intFor:@"duo_trackpad_y" fallback:100]; }
+ (BOOL)trackpadSwapAxis { return [self boolFor:@"duo_trackpad_swap" fallback:NO]; }
+ (NSInteger)dragHoldMs { return MAX(150, [self intFor:@"duo_drag_hold" fallback:650]); }
+ (BOOL)rememberZoom { return [self boolFor:@"duo_remember_zoom" fallback:NO]; }

+ (NSInteger)deadzone { return MAX(0, MIN(20, [self intFor:@"duo_deadzone" fallback:5])); }
+ (BOOL)gamepadMouse { return [self boolFor:@"duo_gamepad_mouse" fallback:YES]; }
+ (BOOL)touchpadAsMouse { return [self boolFor:@"duo_touchpad_mouse" fallback:NO]; }
+ (BOOL)motionFallback { return [self boolFor:@"duo_motion_fallback" fallback:NO]; }
+ (BOOL)rumbleFallback { return [self boolFor:@"duo_rumble_fallback" fallback:NO]; }
+ (BOOL)batteryReport { return [self boolFor:@"duo_battery_report" fallback:YES]; }

+ (NSArray<NSString*>*)shortcutActions { return @[@"quit", @"pause", @"perf", @"menu", @"keyboard", @"mouse"]; }

+ (NSString*)shortcutTitle:(NSString*)action {
    NSDictionary* t = @{@"quit": @"Quit session", @"pause": @"Pause session (disconnect)", @"perf": @"Performance overlay",
                        @"menu": @"Stream menu", @"keyboard": @"Keyboard", @"mouse": @"Controller as mouse"};
    return t[action] ?: action;
}

+ (NSString*)shortcutButton:(NSString*)action {
    NSDictionary* d = @{@"quit": @"A", @"pause": @"Y", @"perf": @"X", @"menu": @"B", @"keyboard": @"START", @"mouse": @"SELECT"};
    return [self stringFor:[@"duo_pad_sc_" stringByAppendingString:action] fallback:d[action] ?: @"Off"];
}

+ (NSArray<NSString*>*)shortcutButtons { return @[@"Off", @"A", @"B", @"X", @"Y", @"START", @"SELECT", @"L3", @"R3"]; }

+ (NSString*)overlayStyle { return [self stringFor:@"duo_overlay_style" fallback:@"new"]; }
+ (NSInteger)overlayOpacity { return [self intFor:@"duo_overlay_opacity" fallback:25]; }
+ (BOOL)overlayBottom { return [self intFor:@"duo_overlay_bottom_i" fallback:0] == 1; }
+ (BOOL)overlayHostStats { return [self boolFor:@"duo_overlay_host" fallback:NO]; }

+ (BOOL)resumeWithoutConfirm { return [self boolFor:@"duo_resume_no_confirm" fallback:YES]; }
+ (BOOL)quitDialog { return [self boolFor:@"duo_quit_dialog" fallback:NO]; }
+ (BOOL)floatingButton { return [self boolFor:@"duo_floating_button" fallback:YES]; }
+ (BOOL)pictureInPicture { return [self boolFor:@"duo_pip" fallback:NO]; }
+ (BOOL)postStreamToast { return [self boolFor:@"duo_post_toast" fallback:YES]; }
+ (BOOL)disableWarnings { return [self boolFor:@"duo_disable_warnings" fallback:NO]; }

+ (BOOL)clipboardSync { return [self boolFor:@"duo_clipboard_sync" fallback:YES]; }
+ (void)setClipboardSync:(BOOL)on { [self setBool:on forKey:@"duo_clipboard_sync"]; }
+ (BOOL)clipboardToast { return [self boolFor:@"duo_clipboard_toast" fallback:YES]; }
+ (BOOL)hideClipboardContent { return [self boolFor:@"duo_clipboard_hide" fallback:YES]; }

+ (NSString*)deviceModel {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size == 0) {
        return @"";
    }
    char* machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString* model = [NSString stringWithUTF8String:machine];
    free(machine);
    return model ?: @"";
}

+ (BOOL)isIPadPro11FirstGen {
    NSString* m = [self deviceModel];
    return [m isEqualToString:@"iPad8,1"] || [m isEqualToString:@"iPad8,2"]
        || [m isEqualToString:@"iPad8,3"] || [m isEqualToString:@"iPad8,4"];
}

+ (BOOL)isTailscaleAddress:(NSString*)address {
    if (address == nil) {
        return NO;
    }
    NSString* a = [[address lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[] "]];
    if ([a hasPrefix:@"fd7a:115c:a1e0:"]) {
        return YES;
    }
    NSRange colon = [a rangeOfString:@":"];
    if (colon.location != NSNotFound && [[a componentsSeparatedByString:@":"] count] == 2) {
        a = [a substringToIndex:colon.location];
    }
    NSArray* parts = [a componentsSeparatedByString:@"."];
    if (parts.count != 4) {
        return NO;
    }
    int o1 = [parts[0] intValue], o2 = [parts[1] intValue];
    return o1 == 100 && o2 >= 64 && o2 <= 127;
}

+ (NSString*)tailscaleAddress {
    struct ifaddrs* list = NULL;
    if (getifaddrs(&list) != 0) {
        return nil;
    }
    NSString* found = nil;
    for (struct ifaddrs* i = list; i != NULL; i = i->ifa_next) {
        if (i->ifa_addr == NULL || i->ifa_addr->sa_family != AF_INET || !(i->ifa_flags & IFF_UP)) {
            continue;
        }
        char buf[INET_ADDRSTRLEN];
        struct sockaddr_in* sin = (struct sockaddr_in*)i->ifa_addr;
        if (inet_ntop(AF_INET, &sin->sin_addr, buf, sizeof(buf)) == NULL) {
            continue;
        }
        NSString* addr = [NSString stringWithUTF8String:buf];
        if ([self isTailscaleAddress:addr]) {
            found = addr;
            break;
        }
    }
    freeifaddrs(list);
    return found;
}

+ (BOOL)onCellular {
    struct sockaddr_in zero;
    memset(&zero, 0, sizeof(zero));
    zero.sin_len = sizeof(zero);
    zero.sin_family = AF_INET;
    SCNetworkReachabilityRef r = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zero);
    if (r == NULL) {
        return NO;
    }
    SCNetworkReachabilityFlags flags = 0;
    BOOL ok = SCNetworkReachabilityGetFlags(r, &flags);
    CFRelease(r);
    return ok && (flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsWWAN);
}

+ (BOOL)isAppName:(NSString*)name {
    if (name == nil) {
        return NO;
    }
    NSString* n = [name lowercaseString];
    NSArray* words = @[@"desktop", @"virtual display", @"remote", @"reboot", @"restart", @"shutdown", @"shut down",
                       @"power off", @"hibernate", @"log off", @"logoff", @"sign out", @"lock screen", @"big picture",
                       @"playnite", @"launcher", @"explorer", @"browser", @"chrome", @"firefox", @"spotify", @"youtube",
                       @"netflix", @"plex", @"kodi", @"vlc", @"terminal", @"powershell", @"task manager", @"discord",
                       @"terminate", @"resume"];
    for (NSString* w in words) {
        if ([n containsString:w]) {
            return YES;
        }
    }
    return NO;
}

+ (CGSize)videoSizeIn:(CGSize)b aspect:(CGFloat)aspect {
    if (aspect <= 0 || b.width <= 0 || b.height <= 0) {
        return b;
    }
    switch ([self videoScaleMode]) {
        case 2: // stretch
            return b;
        case 1: // fill: cover the screen, crop the rest
            if (b.width / b.height > aspect) {
                return CGSizeMake(b.width, b.width / aspect);
            }
            return CGSizeMake(b.height * aspect, b.height);
        default: // fit
            if (b.width > b.height * aspect) {
                return CGSizeMake(b.height * aspect, b.height);
            }
            return CGSizeMake(b.width, b.width / aspect);
    }
}

@end

#pragma mark - Play stats

@implementation DuoLastPlayed
@end

static NSString* sRunHost;
static NSString* sRunApp;
static CFTimeInterval sRunStart;

@implementation DuoPlayStats

+ (NSUserDefaults*)store {
    static NSUserDefaults* s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[NSUserDefaults alloc] initWithSuiteName:@"duo_play_stats"];
    });
    return s;
}

+ (void)startedOnHost:(NSString*)hostUuid app:(NSString*)appId name:(NSString*)name {
    if (hostUuid == nil || appId == nil) {
        return;
    }
    [self ended];
    sRunHost = hostUuid;
    sRunApp = appId;
    sRunStart = CACurrentMediaTime();
    NSUserDefaults* s = [self store];
    NSString* p = [hostUuid stringByAppendingString:@"|"];
    NSString* a = [NSString stringWithFormat:@"%@%@|", p, appId];
    [s setObject:appId forKey:[p stringByAppendingString:@"last.id"]];
    [s setObject:name ?: @"" forKey:[p stringByAppendingString:@"last.name"]];
    [s setDouble:[NSDate date].timeIntervalSince1970 forKey:[p stringByAppendingString:@"last.when"]];
    [s setInteger:[s integerForKey:[a stringByAppendingString:@"sessions"]] + 1 forKey:[a stringByAppendingString:@"sessions"]];
}

+ (NSTimeInterval)ended {
    if (sRunHost == nil) {
        return 0;
    }
    NSTimeInterval t = MAX(0, CACurrentMediaTime() - sRunStart);
    NSUserDefaults* s = [self store];
    NSString* a = [NSString stringWithFormat:@"%@|%@|time", sRunHost, sRunApp];
    [s setDouble:[s doubleForKey:a] + t forKey:a];
    [s setDouble:[NSDate date].timeIntervalSince1970 forKey:[sRunHost stringByAppendingString:@"|last.when"]];
    sRunHost = nil;
    sRunApp = nil;
    return t;
}

+ (DuoLastPlayed*)lastForHost:(NSString*)hostUuid {
    if (hostUuid == nil) {
        return nil;
    }
    NSUserDefaults* s = [self store];
    NSString* p = [hostUuid stringByAppendingString:@"|"];
    NSString* appId = [s stringForKey:[p stringByAppendingString:@"last.id"]];
    if (appId == nil) {
        return nil;
    }
    DuoLastPlayed* l = [[DuoLastPlayed alloc] init];
    l.appId = appId;
    l.name = [s stringForKey:[p stringByAppendingString:@"last.name"]] ?: @"";
    l.when = [s doubleForKey:[p stringByAppendingString:@"last.when"]];
    l.total = [self timeForHost:hostUuid app:appId];
    l.sessions = [self sessionsForHost:hostUuid app:appId];
    return l;
}

+ (NSTimeInterval)timeForHost:(NSString*)hostUuid app:(NSString*)appId {
    return [[self store] doubleForKey:[NSString stringWithFormat:@"%@|%@|time", hostUuid, appId]];
}

+ (NSInteger)sessionsForHost:(NSString*)hostUuid app:(NSString*)appId {
    return [[self store] integerForKey:[NSString stringWithFormat:@"%@|%@|sessions", hostUuid, appId]];
}

+ (BOOL)isPinnedHost:(NSString*)hostUuid app:(NSString*)appId {
    return [[self store] boolForKey:[NSString stringWithFormat:@"%@|%@|pinned", hostUuid, appId]];
}

+ (void)setPinned:(BOOL)pinned host:(NSString*)hostUuid app:(NSString*)appId {
    [[self store] setBool:pinned forKey:[NSString stringWithFormat:@"%@|%@|pinned", hostUuid, appId]];
}

+ (NSString*)duration:(NSTimeInterval)seconds {
    long m = (long)(seconds / 60);
    if (m < 1) {
        return @"< 1 m";
    }
    return m >= 60 ? [NSString stringWithFormat:@"%ld h %ld m", m / 60, m % 60] : [NSString stringWithFormat:@"%ld m", m];
}

+ (NSString*)ago:(NSTimeInterval)when {
    long d = (long)(MAX(0, [NSDate date].timeIntervalSince1970 - when) / 60);
    if (d < 1) {
        return @"just now";
    }
    if (d < 60) {
        return [NSString stringWithFormat:@"%ld min ago", d];
    }
    if (d < 48 * 60) {
        return [NSString stringWithFormat:@"%ld h ago", d / 60];
    }
    return [NSString stringWithFormat:@"%ld d ago", d / 1440];
}

@end

#pragma mark - Motion

@implementation DuoMotion

+ (void)curve:(CGPoint)c1 :(CGPoint)c2 duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay animations:(void (^)(void))animations completion:(void (^)(void))completion {
    UICubicTimingParameters* t = [[UICubicTimingParameters alloc] initWithControlPoint1:c1 controlPoint2:c2];
    UIViewPropertyAnimator* a = [[UIViewPropertyAnimator alloc] initWithDuration:duration timingParameters:t];
    [a addAnimations:animations];
    if (completion != nil) {
        [a addCompletion:^(UIViewAnimatingPosition p) {
            completion();
        }];
    }
    a.interruptible = YES;
    a.userInteractionEnabled = YES;
    [a startAnimationAfterDelay:delay];
}

+ (void)ease:(NSTimeInterval)duration delay:(NSTimeInterval)delay animations:(void (^)(void))animations completion:(void (^)(void))completion {
    [self curve:CGPointMake(0.32, 0.72) :CGPointMake(0, 1) duration:duration delay:delay animations:animations completion:completion];
}

+ (void)spring:(NSTimeInterval)duration animations:(void (^)(void))animations {
    [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:animations completion:nil];
}

+ (void)slideIn:(UIView*)v dir:(NSInteger)dir distance:(CGFloat)distance {
    if (v == nil) {
        return;
    }
    [v.layer removeAllAnimations];
    v.alpha = 0;
    v.transform = CGAffineTransformMakeTranslation(dir * distance, 0);
    [self ease:0.32 delay:0 animations:^{
        v.alpha = 1;
        v.transform = CGAffineTransformIdentity;
    } completion:nil];
}

+ (void)fadeIn:(UIView*)v duration:(NSTimeInterval)duration {
    if (v == nil) {
        return;
    }
    v.alpha = 0;
    [self ease:duration delay:0 animations:^{
        v.alpha = 1;
    } completion:nil];
}

+ (void)stagger:(NSArray<UIView*>*)views {
    NSInteger i = 0;
    CGFloat d = [DuoTheme scale];
    for (UIView* c in views) {
        if (i >= 14) {
            break;
        }
        c.alpha = 0;
        c.transform = CGAffineTransformMakeTranslation(0, 12 * d);
        [self ease:0.30 delay:i * 0.028 animations:^{
            c.alpha = 1;
            c.transform = CGAffineTransformIdentity;
        } completion:nil];
        i++;
    }
}

+ (void)tap:(UIView*)v {
    if (v == nil) {
        return;
    }
    CGFloat s = ([v isKindOfClass:[DuoButton class]] && ((DuoButton*)v).duoFocused) ? 1.04 : 1.0;
    [self ease:0.08 delay:0 animations:^{
        v.transform = CGAffineTransformMakeScale(s * 0.94, s * 0.94);
    } completion:^{
        [self spring:0.3 animations:^{
            v.transform = CGAffineTransformMakeScale(s, s);
        }];
    }];
}

+ (void)countUp:(UILabel*)label to:(NSInteger)to {
    if (to <= 0) {
        label.text = [NSString stringWithFormat:@"%ld", (long)MAX(0, to)];
        return;
    }
    CFTimeInterval start = CACurrentMediaTime();
    NSTimeInterval dur = MIN(0.7, 0.2 + to * 0.04);
    __weak UILabel* weakLabel = label;
    [NSTimer scheduledTimerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer* t) {
        UILabel* l = weakLabel;
        CGFloat k = MIN(1, (CACurrentMediaTime() - start) / dur);
        CGFloat e = 1 - pow(1 - k, 3);
        if (l == nil) {
            [t invalidate];
            return;
        }
        l.text = [NSString stringWithFormat:@"%ld", (long)lround(e * to)];
        if (k >= 1) {
            [t invalidate];
        }
    }];
}

+ (void)pulse:(UIView*)v {
    CABasicAnimation* a = [CABasicAnimation animationWithKeyPath:@"opacity"];
    a.fromValue = @1;
    a.toValue = @0.45;
    a.duration = 0.9;
    a.autoreverses = YES;
    a.repeatCount = HUGE_VALF;
    [v.layer addAnimation:a forKey:@"duoPulse"];
}

+ (void)navTick {
    if ([DuoPrefs navHaptics]) {
        static UISelectionFeedbackGenerator* g;
        if (g == nil) {
            g = [[UISelectionFeedbackGenerator alloc] init];
        }
        [g selectionChanged];
    }
}

@end

#pragma mark - Glyph

@implementation DuoGlyphView {
    CAGradientLayer* _halo;
    CAGradientLayer* _body;
    UILabel* _letter;
}

+ (UIColor*)colorFor:(NSString*)l {
    if ([l isEqualToString:@"A"]) return [DuoTheme hex:0x6FCF7F];
    if ([l isEqualToString:@"B"]) return [DuoTheme hex:0xE0645A];
    if ([l isEqualToString:@"X"]) return [DuoTheme hex:0x5A9BE0];
    if ([l isEqualToString:@"≡"] || [l isEqualToString:@"⧉"]) return [DuoTheme hex:0x3A434A];
    return [DuoTheme hex:0xE8C15A];
}

- (instancetype)initWithLetter:(NSString*)letter {
    CGFloat d = [DuoTheme scale];
    self = [super initWithFrame:CGRectMake(0, 0, 23 * d, 23 * d)];
    if (self) {
        self.userInteractionEnabled = NO;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        UIColor* c = [DuoGlyphView colorFor:letter];
        _halo = [CAGradientLayer layer];
        _halo.type = kCAGradientLayerRadial;
        _halo.colors = @[(id)[c colorWithAlphaComponent:0.55].CGColor, (id)[c colorWithAlphaComponent:0].CGColor];
        _halo.startPoint = CGPointMake(0.5, 0.5);
        _halo.endPoint = CGPointMake(1, 1);
        [self.layer addSublayer:_halo];
        _body = [CAGradientLayer layer];
        _body.colors = @[(id)[DuoTheme mix:[UIColor whiteColor] with:c k:0.35].CGColor, (id)c.CGColor,
                         (id)[DuoTheme mix:[UIColor blackColor] with:c k:0.15].CGColor];
        _body.borderWidth = 0.8;
        _body.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
        [self.layer addSublayer:_body];
        _letter = [[UILabel alloc] init];
        BOOL symbol = [letter isEqualToString:@"≡"] || [letter isEqualToString:@"⧉"];
        _letter.text = letter;
        _letter.font = [DuoTheme bold:(symbol ? 7.5 : 10.5) * d];
        _letter.textColor = symbol ? [UIColor whiteColor] : [DuoTheme hex:0x0B0C0E];
        _letter.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_letter];
        [NSLayoutConstraint activateConstraints:@[
            [self.widthAnchor constraintEqualToConstant:23 * d],
            [self.heightAnchor constraintEqualToConstant:23 * d],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    CGFloat in = 3 * [DuoTheme scale];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _halo.frame = b;
    _halo.cornerRadius = b.size.width / 2;
    _body.frame = CGRectInset(b, in, in);
    _body.cornerRadius = _body.frame.size.width / 2;
    [CATransaction commit];
    _letter.frame = CGRectInset(b, in, in);
}

@end

#pragma mark - Logo

@implementation DuoLogoView {
    CAShapeLayer* _screen;
    CAShapeLayer* _play;
    CGFloat _size;
}

- (instancetype)initWithSize:(CGFloat)size {
    self = [super initWithFrame:CGRectMake(0, 0, size, size)];
    if (self) {
        _size = size;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = NO;
        self.backgroundColor = [DuoTheme card];
        self.layer.cornerRadius = size * 0.225;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [DuoTheme line].CGColor;
        UIColor* accent = [DuoTheme accent];
        _screen = [CAShapeLayer layer];
        _screen.fillColor = [UIColor clearColor].CGColor;
        _screen.strokeColor = accent.CGColor;
        _screen.lineCap = kCALineCapRound;
        _screen.lineJoin = kCALineJoinRound;
        _play = [CAShapeLayer layer];
        _play.fillColor = accent.CGColor;
        _play.strokeColor = accent.CGColor;
        _play.lineJoin = kCALineJoinRound;
        [self.layer addSublayer:_screen];
        [self.layer addSublayer:_play];
        [NSLayoutConstraint activateConstraints:@[
            [self.widthAnchor constraintEqualToConstant:size],
            [self.heightAnchor constraintEqualToConstant:size],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Glyph on a 24 x 24 grid with 20 % padding (Android ic_duo_logo).
    CGFloat pad = _size * 0.2, k = (_size - 2 * pad) / 24.0;
    CGAffineTransform t = CGAffineTransformMake(k, 0, 0, k, pad, pad);
    UIBezierPath* s = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 4.5, 18, 12.5) cornerRadius:3];
    [s moveToPoint:CGPointMake(9, 20.5)];
    [s addLineToPoint:CGPointMake(15, 20.5)];
    [s applyTransform:t];
    _screen.path = s.CGPath;
    _screen.lineWidth = 1.9 * k;
    UIBezierPath* p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(10.35, 8.75)];
    [p addLineToPoint:CGPointMake(13.65, 10.75)];
    [p addLineToPoint:CGPointMake(10.35, 12.75)];
    [p closePath];
    [p applyTransform:t];
    _play.path = p.CGPath;
    _play.lineWidth = 1.0 * k;
}

@end

#pragma mark - Button

@implementation DuoButton {
    BOOL _primary;
    UIStackView* _row;
    DuoGlyphView* _aGlyph;
    DuoGlyphView* _glyph;
    BOOL _pad;
}

- (instancetype)initWithTitle:(NSString*)title glyph:(NSString*)glyph primary:(BOOL)primary {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        CGFloat d = [DuoTheme scale];
        _primary = primary;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 10 * d;
        _row = [[UIStackView alloc] init];
        _row.axis = UILayoutConstraintAxisHorizontal;
        _row.alignment = UIStackViewAlignmentCenter;
        _row.spacing = 5 * d;
        _row.userInteractionEnabled = NO;
        _row.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_row];
        BOOL follow = glyph == nil || [glyph isEqualToString:@"A"] || [glyph isEqualToString:@"X"]
            || [glyph isEqualToString:@"≡"] || [glyph isEqualToString:@"⧉"];
        if (follow) {
            _aGlyph = [[DuoGlyphView alloc] initWithLetter:@"A"];
            _aGlyph.hidden = YES;
            [_row addArrangedSubview:_aGlyph];
        }
        if (glyph != nil && ![glyph isEqualToString:@"A"]) {
            _glyph = [[DuoGlyphView alloc] initWithLetter:glyph];
            _glyph.hidden = YES;
            [_row addArrangedSubview:_glyph];
        }
        _label = [[UILabel alloc] init];
        _label.text = title;
        _label.font = primary ? [DuoTheme semibold:14 * d] : [DuoTheme regular:13 * d];
        _label.textColor = primary ? [DuoTheme onColor:[DuoTheme focus]] : [DuoTheme text];
        [_row addArrangedSubview:_label];
        CGFloat side = (primary ? 18 : 16) * d;
        [NSLayoutConstraint activateConstraints:@[
            [_row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:side],
            [_row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-side],
            [_row.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
        [self addTarget:self action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside];
        [self applyLook:NO];
    }
    return self;
}

- (void)setTitle:(NSString*)title {
    _label.text = title;
}

- (void)applyLook:(BOOL)pressed {
    CGFloat d = [DuoTheme scale];
    UIColor* bg = _primary ? [DuoTheme focus] : [UIColor colorWithWhite:1 alpha:0x17 / 255.0];
    if (pressed) {
        bg = _primary ? [DuoTheme mix:[UIColor whiteColor] with:[DuoTheme focus] k:0.08] : [UIColor colorWithWhite:1 alpha:0.14];
    }
    self.backgroundColor = bg;
    if (_duoFocused) {
        self.layer.borderWidth = 2 * d;
        self.layer.borderColor = (_primary ? [DuoTheme text] : [DuoTheme focus]).CGColor;
    } else {
        self.layer.borderWidth = _primary ? 0 : 1;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0x29 / 255.0].CGColor;
    }
}

- (void)setDuoFocused:(BOOL)duoFocused {
    if (_duoFocused == duoFocused) {
        return;
    }
    _duoFocused = duoFocused;
    [UIView transitionWithView:self duration:0.14 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self applyLook:NO];
    } completion:nil];
    if (duoFocused) {
        [DuoMotion spring:0.3 animations:^{
            self.transform = CGAffineTransformMakeScale(1.04, 1.04);
        }];
    } else {
        [DuoMotion ease:0.2 delay:0 animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
    [self updateGlyphs:_pad];
}

- (void)updateGlyphs:(BOOL)pad {
    _pad = pad;
    if (_aGlyph != nil) {
        _aGlyph.hidden = !(pad && _duoFocused);
        _glyph.hidden = !(pad && !_duoFocused);
    } else {
        _glyph.hidden = !pad;
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self applyLook:highlighted];
    if (highlighted) {
        [DuoMotion ease:0.09 delay:0 animations:^{
            self.transform = CGAffineTransformMakeScale(0.96, 0.96);
        } completion:nil];
    } else {
        CGFloat s = self->_duoFocused ? 1.04 : 1.0;
        [DuoMotion spring:0.3 animations:^{
            self.transform = CGAffineTransformMakeScale(s, s);
        }];
    }
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alpha = enabled ? 1 : 0.45;
}

- (void)touchUp {
    if (self.onTap != nil) {
        self.onTap();
    }
}

- (void)fire {
    if (!self.enabled || self.hidden) {
        return;
    }
    [DuoMotion tap:self];
    [self touchUp];
}

@end

#pragma mark - Small views

UILabel* DuoText(NSString* text, CGFloat size, UIColor* color, BOOL bold) {
    UILabel* l = [[UILabel alloc] init];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = text;
    CGFloat d = [DuoTheme scale];
    l.font = bold ? [DuoTheme semibold:size * d] : [DuoTheme regular:size * d];
    l.textColor = color;
    return l;
}

UILabel* DuoKeyPill(NSString* text) {
    CGFloat d = [DuoTheme scale];
    UILabel* t = DuoText(text, 9, [DuoTheme text], YES);
    t.textAlignment = NSTextAlignmentCenter;
    t.backgroundColor = [DuoTheme cardHigh];
    t.layer.cornerRadius = 5 * d;
    t.layer.borderWidth = 1;
    t.layer.borderColor = [DuoTheme line].CGColor;
    t.clipsToBounds = YES;
    [NSLayoutConstraint activateConstraints:@[
        [t.widthAnchor constraintGreaterThanOrEqualToConstant:26 * d],
        [t.heightAnchor constraintEqualToConstant:18 * d],
    ]];
    return t;
}

@interface DuoPaddedLabel : UILabel
@property (nonatomic) UIEdgeInsets insets;
@end

@implementation DuoPaddedLabel
- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.insets)];
}
- (CGSize)intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    return CGSizeMake(s.width + self.insets.left + self.insets.right, s.height + self.insets.top + self.insets.bottom);
}
@end

UILabel* DuoInfoChip(NSString* text) {
    CGFloat d = [DuoTheme scale];
    DuoPaddedLabel* t = [[DuoPaddedLabel alloc] init];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.insets = UIEdgeInsetsMake(4 * d, 8 * d, 4 * d, 8 * d);
    t.text = text;
    t.font = [DuoTheme semibold:10.5 * d];
    t.textColor = [DuoTheme text];
    t.backgroundColor = [DuoTheme card];
    t.layer.cornerRadius = 6 * d;
    t.layer.borderWidth = 1;
    t.layer.borderColor = [DuoTheme line].CGColor;
    t.clipsToBounds = YES;
    return t;
}

UIView* DuoBadge(NSString* text, UIColor* dotColor, UILabel** labelOut, UIView** dotOut) {
    CGFloat d = [DuoTheme scale];
    UIView* box = [[UIView alloc] init];
    box.translatesAutoresizingMaskIntoConstraints = NO;
    box.layer.cornerRadius = 6 * d;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [DuoTheme line].CGColor;
    UIView* dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = dotColor;
    dot.layer.cornerRadius = 3 * d;
    [box addSubview:dot];
    UILabel* l = DuoText(@"", 10.5, [DuoTheme text], YES);
    l.attributedText = [DuoTheme spaced:text font:[DuoTheme semibold:10.5 * d] color:[DuoTheme text] em:0.1];
    [box addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:6 * d],
        [dot.heightAnchor constraintEqualToConstant:6 * d],
        [dot.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:9 * d],
        [dot.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
        [l.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:6 * d],
        [l.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-9 * d],
        [l.topAnchor constraintEqualToAnchor:box.topAnchor constant:4 * d],
        [l.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-4 * d],
    ]];
    if (labelOut != NULL) {
        *labelOut = l;
    }
    if (dotOut != NULL) {
        *dotOut = dot;
    }
    return box;
}

CAGradientLayer* DuoPlaceholderLayer(void) {
    CAGradientLayer* g = [CAGradientLayer layer];
    g.colors = @[(id)[DuoTheme mix:[DuoTheme accent] with:[DuoTheme cardHigh] k:0.22].CGColor, (id)[DuoTheme card].CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    return g;
}

void DuoToast(UIView* inView, NSString* text) {
    if (inView == nil || text.length == 0) {
        return;
    }
    CGFloat d = [DuoTheme scale];
    DuoPaddedLabel* t = [[DuoPaddedLabel alloc] init];
    t.insets = UIEdgeInsetsMake(10 * d, 16 * d, 10 * d, 16 * d);
    t.text = text;
    t.numberOfLines = 2;
    t.textAlignment = NSTextAlignmentCenter;
    t.font = [DuoTheme medium:12.5 * d];
    t.textColor = [DuoTheme text];
    t.backgroundColor = [[DuoTheme cardHigh] colorWithAlphaComponent:0.94];
    t.layer.cornerRadius = 12 * d;
    t.layer.borderWidth = 1;
    t.layer.borderColor = [DuoTheme line].CGColor;
    t.clipsToBounds = YES;
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.userInteractionEnabled = NO;
    [inView addSubview:t];
    [NSLayoutConstraint activateConstraints:@[
        [t.centerXAnchor constraintEqualToAnchor:inView.centerXAnchor],
        [t.bottomAnchor constraintEqualToAnchor:inView.safeAreaLayoutGuide.bottomAnchor constant:-28 * d],
        [t.widthAnchor constraintLessThanOrEqualToAnchor:inView.widthAnchor multiplier:0.8],
    ]];
    t.alpha = 0;
    t.transform = CGAffineTransformMakeTranslation(0, 10 * d);
    [DuoMotion ease:0.32 delay:0 animations:^{
        t.alpha = 1;
        t.transform = CGAffineTransformIdentity;
    } completion:^{
        [DuoMotion ease:0.4 delay:2.4 animations:^{
            t.alpha = 0;
        } completion:^{
            [t removeFromSuperview];
        }];
    }];
}

UIImage* DuoMonitorIcon(CGFloat size, UIColor* color) {
    UIGraphicsImageRenderer* r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext* ctx) {
        CGFloat k = size / 24.0;
        UIBezierPath* p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3 * k, 4 * k, 18 * k, 12 * k) cornerRadius:2 * k];
        [p moveToPoint:CGPointMake(8 * k, 20 * k)];
        [p addLineToPoint:CGPointMake(16 * k, 20 * k)];
        [p moveToPoint:CGPointMake(12 * k, 16 * k)];
        [p addLineToPoint:CGPointMake(12 * k, 20 * k)];
        p.lineWidth = 1.3 * k;
        p.lineCapStyle = kCGLineCapRound;
        p.lineJoinStyle = kCGLineJoinRound;
        [color setStroke];
        [p stroke];
    }];
}

//
//  DuoSupport.h
//  Artemide Duo for iOS
//
//  Shared pieces of the Artemide Duo screens, ported from Artemide Duo for Android
//  (com.limelight.duo.DuoTheme / DuoFonts / DuoMotion / DuoPlayStats and the settings).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Theme

@interface DuoTheme : NSObject
+ (UIColor*)hex:(uint32_t)rgb;
+ (UIColor*)hex:(uint32_t)rgb alpha:(CGFloat)alpha;
+ (UIColor*)floor;      // 0E0F10
+ (UIColor*)card;       // 0F1519
+ (UIColor*)cardHigh;   // 161F25
+ (UIColor*)line;       // white 8 %
+ (UIColor*)text;
+ (UIColor*)text2;
+ (UIColor*)text3;
+ (UIColor*)online;
+ (UIColor*)offline;
+ (UIColor*)warn;
/// The user's accent (Settings → Duo → Accent color), StreamLight's "Ion" by default.
+ (UIColor*)accent;
/// Accent a bit darker so it doesn't glare (focus rings, primary buttons).
+ (UIColor*)focus;
/// a over b, k = share of a.
+ (UIColor*)mix:(UIColor*)a with:(UIColor*)b k:(CGFloat)k;
/// Dark or white text on a colour, whichever reads better.
+ (UIColor*)onColor:(UIColor*)c;
/// UI scale for big screens (1 on phones, up to 1.5 on the iPad).
+ (CGFloat)scale;
/// System font (SF Pro).
+ (UIFont*)font:(CGFloat)size weight:(UIFontWeight)weight;
+ (UIFont*)regular:(CGFloat)size;
+ (UIFont*)medium:(CGFloat)size;
+ (UIFont*)semibold:(CGFloat)size;
+ (UIFont*)bold:(CGFloat)size;
/// Monospaced digits (clock, numbers).
+ (UIFont*)digits:(CGFloat)size weight:(UIFontWeight)weight;
/// (No-op: the app uses the system font, SF Pro.)
+ (void)registerFonts;
/// "ARTEMIDE DUO" / "Artemide Duo" with DUO in the accent.
+ (NSAttributedString*)brand:(BOOL)upper size:(CGFloat)size;
/// Text with letter spacing (em, like Android's setLetterSpacing).
+ (NSAttributedString*)spaced:(NSString*)text font:(UIFont*)font color:(UIColor*)color em:(CGFloat)em;
+ (NSArray<NSString*>*)accentNames;
+ (NSArray<NSString*>*)accentValues;
@end

#pragma mark - Preferences

@interface DuoPrefs : NSObject
+ (BOOL)boolFor:(NSString*)key fallback:(BOOL)fallback;
+ (void)setBool:(BOOL)on forKey:(NSString*)key;
+ (NSInteger)intFor:(NSString*)key fallback:(NSInteger)fallback;
+ (void)setInt:(NSInteger)v forKey:(NSString*)key;
+ (NSString*)stringFor:(NSString*)key fallback:(NSString*)fallback;
+ (void)setString:(NSString*)v forKey:(NSString*)key;

// Duo
+ (NSString*)accentHex;               // "#00D3F2"
+ (NSInteger)splashSeconds;           // 0..3, default 2
+ (BOOL)navHaptics;                   // tick when the controller moves focus
// Video
+ (BOOL)virtualDisplay;
+ (void)setVirtualDisplay:(BOOL)on;
+ (NSInteger)scaleFactor;             // Apollo resolution scale, 50..200 %
+ (NSInteger)videoScaleMode;          // 0 fit, 1 fill, 2 stretch
+ (BOOL)autoOrientation;              // stream in portrait when the device is held upright
+ (NSInteger)customFps;               // 0 = use the FPS setting
+ (NSInteger)mobileBitrate;           // kbps on cellular, 0 = same as Wi-Fi
// Input
+ (BOOL)touchGestures;                // 2 fingers right click / scroll, 3 fingers drag
+ (NSInteger)trackpadSensX;           // %
+ (NSInteger)trackpadSensY;
+ (BOOL)trackpadSwapAxis;
+ (NSInteger)dragHoldMs;              // hold to start a drag
+ (BOOL)rememberZoom;
// Mouse / trackpad (Magic Keyboard)
+ (BOOL)localCursor;                  // smooth iPad-drawn cursor in desktop apps (games: raw mouse)
+ (NSInteger)mouseSpeed;              // %
+ (BOOL)naturalScroll;
// Upscaling
+ (BOOL)metalFX;
+ (BOOL)metalFXSupported;
// Controller
+ (NSInteger)deadzone;                // % of the stick range
+ (BOOL)gamepadMouse;                 // LB+RB+shortcut toggles stick-as-mouse
+ (BOOL)touchpadAsMouse;              // DualSense touchpad moves the mouse
+ (BOOL)motionFallback;               // device gyro when the controller has none
+ (BOOL)rumbleFallback;               // iPhone vibration when the controller can't rumble
+ (BOOL)batteryReport;
// Shortcuts (LB + RB + button)
+ (NSArray<NSString*>*)shortcutActions;   // quit, pause, perf, menu, keyboard, mouse
+ (NSString*)shortcutTitle:(NSString*)action;
+ (NSString*)shortcutButton:(NSString*)action;
+ (NSArray<NSString*>*)shortcutButtons;   // Off, A, B, X, Y, START, SELECT, L3, R3
// Overlay
+ (NSString*)overlayStyle;            // new, detailed, classic
+ (NSInteger)overlayOpacity;          // 25..70
+ (BOOL)overlayBottom;
+ (BOOL)overlayHostStats;
// Interface
+ (BOOL)resumeWithoutConfirm;
+ (BOOL)quitDialog;
+ (BOOL)floatingButton;
+ (BOOL)pictureInPicture;
+ (BOOL)postStreamToast;
+ (BOOL)disableWarnings;
// General
+ (BOOL)clipboardSync;
+ (void)setClipboardSync:(BOOL)on;
+ (BOOL)clipboardToast;
+ (BOOL)hideClipboardContent;

/// Hardware model, e.g. "iPad8,1".
+ (NSString*)deviceModel;
/// iPad Pro 11" (1st generation, 2018): 2388 x 1668, 120 Hz.
+ (BOOL)isIPadPro11FirstGen;
/// This device's Tailscale IPv4 address, or nil when Tailscale isn't connected.
+ (nullable NSString*)tailscaleAddress;
+ (BOOL)isTailscaleAddress:(nullable NSString*)address;
/// On a cellular connection (no Wi-Fi / Ethernet route).
+ (BOOL)onCellular;
/// Tools and apps (Desktop, Remote Monitor, Steam Big Picture ...) as opposed to games.
+ (BOOL)isAppName:(nullable NSString*)name;
/// Size of the video inside `bounds` for the chosen scale mode (same for drawing and touch).
+ (CGSize)videoSizeIn:(CGSize)bounds aspect:(CGFloat)aspect;
@end

#pragma mark - Scroll view that scrolls even when the drag starts on a row / button

@interface DuoScrollView : UIScrollView
@end

#pragma mark - Play stats (last played, time, sessions, favourites)

@interface DuoLastPlayed : NSObject
@property (nonatomic, copy) NSString* appId;
@property (nonatomic, copy) NSString* name;
@property (nonatomic) NSTimeInterval when;
@property (nonatomic) NSTimeInterval total;
@property (nonatomic) NSInteger sessions;
@end

@interface DuoPlayStats : NSObject
+ (void)startedOnHost:(NSString*)hostUuid app:(NSString*)appId name:(NSString*)name;
/// Returns the length of the session that just ended (0 if none).
+ (NSTimeInterval)ended;
+ (nullable DuoLastPlayed*)lastForHost:(NSString*)hostUuid;
+ (NSTimeInterval)timeForHost:(NSString*)hostUuid app:(NSString*)appId;
+ (NSInteger)sessionsForHost:(NSString*)hostUuid app:(NSString*)appId;
+ (BOOL)isPinnedHost:(NSString*)hostUuid app:(NSString*)appId;
+ (void)setPinned:(BOOL)pinned host:(NSString*)hostUuid app:(NSString*)appId;
/// "1 h 11 m", "54 m", "< 1 m".
+ (NSString*)duration:(NSTimeInterval)seconds;
/// "14 h ago", "3 d ago", "just now".
+ (NSString*)ago:(NSTimeInterval)when;
@end

#pragma mark - Motion

@interface DuoMotion : NSObject
/// StreamLight / Apple ease (0.32, 0.72, 0, 1).
+ (void)ease:(NSTimeInterval)duration delay:(NSTimeInterval)delay animations:(void (^)(void))animations completion:(nullable void (^)(void))completion;
+ (void)curve:(CGPoint)c1 :(CGPoint)c2 duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay animations:(void (^)(void))animations completion:(nullable void (^)(void))completion;
/// Springy settle (Android OvershootInterpolator 1.6).
+ (void)spring:(NSTimeInterval)duration animations:(void (^)(void))animations;
/// Content swap: slides in from the side it came from (dir -1 left, 1 right, 0 fade only).
+ (void)slideIn:(UIView*)v dir:(NSInteger)dir distance:(CGFloat)distance;
+ (void)fadeIn:(UIView*)v duration:(NSTimeInterval)duration;
/// Children rise in one after the other.
+ (void)stagger:(NSArray<UIView*>*)views;
/// Quick squish and back (controller A).
+ (void)tap:(UIView*)v;
/// Number counts up.
+ (void)countUp:(UILabel*)label to:(NSInteger)to;
/// Gentle pulse (loading text).
+ (void)pulse:(UIView*)v;
/// Haptic tick when the controller moves focus.
+ (void)navTick;
@end

#pragma mark - Building blocks

/// Controller face button glyph (A/B/X/Y/≡/⧉): glossy circle with a soft halo.
@interface DuoGlyphView : UIView
- (instancetype)initWithLetter:(NSString*)letter;
@end

/// The app icon: dark rounded square with the "play on a display" glyph in the accent.
@interface DuoLogoView : UIView
- (instancetype)initWithSize:(CGFloat)size;
@end

/// Duo button: optional controller glyph + label; secondary (see-through) or primary (accent).
/// Focused (controller) = lifted with an accent ring; pressed = squish.
@interface DuoButton : UIControl
@property (nonatomic, readonly) UILabel* label;
@property (nonatomic) BOOL duoFocused;
@property (nonatomic, copy, nullable) void (^onTap)(void);
- (instancetype)initWithTitle:(NSString*)title glyph:(nullable NSString*)glyph primary:(BOOL)primary;
- (void)setTitle:(NSString*)title;
/// Glyphs show only while a controller is connected; the "A" glyph only while focused.
- (void)updateGlyphs:(BOOL)pad;
- (void)fire;
@end

/// Small LB / RB key hint.
UILabel* DuoKeyPill(NSString* text);
/// Text label in the Duo fonts.
UILabel* DuoText(NSString* text, CGFloat size, UIColor* color, BOOL bold);
/// Info chip (resolution, FPS …).
UILabel* DuoInfoChip(NSString* text);
/// Status badge with a coloured dot.
UIView* DuoBadge(NSString* text, UIColor* dot, UILabel* _Nullable * _Nullable labelOut, UIView* _Nullable * _Nullable dotOut);
/// Rounded-rect cover placeholder background (accent tint gradient).
CAGradientLayer* DuoPlaceholderLayer(void);

/// Toast at the bottom of a view (clipboard, session summary …).
void DuoToast(UIView* inView, NSString* text);

/// Monitor icon (apps without a cover).
UIImage* DuoMonitorIcon(CGFloat size, UIColor* color);

NS_ASSUME_NONNULL_END

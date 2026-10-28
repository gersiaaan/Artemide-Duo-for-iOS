//
//  DuoSupport.h
//  Artemide Duo for iOS
//
//  Colours, fonts and small preferences shared by the Artemide Duo screens.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DuoTheme : NSObject
+ (UIColor*)hex:(uint32_t)rgb;
+ (UIColor*)hex:(uint32_t)rgb alpha:(CGFloat)alpha;
+ (UIColor*)floor;      // page background
+ (UIColor*)card;       // cards and buttons
+ (UIColor*)cardHigh;   // pressed / raised
+ (UIColor*)line;       // hairlines
+ (UIColor*)text;
+ (UIColor*)text2;
+ (UIColor*)text3;
+ (UIColor*)accent;
+ (UIColor*)online;
+ (UIColor*)offline;
+ (UIColor*)warn;
+ (UIFont*)font:(CGFloat)size weight:(UIFontWeight)weight;
+ (UIFont*)digits:(CGFloat)size weight:(UIFontWeight)weight;
@end

@interface DuoPrefs : NSObject
/// Ask Apollo / Vibeshine for a virtual display matching the stream (default on).
+ (BOOL)virtualDisplay;
+ (void)setVirtualDisplay:(BOOL)on;
/// Send the iPad clipboard to the PC when a stream starts, fetch it back when it ends (default on).
+ (BOOL)clipboardSync;
+ (void)setClipboardSync:(BOOL)on;
/// Hardware model, e.g. "iPad8,1".
+ (NSString*)deviceModel;
/// iPad Pro 11" (1st generation, 2018): 2388 x 1668, 120 Hz.
+ (BOOL)isIPadPro11FirstGen;
/// This device's Tailscale IPv4 address, or nil when Tailscale isn't connected.
+ (nullable NSString*)tailscaleAddress;
+ (BOOL)isTailscaleAddress:(nullable NSString*)address;
/// Tools and apps (Desktop, Remote Monitor, Steam Big Picture ...) as opposed to games.
+ (BOOL)isAppName:(nullable NSString*)name;
@end

NS_ASSUME_NONNULL_END

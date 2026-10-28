//
//  DuoSupport.m
//  Artemide Duo for iOS
//

#import "DuoSupport.h"

#include <sys/sysctl.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

static NSString* const kVirtualDisplay = @"duo_virtual_display";
static NSString* const kClipboardSync = @"duo_clipboard_sync";

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

+ (UIColor*)floor { return [self hex:0x0B0D10]; }
+ (UIColor*)card { return [self hex:0x161A1F alpha:0.86]; }
+ (UIColor*)cardHigh { return [self hex:0x20252C]; }
+ (UIColor*)line { return [UIColor colorWithWhite:1.0 alpha:0.09]; }
+ (UIColor*)text { return [self hex:0xF3F6F8]; }
+ (UIColor*)text2 { return [self hex:0xA9AFB7]; }
+ (UIColor*)text3 { return [self hex:0x6B717A]; }
+ (UIColor*)accent { return [self hex:0x00B8D4]; }
+ (UIColor*)online { return [self hex:0x3DDC84]; }
+ (UIColor*)offline { return [self hex:0xE5534B]; }
+ (UIColor*)warn { return [self hex:0xE3B341]; }

+ (UIFont*)font:(CGFloat)size weight:(UIFontWeight)weight {
    return [UIFont systemFontOfSize:size weight:weight];
}

+ (UIFont*)digits:(CGFloat)size weight:(UIFontWeight)weight {
    return [UIFont monospacedDigitSystemFontOfSize:size weight:weight];
}

@end

@implementation DuoPrefs

+ (BOOL)boolForKey:(NSString*)key fallback:(BOOL)fallback {
    NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
    return [d objectForKey:key] == nil ? fallback : [d boolForKey:key];
}

+ (BOOL)virtualDisplay { return [self boolForKey:kVirtualDisplay fallback:YES]; }
+ (void)setVirtualDisplay:(BOOL)on { [[NSUserDefaults standardUserDefaults] setBool:on forKey:kVirtualDisplay]; }
+ (BOOL)clipboardSync { return [self boolForKey:kClipboardSync fallback:YES]; }
+ (void)setClipboardSync:(BOOL)on { [[NSUserDefaults standardUserDefaults] setBool:on forKey:kClipboardSync]; }

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
    // Strip a port ("100.101.102.103:47989")
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

@end

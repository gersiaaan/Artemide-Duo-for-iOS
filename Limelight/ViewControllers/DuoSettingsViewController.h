//
//  DuoSettingsViewController.h
//  Artemide Duo for iOS
//
//  Full-screen settings in the Artemide Duo look (port of the Android settings decoration):
//  tabs instead of one long list, grouped card rows, toggles, pill selectors and sliders.
//  Moonlight's own values stay in its database; the Duo extras live in NSUserDefaults.
//

#import <UIKit/UIKit.h>
#import "DuoPad.h"

NS_ASSUME_NONNULL_BEGIN

@interface DuoSettingsViewController : UIViewController <DuoPadTarget>
/// Called after the settings were saved and the screen is gone.
@property (nonatomic, copy, nullable) void (^onClose)(void);
@end

NS_ASSUME_NONNULL_END

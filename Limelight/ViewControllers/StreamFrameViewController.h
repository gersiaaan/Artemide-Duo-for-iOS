//
//  StreamFrameViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/18/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "Connection.h"
#import "StreamConfiguration.h"
#import "StreamView.h"

#import <UIKit/UIKit.h>

#if TARGET_OS_TV
@import GameController;

@interface StreamFrameViewController : GCEventViewController <ConnectionCallbacks, ControllerSupportDelegate, UserInteractionDelegate, UIScrollViewDelegate>
#else
@interface StreamFrameViewController : UIViewController <ConnectionCallbacks, ControllerSupportDelegate, UserInteractionDelegate, UIScrollViewDelegate>
#endif
@property (nonatomic) StreamConfiguration* streamConfig;
/// Artemide Duo: shown on the stream-start screen.
@property (nonatomic, nullable) UIImage* duoCover;
@property (nonatomic, nullable, copy) NSString* duoHostName;
@property (nonatomic, nullable, copy) NSString* duoHostUuid;
/// Artemide Duo: what the last stream did (for the session summary on the host page).
+ (nullable NSString*)duoTakeSessionSummary;

-(void)updatePreferredDisplayMode:(BOOL)streamActive;

@end

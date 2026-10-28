//
//  DuoWavesView.h
//  Artemide Duo for iOS
//
//  The floor of the pre-stream screens: a dark ramp washed with the accent towards the bottom,
//  and five slow waves travelling left to right on it. Port of Artemide Duo's DuoWavesView
//  (itself ported from StreamLight's AmbientBackground / AmbientWaves, GPL-3.0).
//

#import <UIKit/UIKit.h>

@interface DuoWavesView : UIView
- (instancetype)initWithFrame:(CGRect)frame rise:(BOOL)riseOnStart;
/// Overlay mode: no floor, pale light lines (drawn in front of a cover backdrop).
@property (nonatomic) BOOL overlay;
@end

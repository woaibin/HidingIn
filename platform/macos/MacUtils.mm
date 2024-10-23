//
// Created by 宾小康 on 2024/10/22.
//
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import "MacUtils.h"
float getScalingFactor() {
    NSScreen *mainScreen = [NSScreen mainScreen];
    // Get the screen's backing scale factor (retina or non-retina)
    CGFloat scaleFactor = [mainScreen backingScaleFactor];

    return scaleFactor;
}
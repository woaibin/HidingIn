//
// Created by 宾小康 on 2024/10/22.
//
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import "MacUtils.h"
float getScalingFactor() {
    NSScreen *mainScreen = [NSScreen mainScreen];
    // Get the screen's backing scale factor (retina or non-retina)
    CGFloat scaleFactor = [mainScreen backingScaleFactor];

    return scaleFactor;
}

// Function to find and print the size of windows based on a given PID
std::tuple<int, int, int,int> getWindowSizesForPID(pid_t targetPID) {
    // Get a list of all windows on the screen
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);

    // If the list is not null, we proceed
    if (windowList != NULL) {
        // Iterate through the list of windows
        for (int i = 0; i < CFArrayGetCount(windowList); i++) {
            // Get the dictionary for each window
            auto windowInfo = static_cast<CFDictionaryRef>(CFArrayGetValueAtIndex(windowList, i));

            // Get the window owner PID
            auto ownerPIDRef = static_cast<CFNumberRef>(CFDictionaryGetValue(windowInfo, kCGWindowOwnerPID));
            pid_t ownerPID;
            CFNumberGetValue(ownerPIDRef, kCFNumberIntType, &ownerPID);

            // Check if this window belongs to the target PID
            if (ownerPID == targetPID) {
                // Get the window layer
                auto layerRef = static_cast<CFNumberRef>(CFDictionaryGetValue(windowInfo, kCGWindowLayer));
                int layer = 0;
                CFNumberGetValue(layerRef, kCFNumberIntType, &layer);
                // Get the window bounds (size and position)
                auto windowBounds = static_cast<CFDictionaryRef>(CFDictionaryGetValue(windowInfo,
                                                                                                 kCGWindowBounds));
                if (windowBounds) {
                    // Convert the bounds dictionary to a CGRect
                    CGRect bounds;
                    CGRectMakeWithDictionaryRepresentation(windowBounds, &bounds);
                    // Check if it is a small window (possibly a status bar icon)
                    if (bounds.size.width < 100 && bounds.size.height < 100 && bounds.origin.y == 0) {
                        NSLog(@"Skipping small window (likely a status bar icon) with size: (%f, %f), Layer: %d", bounds.size.width, bounds.size.height, layer);
                        continue;
                    }

                    // Output the size and position of the window
                    NSLog(@"Window for PID %d - Position: (%f, %f), Size: (%f, %f)",
                          targetPID,
                          bounds.origin.x, bounds.origin.y,
                          bounds.size.width, bounds.size.height);
                    return {bounds.origin.x, bounds.origin.y,bounds.size.width, bounds.size.height};
                }
            }
        }

        // Release the window list
        CFRelease(windowList);
    } else {
        NSLog(@"No windows found on screen.");
    }
    return {};
}
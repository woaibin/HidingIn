//
// Created by 宾小康 on 2024/10/22.
//
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import "MacUtils.h"
#include <iostream>
float getScalingFactor() {
    NSScreen *mainScreen = [NSScreen mainScreen];
    // Get the screen's backing scale factor (retina or non-retina)
    CGFloat scaleFactor = [mainScreen backingScaleFactor];

    return scaleFactor;
}

// Function to find and print the size of windows based on a given PID
std::tuple<int, int, int,int, int> getWindowSizesForPID(pid_t targetPID) {
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
                auto windowIDRef = static_cast<CFNumberRef>(CFDictionaryGetValue(windowInfo, kCGWindowNumber));
                int layer = 0;
                CFNumberGetValue(layerRef, kCFNumberIntType, &layer);
                CGWindowID windowID;
                CFNumberGetValue(windowIDRef, kCFNumberIntType, &windowID);
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
                    return {bounds.origin.x, bounds.origin.y,bounds.size.width, bounds.size.height, windowID};
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

NSRunningApplication* findAppPidByPid(pid_t pid) {
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

    for (NSRunningApplication *app in runningApps) {
        if (app.processIdentifier == pid) {
            return app;
        }
    }
    return nil;
}

// Function definition
void stickToApp(int targetAppWinId, int targetAppPID, void *overlayWindow) {
    NSView* nsView = (NSView*) overlayWindow;
    NSWindow* nsWindow = [nsView window];

    if (!nsWindow) {
        std::cerr << "No valid overlay window found." << std::endl;
        return;
    }

    // Step 1: Find the position and size of the window with the given CGWindowID
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, targetAppWinId);
    if (windowList == nullptr || CFArrayGetCount(windowList) == 0) {
        std::cerr << "No window found with the given CGWindowID." << std::endl;
        if (windowList) CFRelease(windowList);
        return;
    }

    // Get window info dictionary
    NSDictionary *windowInfo = (__bridge NSDictionary *)CFArrayGetValueAtIndex(windowList, 0);
    if (!windowInfo) {
        std::cerr << "Failed to retrieve window information." << std::endl;
        CFRelease(windowList);
        return;
    }

    // Extract window position and size
    CGRect windowRect;
    NSDictionary *boundsDict = windowInfo[(id)kCGWindowBounds];
    if (!boundsDict || !CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDict, &windowRect)) {
        std::cerr << "Failed to extract window bounds." << std::endl;
        CFRelease(windowList);
        return;
    }

    // Release the window list as we've extracted the needed information
    CFRelease(windowList);

    // Step 2: Update the overlay window's frame to match the target window
    NSRect frame = NSMakeRect(windowRect.origin.x, windowRect.origin.y, windowRect.size.width, windowRect.size.height);

    // Convert to screen coordinates if needed (depending on the screen origin)
    NSScreen *mainScreen = [NSScreen mainScreen];
    if (mainScreen) {
        CGFloat screenHeight = [mainScreen frame].size.height;
        frame.origin.y = screenHeight - windowRect.origin.y - windowRect.size.height;
    }

    [nsWindow setFrame:frame display:YES];

    auto nsApp = findAppPidByPid(targetAppPID);
    [nsApp activateWithOptions:NSApplicationActivateAllWindows];

    // Step 3: Make the overlay window topmost and ignore mouse events
    [nsWindow setLevel:NSFloatingWindowLevel];   // Keep the window on top
    [nsWindow setIgnoresMouseEvents:YES];        // Ignore mouse events to let them pass through

    // Step 4: Bring the overlay window to the front and make it visible
    //[nsWindow makeKeyAndOrderFront:nil];
    //[[NSApplication sharedApplication] activateIgnoringOtherApps : YES];

    // Finally, log for debugging
    std::cout << "Overlay window now sticks to the target window with ID: " << targetAppWinId << std::endl;
}

std::vector<int> getCurrentAppWindowIDVec(){
    auto nsApp = [NSApplication sharedApplication];
    std::vector<int> retWinIDs;
    for(auto window in nsApp.windows){
        retWinIDs.push_back((int)[window windowNumber]);
    }

    return retWinIDs;
}
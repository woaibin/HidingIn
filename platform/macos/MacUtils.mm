//
// Created by 宾小康 on 2024/10/22.
//
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import "MacUtils.h"
#include <iostream>
#include "../com/NotificationCenter.h"
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
    auto nsView = (NSView*) overlayWindow;
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
    NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, 0);
    if (!windowInfo) {
        std::cerr << "Failed to retrieve window information." << std::endl;
        CFRelease(windowList);
        return;
    }

    // Extract window position and size
    CGRect windowRect;
    NSDictionary *boundsDict = windowInfo[(id)kCGWindowBounds];
    if (!boundsDict || !CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDict, &windowRect)) {
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

    // update capture app info:
    Message msg;
    NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
    auto capWinInfo = (WindowSubMsg*)msg.subMsg.get();
    capWinInfo->capturedAppX = windowRect.origin.x * capWinInfo->scalingFactor;
    capWinInfo->capturedAppY = windowRect.origin.y* capWinInfo->scalingFactor;
    capWinInfo->capturedAppWidth = windowRect.size.width* capWinInfo->scalingFactor;
    capWinInfo->capturedAppHeight = windowRect.size.height* capWinInfo->scalingFactor;

    [nsWindow setFrame:frame display:YES];

    if(!isAppInForeground(targetAppPID)){
        auto nsApp = findAppPidByPid(targetAppPID);
        [nsApp activateWithOptions:NSApplicationActivateAllWindows];
    }

    // Step 4: Bring the overlay window to the front and make it visible
    [nsWindow makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps : YES];

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

std::vector<int> getWindowIDsForAppByName(const std::string &appName) {
    std::vector<int> windowIDs;

    // Convert std::string to an NSString
    NSString *targetAppName = [NSString stringWithUTF8String:appName.c_str()];

    // Get list of running applications
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

    // Find the application by name
    NSRunningApplication *targetApp = nil;
    for (NSRunningApplication *app in runningApps) {
        if ([[app localizedName] isEqualToString:targetAppName]) {
            targetApp = app;
            break;
        }
    }

    if (!targetApp) {
        printf("App with name %s not found.\n", appName.c_str());
        return windowIDs;
    }

    // Get the process ID of the target application
    pid_t targetPID = [targetApp processIdentifier];

    // Fetch information for all windows
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);

    // Iterate over the windows
    for (NSDictionary *windowInfo in (NSArray *)windowList) {
        // Get the window's owner process ID
        pid_t windowPID = [windowInfo[(NSString *)kCGWindowOwnerPID] intValue];

        // Check if the window belongs to the target app
        if (windowPID == targetPID) {
            // Get the window ID
            int windowID = [windowInfo[(NSString *)kCGWindowNumber] intValue];
            windowIDs.push_back(windowID);
        }
    }

    // Release the window list
    CFRelease(windowList);

    return windowIDs;
}

bool getWindowGeometry(int windowID, std::tuple<int, int, int, int>& rectGeometry) {
    // Get the list of windows with the specific window ID
    CFArrayRef windowList = CGWindowListCreateDescriptionFromArray(CFArrayCreate(nullptr, (const void**)&windowID, 1, nullptr));

    if (windowList == nullptr || CFArrayGetCount(windowList) == 0) {
        std::cerr << "No window found with the given window ID: " << windowID << std::endl;
        if (windowList != nullptr) {
            CFRelease(windowList);
        }
        return false;
    }

    // Get the first (and only) window's dictionary
    CFDictionaryRef windowInfo = static_cast<CFDictionaryRef>(CFArrayGetValueAtIndex(windowList, 0));

    // Get the bounds of the window
    CFDictionaryRef boundsDict = static_cast<CFDictionaryRef>(CFDictionaryGetValue(windowInfo, kCGWindowBounds));
    if (boundsDict == nullptr) {
        std::cerr << "Failed to get window bounds." << std::endl;
        CFRelease(windowList);
        return false;
    }

    // Convert the bounds dictionary to a CGRect
    CGRect roiRect;
    if (!CGRectMakeWithDictionaryRepresentation(boundsDict, &roiRect)) {
        std::cerr << "Failed to convert bounds dictionary to CGRect." << std::endl;
        CFRelease(windowList);
        return false;
    }

    // Update the tuple with the correct window geometry
    rectGeometry = std::make_tuple(
            static_cast<int>(roiRect.origin.x),
            static_cast<int>(roiRect.origin.y),
            static_cast<int>(roiRect.size.width),
            static_cast<int>(roiRect.size.height)
    );

    // Release the window list
    CFRelease(windowList);

    return true;
}

std::tuple<int, int, int, int> resizeAndMoveOverlayWindow(void* nativeWindowHandle, int targetAppWinId) {
    if (!nativeWindowHandle) {
        std::cerr << "No valid NSWindow found." << std::endl;
        return {};
    }

    auto nsView = (NSView*)nativeWindowHandle;
    auto nsWindow = [nsView window];

    // Step 1: Find the position and size of the window with the given CGWindowID
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, targetAppWinId);
    if (windowList == nullptr || CFArrayGetCount(windowList) == 0) {
        std::cerr << "No window found with the given CGWindowID: " << targetAppWinId << std::endl;
        if (windowList) CFRelease(windowList);
        return {};
    }

    // Get window info dictionary
    NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, 0);
    if (!windowInfo) {
        std::cerr << "Failed to retrieve window information." << std::endl;
        CFRelease(windowList);
        return {};
    }

    // Extract window position and size
    CGRect windowRect;
    NSDictionary *boundsDict = windowInfo[(id)kCGWindowBounds];
    if (!boundsDict || !CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDict, &windowRect)) {
        std::cerr << "Failed to extract window bounds." << std::endl;
        CFRelease(windowList);
        return {};
    }

    // Release the window list as we've extracted the needed information
    CFRelease(windowList);

    // Step 2: Create an NSRect from the target window's CGRect
    NSRect frame = NSMakeRect(windowRect.origin.x, windowRect.origin.y, windowRect.size.width, windowRect.size.height);

    // Step 3: Convert the coordinates to screen coordinates if needed
    NSScreen *mainScreen = [NSScreen mainScreen];
    if (mainScreen) {
        CGFloat screenHeight = [mainScreen frame].size.height;
        // Adjust the y-coordinate to account for macOS's flipped screen origin
        frame.origin.y = screenHeight - windowRect.origin.y - windowRect.size.height;
    }

    // Step 4: Update the NSWindow's frame to match the target window
    [nsWindow setFrame:frame display:YES];

    return std::make_tuple(windowRect.origin.x, windowRect.origin.y, windowRect.size.width, windowRect.size.height);
}

bool isAppInForeground(int pid) {
    ProcessSerialNumber psn;
    if (GetFrontProcess(&psn) == noErr) {
        // Get the PID of the frontmost process
        pid_t frontPid = 0;
        if (GetProcessPID(&psn, &frontPid) == noErr) {
            return frontPid == pid;
        }
    }
    return false;
}

void wakeUpAppByPID(int pid) {
    if(!isAppInForeground(pid)){
        auto nsApp = findAppPidByPid(pid);
        [nsApp activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
    }
}

bool isMouseInWindowWithID(void *viewPtr) {
    // Cast the void* back to NSView*
    NSView *view = (__bridge NSView *)viewPtr;

    // Get the current mouse location in screen coordinates
    NSPoint mouseLocation = [NSEvent mouseLocation];

    // Convert the view's frame to screen coordinates
    NSRect viewFrameInWindow = [view convertRect:view.bounds toView:nil];
    NSRect viewFrameInScreen = [view.window convertRectToScreen:viewFrameInWindow];

    // Check if the mouse location is inside the view's frame in screen coordinates
    return NSPointInRect(mouseLocation, viewFrameInScreen);
}

void disableShadow(void *winId) {
    auto nsView = (NSView*) winId;

    NSWindow *window = [nsView window];

    // Disable shadow for the window
    [window setHasShadow:NO];
}


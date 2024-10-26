//
// Created by 宾小康 on 2024/10/24.
//
#include "RemoteInputControllerMacOS.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h> /* For kVK_ constants, and TIS functions. */
#include <unistd.h>

// Constructor with app name
RemoteInputControllerMacOS::RemoteInputControllerMacOS(const std::string& appName)
        : appName(appName), appPid(-1) {
    this->appPid = findAppPidByName(appName);
    if (appPid == -1) {
        NSLog(@"Application with name %@ not found.", [NSString stringWithUTF8String:appName.c_str()]);
    }
}

// Constructor with app PID
RemoteInputControllerMacOS::RemoteInputControllerMacOS(pid_t pid)
        : appPid(pid) {}

// Destructor
RemoteInputControllerMacOS::~RemoteInputControllerMacOS() {}

// Helper function to find the PID of an application by its name
pid_t RemoteInputControllerMacOS::findAppPidByName(const std::string& appName) {
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    NSString *appNameNSString = [NSString stringWithUTF8String:appName.c_str()];

    for (NSRunningApplication *app in runningApps) {
        if ([app.localizedName isEqualToString:appNameNSString]) {
            return app.processIdentifier;
        }
    }
    return -1;
}

// Method to focus the app
bool RemoteInputControllerMacOS::focusApp() {
    AXUIElementRef appRef = AXUIElementCreateApplication(this->appPid);

    if (!appRef) {
        NSLog(@"Failed to create AXUIElement for PID: %d", this->appPid);
        return false;
    }

    AXUIElementRef focusedWindow = NULL;
    AXError result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute, (CFTypeRef *)&focusedWindow);

    if (result != kAXErrorSuccess || !focusedWindow) {
        NSLog(@"Failed to get focused window for PID: %d", this->appPid);
        CFRelease(appRef);
        return false;
    }

    result = AXUIElementSetAttributeValue(appRef, kAXFocusedWindowAttribute, focusedWindow);

    if (result != kAXErrorSuccess) {
        NSLog(@"Failed to focus window for PID: %d", this->appPid);
        CFRelease(appRef);
        CFRelease(focusedWindow);
        return false;
    }

    CFRelease(appRef);
    CFRelease(focusedWindow);

    NSLog(@"Successfully focused app with PID: %d", this->appPid);
    return true;
}

// Helper function to create a string representation of a key
CFStringRef createStringForKey(CGKeyCode keyCode) {
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = static_cast<CFDataRef>(TISGetInputSourceProperty(currentKeyboard,
                                                                            kTISPropertyUnicodeKeyLayoutData));
    if(!layoutData){
        return NULL;
    }
    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);

    UInt32 keysDown = 0;
    UniChar chars[4];
    UniCharCount realLength;

    UCKeyTranslate(keyboardLayout, keyCode, kUCKeyActionDisplay, 0, LMGetKbdType(), kUCKeyTranslateNoDeadKeysBit, &keysDown, sizeof(chars) / sizeof(chars[0]), &realLength, chars);
    CFRelease(currentKeyboard);

    return CFStringCreateWithCharacters(kCFAllocatorDefault, chars, 1);
}

// Helper function to get CGKeyCode for a character
CGKeyCode keyCodeForChar(const char c) {
    static CFMutableDictionaryRef charToCodeDict = NULL;
    CGKeyCode code = UINT16_MAX;
    UniChar character = c;
    CFStringRef charStr = NULL;

    if (charToCodeDict == NULL) {
        charToCodeDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 256, &kCFCopyStringDictionaryKeyCallBacks, NULL);
        if (charToCodeDict == NULL){
            NSLog(@"failed to create char to code dict");
            return UINT16_MAX;
        }

        for (size_t i = 0; i < 256; ++i) {
            CFStringRef string = createStringForKey((CGKeyCode)i);
            if (string != NULL) {
                CFDictionaryAddValue(charToCodeDict, string, (const void *)i);
                CFRelease(string);
            }
        }
    }

    charStr = CFStringCreateWithCharacters(kCFAllocatorDefault, &character, 1);

    if (!CFDictionaryGetValueIfPresent(charToCodeDict, charStr, (const void **)&code)) {
        code = UINT16_MAX;
    }

    CFRelease(charStr);
    return code;
}

// Method to send a string to the app
void RemoteInputControllerMacOS::sendString(const std::string& message) {
    if(message.empty()){
        return;
    }
    NSString* messageNSString = [NSString stringWithUTF8String:message.c_str()];
    NSUInteger length = [messageNSString length];
    NSLog(@"length:%lu", static_cast<unsigned long>(length));
    for (NSUInteger i = 0; i < length; i++) {
        unichar character = [messageNSString characterAtIndex:i];
        CGKeyCode keyCode = keyCodeForChar(character);
        NSLog(@"first step: keycode:%d", keyCode);
        if (keyCode == UINT16_MAX) {
            break;
        }
        NSLog(@"second step");
        CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
        if (keyDown == NULL) {
            NSLog(@"Failed to create key down event for keyCode: %u", keyCode);
            break;
        }

        // Check for valid PID before posting the event
        if (this->appPid <= 0) {
            NSLog(@"Invalid PID: %d. Skipping event posting.", this->appPid);
            CFRelease(keyDown);
            break;
        }

        CGEventPostToPid(this->appPid, keyDown);
        CFRelease(keyDown);
        NSLog(@"third step");
        usleep(50000); // 50ms delay
        NSLog(@"fourth step");
        CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
        if (keyUp == NULL) {
            NSLog(@"Failed to create key up event for keyCode: %u", keyCode);
            break;
        }
        CGEventPostToPid(this->appPid, keyUp);
        CFRelease(keyUp);
        NSLog(@"fifth step");
    }
}

// Method to send a mouse click at the given (x, y) coordinates
void RemoteInputControllerMacOS::sendMouseClickAt(double x, double y) {
    focusApp();
    // Step 1: Create an AXUIElement for the application using its appPid
    AXUIElementRef appElement = AXUIElementCreateApplication(this->appPid);
    if (!appElement) {
        NSLog(@"Failed to create AXUIElement for the application.");
        return;
    }

    // Step 2: Retrieve the main (focused) window of the application
    AXUIElementRef windowElement = nullptr;
    AXError error = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute, (CFTypeRef*)&windowElement);
    if (error != kAXErrorSuccess || !windowElement) {
        NSLog(@"Failed to get the focused window of the application.");
        CFRelease(appElement);
        return;
    }

    // Step 3: Get the size and position of the window to check if (x, y) is inside it
    CFTypeRef positionValue = nullptr;
    CFTypeRef sizeValue = nullptr;
    CGPoint windowPosition;
    CGSize windowSize;

    error = AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute, &positionValue);
    if (error == kAXErrorSuccess && positionValue) {
        AXValueGetValue((AXValueRef)positionValue, AXValueType::kAXValueTypeCGPoint, &windowPosition);
        CFRelease(positionValue);
    } else {
        NSLog(@"Failed to get the window position.");
        CFRelease(windowElement);
        CFRelease(appElement);
        return;
    }

    error = AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute, &sizeValue);
    if (error == kAXErrorSuccess && sizeValue) {
        AXValueGetValue((AXValueRef)sizeValue, AXValueType::kAXValueTypeCGSize, &windowSize);
        CFRelease(sizeValue);
    } else {
        NSLog(@"Failed to get the window size.");
        CFRelease(windowElement);
        CFRelease(appElement);
        return;
    }

    // Step 4: Check if the (x, y) is inside the window's bounds
//    if (x < windowPosition.x || x > windowPosition.x + windowSize.width ||
//        y < windowPosition.y || y > windowPosition.y + windowSize.height) {
//        NSLog(@"The (x, y) position is outside the window bounds.");
//        CFRelease(windowElement);
//        CFRelease(appElement);
//        return;
//    }
//
//    // Step 5: Find the UI element at the given (x, y) position
    AXUIElementRef elementAtPosition = nullptr;
//    CGPoint localPosition = CGPointMake(x - windowPosition.x, y - windowPosition.y);
    error = AXUIElementCopyElementAtPosition(windowElement, windowPosition.x, 20, &elementAtPosition);

    if (error != kAXErrorSuccess || !elementAtPosition) {
        NSLog(@"Failed to find an element at the specified");
        CFRelease(windowElement);
        CFRelease(appElement);
        return;
    }

    // Step 6: Perform the "press"/click action on the found element
    error = AXUIElementPerformAction(elementAtPosition, kAXPressAction);
    if (error != kAXErrorSuccess) {
        NSLog(@"Failed to perform a press action on the UI element.");
    } else {
        NSLog(@"Successfully clicked the element");
    }

    // Step 7: Clean up
    CFRelease(elementAtPosition);
    CFRelease(windowElement);
    CFRelease(appElement);
}

void RemoteInputControllerMacOS::sendKey(int keyCode) {
    focusApp();
    CGKeyCode cgKeyCode =(CGKeyCode)keyCode;
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, cgKeyCode, true);
    if (keyDown == NULL) {
        NSLog(@"Failed to create key down event for keyCode: %u", keyCode);
        return;
    }

    // Check for valid PID before posting the event
    if (this->appPid <= 0) {
        NSLog(@"Invalid PID: %d. Skipping event posting.", this->appPid);
        CFRelease(keyDown);
        return;
    }

    CGEventPostToPid(this->appPid, keyDown);
    CFRelease(keyDown);
    NSLog(@"third step");
    usleep(50000); // 50ms delay
    NSLog(@"fourth step");
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, cgKeyCode, false);
    if (keyUp == NULL) {
        NSLog(@"Failed to create key up event for keyCode: %u", cgKeyCode);
        return;
    }
    CGEventPostToPid(this->appPid, keyUp);
    CFRelease(keyUp);
}

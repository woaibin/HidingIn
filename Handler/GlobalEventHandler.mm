#include "GlobalEventHandler.h"
#include <ApplicationServices/ApplicationServices.h>
#include <iostream>

// Helper function to check if the Command key is pressed
bool isCommandKeyPressed(CGEventFlags flags) {
    return (flags & kCGEventFlagMaskCommand) != 0;
}

// Static callback function for the event tap
CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
    if (type == kCGEventKeyDown) {
        auto* handler = static_cast<GlobalEventHandler*>(refcon);
        int keycode = (int)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        CGEventFlags flags = CGEventGetFlags(event);

        bool isCommandPressed = isCommandKeyPressed(flags);
        handler->handleKeyPress(keycode, isCommandPressed);
    }
    return event;
}

GlobalEventHandler::GlobalEventHandler() : eventTap(nullptr), runLoopSource(nullptr) {}

GlobalEventHandler::~GlobalEventHandler() {
    stopListening();
}

void GlobalEventHandler::startListening() {
    // Create the event tap to listen for all key down events
    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown);
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, static_cast<CGEventTapOptions>(0), eventMask, eventCallback, this);

    if (!eventTap) {
        std::cerr << "Failed to create event tap." << std::endl;
        return;
    }

    // Create a run loop source and add it to the current run loop
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, (CFMachPortRef)eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), (CFRunLoopSourceRef)runLoopSource, kCFRunLoopCommonModes);

    // Enable the event tap
    CGEventTapEnable((CFMachPortRef)eventTap, true);

    std::cout << "Started listening for global key press events." << std::endl;
}

void GlobalEventHandler::stopListening() {
    if (eventTap) {
        // Remove the event tap from the run loop and release resources
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), (CFRunLoopSourceRef)runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CFRelease(eventTap);

        eventTap = nullptr;
        runLoopSource = nullptr;

        std::cout << "Stopped listening for global key press events." << std::endl;
    }
}

void GlobalEventHandler::handleKeyPress(int keycode, bool isCommandPressed) {
    // We are checking for Command + B (keycode for 'B' is 11 on macOS)
    if (isCommandPressed && keycode == 11) {
        if(ctrlBPressedCB){
            ctrlBPressedCB(keycode);
        }
    }
}
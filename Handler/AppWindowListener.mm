#import "AppWindowListener.h"
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

// Helper function to convert AXValueRef to CGPoint
static CGPoint getAXPosition(AXUIElementRef element) {
    AXValueRef positionValue = NULL;
    CGPoint position = CGPointZero;
    if (AXUIElementCopyAttributeValue(element, kAXPositionAttribute, (CFTypeRef*)&positionValue) == kAXErrorSuccess) {
        AXValueGetValue(positionValue, (AXValueType) kAXValueCGPointType, &position);
        CFRelease(positionValue);
    }
    return position;
}

// Helper function to convert AXValueRef to CGSize
static CGSize getAXSize(AXUIElementRef element) {
    AXValueRef sizeValue = NULL;
    CGSize size = CGSizeZero;
    if (AXUIElementCopyAttributeValue(element, kAXSizeAttribute, (CFTypeRef*)&sizeValue) == kAXErrorSuccess) {
        AXValueGetValue(sizeValue, (AXValueType) kAXValueCGSizeType, &size);
        CFRelease(sizeValue);
    }
    return size;
}

// Callback for AXObserver
static void axWindowCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon) {
    AppWindowListener *listener = (AppWindowListener*)refcon;

    // Get window position and size
    CGPoint position = getAXPosition(element);
    CGSize size = getAXSize(element);

    // Invoke callbacks if set
    if (listener->onWindowMovedCallback_) {
        listener->onWindowMovedCallback_(position.x, position.y);
    }
    if (listener->onWindowResizedCallback_) {
        listener->onWindowResizedCallback_(size.width, size.height);
    }
}

#pragma mark - Constructor / Destructor

AppWindowListener::AppWindowListener(pid_t appPID, CGWindowID windowID)
        : appPID_(appPID), windowID_(windowID), axObserver_(nullptr), axAppElement_(nullptr), axWindowElement_(nullptr), pollingActive_(false) {
    // AXUIElement for the app based on PID
    axAppElement_ = (void*)AXUIElementCreateApplication(appPID_);
}

AppWindowListener::~AppWindowListener() {
    stopMonitoring();
    if (axAppElement_) {
        CFRelease(axAppElement_);
    }
}

#pragma mark - AX API Monitoring

void AppWindowListener::setupAXObserver() {
    if (!axAppElement_) return;

    // Get the first window of the app
    CFArrayRef windows;
    if (AXUIElementCopyAttributeValue(TO_AXUIELEMENT_REF(axAppElement_), kAXWindowsAttribute, (CFTypeRef*)&windows) == kAXErrorSuccess) {
        axWindowElement_ = (void*)CFArrayGetValueAtIndex(windows, 0);
        CFRetain(axWindowElement_);  // Retain the window element
        CFRelease(windows);  // Release the windows array
    }

    // Create AXObserver
    auto obRef = TO_AXOBSERVER_REF(axObserver_);
    AXObserverCreate(appPID_, axWindowCallback, &obRef);
    axObserver_ = obRef;
    AXObserverAddNotification(obRef, TO_AXUIELEMENT_REF(axWindowElement_), kAXMovedNotification, this);
    AXObserverAddNotification(obRef, TO_AXUIELEMENT_REF(axWindowElement_), kAXResizedNotification, this);

    // Add AXObserver to the run loop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obRef), kCFRunLoopDefaultMode);
}

void AppWindowListener::teardownAXObserver() {
    if (axObserver_) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(TO_AXOBSERVER_REF(axObserver_)), kCFRunLoopDefaultMode);
        CFRelease(axObserver_);
        axObserver_ = nullptr;
    }
    if (axWindowElement_) {
        CFRelease(axWindowElement_);
        axWindowElement_ = nullptr;
    }
}

void AppWindowListener::startAXMonitoring() {
    setupAXObserver();
}

#pragma mark - CGWindow API Monitoring

void AppWindowListener::startPolling(double interval) {
    pollingActive_ = true;

    // Create a global queue for the polling timer
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    // Create the timer source
    pollingTimer_ = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    // Set the timer to fire at the specified interval (in seconds)
    uint64_t intervalInNanoseconds = (uint64_t)(interval * NSEC_PER_SEC);

    // Configure the timer to start immediately and repeat at the interval
    dispatch_source_set_timer(pollingTimer_, dispatch_time(DISPATCH_TIME_NOW, 0), intervalInNanoseconds, 0);

    // Set the event handler for the timer (this gets called every time the timer fires)
    dispatch_source_set_event_handler(pollingTimer_, ^{
        // Get window information
        CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
        for (NSDictionary *windowInfo in (__bridge NSArray *)windowList) {
            pid_t windowPID = [windowInfo[(id)kCGWindowOwnerPID] intValue];
            CGWindowID windowID = [windowInfo[(id)kCGWindowNumber] unsignedIntValue];

            if (windowPID == appPID_ && windowID == windowID_) {
                CGRect windowBounds;
                CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)windowInfo[(id)kCGWindowBounds], &windowBounds);

                // Trigger the callbacks if they are set
                if (onWindowMovedCallback_) {
                    onWindowMovedCallback_(windowBounds.origin.x, windowBounds.origin.y);
                }
                if (onWindowResizedCallback_) {
                    onWindowResizedCallback_(windowBounds.size.width, windowBounds.size.height);
                }
            }
        }
        CFRelease(windowList);
    });

    // Start the timer
    dispatch_resume(pollingTimer_);
}

void AppWindowListener::stopPolling() {
    if (pollingActive_ && pollingTimer_) {
        dispatch_source_cancel(pollingTimer_);
        pollingTimer_ = nullptr;
        pollingActive_ = false;
    }
}

void AppWindowListener::startCGWindowMonitoring(double pollIntervalSeconds) {
    startPolling(pollIntervalSeconds);
}

#pragma mark - Monitoring Control

void AppWindowListener::stopMonitoring() {
    teardownAXObserver();
    stopPolling();
}

#pragma mark - Callback Setters

void AppWindowListener::setOnWindowMovedCallback(std::function<void(float x, float y)> callback) {
    onWindowMovedCallback_ = callback;
}

void AppWindowListener::setOnWindowResizedCallback(std::function<void(float width, float height)> callback) {
    onWindowResizedCallback_ = callback;
}
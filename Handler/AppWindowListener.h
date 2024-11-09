//
// Created by 宾小康 on 2024/11/9.
//

#ifndef HIDINGIN_APPWINDOWLISTENER_H
#define HIDINGIN_APPWINDOWLISTENER_H
#include <functional>
#include <CoreGraphics/CoreGraphics.h>

#define TO_AXOBSERVER_REF(obs) (AXObserverRef)obs
#define TO_AXUIELEMENT_REF(elem) (AXUIElementRef)elem

class AppWindowListener {
public:
    // Constructor takes PID of the target app and CGWindow ID
    AppWindowListener(pid_t appPID, CGWindowID windowID);

    // Destructor to clean up resources
    ~AppWindowListener();

    // Start listening for window position and size changes via AX API
    void startAXMonitoring();

    // Start polling window position and size changes via CGWindow API
    void startCGWindowMonitoring(double pollIntervalSeconds = 0.1);

    // Stop monitoring (for both AX and CGWindow monitoring)
    void stopMonitoring();

    // Set a callback for window position changes
    void setOnWindowMovedCallback(std::function<void(float x, float y)> callback);

    // Set a callback for window size changes
    void setOnWindowResizedCallback(std::function<void(float width, float height)> callback);

public:
    // Callbacks
    std::function<void(float, float)> onWindowMovedCallback_;
    std::function<void(float, float)> onWindowResizedCallback_;

private:
    pid_t appPID_;
    CGWindowID windowID_;

    // Internal methods for AX API monitoring
    void setupAXObserver();
    void teardownAXObserver();

    // Internal methods for CGWindow API polling
    void startPolling(double interval);
    void stopPolling();

    // AX Observer and elements
    /*AXObserverRef*/void* axObserver_;
    /*AXUIElementRef*/void* axAppElement_;
    /*AXUIElementRef*/void* axWindowElement_;

    dispatch_source_t pollingTimer_;

    // Polling control
    bool pollingActive_;
};

#endif //HIDINGIN_APPWINDOWLISTENER_H

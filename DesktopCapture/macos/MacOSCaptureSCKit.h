// ScreenCapture.h
#include <optional>
#ifndef SCREEN_CAPTURE_H
#define SCREEN_CAPTURE_H
#include "../common/CaptureStuff.h"
class MacOSCaptureSCKit {  // Removed the trailing underscore
public:
    MacOSCaptureSCKit();    // Constructor
    ~MacOSCaptureSCKit();   // Destructor

    // Start capturing the screen content
    bool startCapture(std::optional<DesktopCaptureArgs> args = std::nullopt);

    bool startCaptureWithApplicationName(std::string applicationName);

    // Stop capturing the screen content
    void stopCapture();

    void* getLatestCaptureFrame();

    CaptureStatus getCaptureStatus() { return captureStatus; }

private:
    class Impl;         // Forward declaration of the implementation class
    Impl *impl;         // Pointer to the implementation class
    CaptureStatus captureStatus = CaptureStatus::NotStart;
};

#endif // SCREEN_CAPTURE_H

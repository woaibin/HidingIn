// ScreenCapture.h

#ifndef SCREEN_CAPTURE_H
#define SCREEN_CAPTURE_H
class MacosCapture {  // Removed the trailing underscore
public:
    MacosCapture();    // Constructor
    ~MacosCapture();   // Destructor

    // Start capturing the screen content
    bool startCapture();

    // Stop capturing the screen content
    void stopCapture();
private:
    class Impl;         // Forward declaration of the implementation class
    Impl *impl;         // Pointer to the implementation class
};
#endif // SCREEN_CAPTURE_H

//
// Created by 宾小康 on 2024/10/26.
//

#ifndef HIDINGIN_COMPOSITECAPTURE_H
#define HIDINGIN_COMPOSITECAPTURE_H
#include <vector>
#include <string>
#include <memory>
#include <optional>
#include "common/CaptureStuff.h"

// Forward declaration of MacOSCaptureSCKit
#ifdef __APPLE__
class MacOSCaptureSCKit;
class MetalProcessor;
using DesktopCapture = MacOSCaptureSCKit;
using TextureProcessor = MetalProcessor;
#endif

class CompositeCapture {
public:
    CompositeCapture();  // Constructor
    ~CompositeCapture() = default; // Destructor

    // Add a screen capture by application name
    bool addCaptureByApplicationName(const std::string &applicationName, std::optional<DesktopCaptureArgs> args = std::nullopt);

    bool addWholeDesktopCapture(std::optional<DesktopCaptureArgs> args = std::nullopt);

    CaptureStatus queryCaptureStatus();

    // Start all captures
    bool startAllCaptures();

    // Stop all captures
    void stopAllCaptures();

    // Get the latest composite frame (returns a Metal texture pointer)
    void* getLatestCompositeFrame();

private:
    std::vector<std::shared_ptr<DesktopCapture>> m_captureSources;
    std::shared_ptr<TextureProcessor> m_textureProcessor;
};


#endif //HIDINGIN_COMPOSITECAPTURE_H

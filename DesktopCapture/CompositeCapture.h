//
// Created by 宾小康 on 2024/10/26.
//

#ifndef HIDINGIN_COMPOSITECAPTURE_H
#define HIDINGIN_COMPOSITECAPTURE_H
#include <vector>
#include <string>
#include <memory>
#include <optional>
#include <thread>
#include "common/CaptureStuff.h"
#include <map>

// Forward declaration of MacOSCaptureSCKit
#ifdef __APPLE__
class MacOSCaptureSCKit;
class MetalProcessor;
using DesktopCapture = MacOSCaptureSCKit;
using TextureProcessor = MetalProcessor;
#endif

struct CaptureFrameDesc{
    void* texId = nullptr;
    std::string captureEventName;
    std::function<void*(void* texId)> opsToBePerformBeforeComposition;
};

struct CompositeOrder{
    bool operator()(const int& lhs, const int& rhs) const {
        return lhs > rhs; // Sort in descending order
    }
};

class CompositeCapture {
public:
    CompositeCapture(std::optional<CompositeCaptureArgs> compCapArgs = std::nullopt);  // Constructor
    ~CompositeCapture(); // Destructor

    void cleanUp();

    // Add a screen capture by application name
    bool addCaptureByApplicationName(std::optional<CaptureArgs> args = std::nullopt);

    bool addWholeDesktopCapture(std::optional<CaptureArgs> args = std::nullopt);

    CaptureStatus queryCaptureStatus();

    // Start all captures
    bool startAllCaptures();

    // Stop all captures
    void stopAllCaptures();

    // Get the latest composite frame (returns a Metal texture pointer)
    void* getLatestCompositeFrame();

private:
    void compositeThreadFunc();
    int putFrameAndCompositeIfMeet(int order, const CaptureFrameDesc& captureFrameDesc);
    void waitForCompositeDone();

private:
    std::vector<std::shared_ptr<DesktopCapture>> m_captureSources;
    std::shared_ptr<TextureProcessor> m_textureProcessor;
    CompositeCaptureArgs m_compCapArgs;
    std::map<int, CaptureFrameDesc> m_captureFrameSet;
    std::thread m_compositeThread;
    std::atomic_bool m_stopAllWork = false;
    std::mutex m_framesSetMutex;
    std::condition_variable m_compositeCondVar;
    int m_capOrder = 0;
    int reqCompositeNum = 0;
    int frameIntervalInMilliSeconds = 16;
};


#endif //HIDINGIN_COMPOSITECAPTURE_H

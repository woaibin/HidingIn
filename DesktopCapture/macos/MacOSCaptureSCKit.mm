// ScreenCapture.mm

#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <MetalKit/MetalKit.h>
#include "MacOSCaptureSCKit.h"
#import <CoreMedia/CoreMedia.h>
#include <iostream>
#include "com/NotificationCenter.h"
#include "com/EventListener.h"
#include "platform/macos/MacUtils.h"
#include "../GPUPipeline/macos/MetalPipeline.h"

static void savePNG(CVImageBufferRef imageBuffer){
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    // Get the base address, width, height, and bytes per row of the image buffer
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);

    // Create a CGColorSpace for the BGRA format
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Create a CGContext with the BGRA pixel data
    CGContextRef context = CGBitmapContextCreate(baseAddress,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    // Create a CGImage from the context
    CGImageRef cgImage = CGBitmapContextCreateImage(context);

    // Save the CGImage as a PNG file
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"captured_frame.png"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];

    // Create a destination for the PNG file
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)fileURL, kUTTypePNG, 1, NULL);
    if (destination) {
        CGImageDestinationAddImage(destination, cgImage, NULL);
        CGImageDestinationFinalize(destination);
        CFRelease(destination);
    }

    // Clean up
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    CGContextRelease(context);
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);

    NSLog(@"Saved frame as PNG to %@", filePath);
}

@interface SCFrameReceiver : NSObject <SCStreamOutput,SCStreamDelegate>
@property (nonatomic) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) CVMetalTextureRef metalTextureRef;
@property (atomic) bool stopCapturing;
@property (atomic) bool stopped;
@property bool isDesktopCap;
@property std::string captureEventName;

- (void)stream:(SCStream *)stream
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        ofType:(SCStreamOutputType)type;
@end

@implementation SCFrameReceiver

- (instancetype)init {
    self = [super init];
    auto mtlDevice = (__bridge id<MTLDevice>)MetalPipeline::getGlobalInstance().getRenderPipeline().mtlDeviceRef;
    CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, mtlDevice, NULL, &_textureCache);
    EventRegisterParam eventRegisterParam;
    eventRegisterParam.type = EventType::General;
    eventRegisterParam.eventName = _captureEventName;
    EventManager::getInstance()->registerEvent(eventRegisterParam);

    return self;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if(self.stopCapturing){
        self.stopped = true;
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if(!CMSampleBufferIsValid(sampleBuffer) || !imageBuffer){
        return;
    }
    id<MTLTexture> newTexture = [self createTextureFromImage:imageBuffer];
    if (newTexture) {
        EventParam eventParam;
        eventParam.addParameter("textureId", (__bridge void*)newTexture);
        EventManager::getInstance()->triggerEvent(_captureEventName, eventParam);
    }
}

- (id<MTLTexture>)createTextureFromImage:(CVImageBufferRef)imageBuffer {
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    CVMetalTextureCacheFlush(self.textureCache, 0);
    if (_metalTextureRef) {
        CFRelease(_metalTextureRef);
        _metalTextureRef = NULL;
    }

    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                self.textureCache, imageBuffer,
                                                                NULL, MTLPixelFormatBGRA8Unorm,
                                                                width, height, 0, &_metalTextureRef);
    if (status != kCVReturnSuccess) {
        NSLog(@"Failed to create Metal texture from image");
        return nil;
    }

    return CVMetalTextureGetTexture(_metalTextureRef);
}

@end

enum CaptureMode{
    FullDesktopCapture,
    AppCapture
};

class MacOSCaptureSCKit::Impl {
private:
    SCFrameReceiver* frameReceiver = nullptr;
    SCStream *stream = nullptr;
    CaptureMode capMode = CaptureMode::FullDesktopCapture;
public:
    Impl() {}

    ~Impl() {
        stopCapture();
    }

    bool startCapture(std::optional<CaptureArgs> args = std::nullopt) {
        // Create a dispatch semaphore to wait for the completion handler
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        __block bool captureStarted = false;  // Use a block variable to capture the result

        // Use the async method to fetch shareable content
        [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                                   onScreenWindowsOnly:NO
                                                     completionHandler:^(SCShareableContent *content, NSError *error) {
             if (error) {
                 NSLog(@"Error: Unable to get shareable content: %@", error);
                 dispatch_semaphore_signal(semaphore);  // Signal the semaphore to unblock
                 return;
             }
             capMode = CaptureMode::FullDesktopCapture;
             // Select the main display for capture
             SCDisplay *display = content.displays.firstObject;
             if (!display) {
                 NSLog(@"Error: No display found.");
                 dispatch_semaphore_signal(semaphore);  // Signal the semaphore to unblock
                 return;
             }

             // Create a configuration for the capture stream
             SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
             Message windowMsg;
             auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
             auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();
             config.width = display.width * windowInfo->scalingFactor;
             config.height = display.height * windowInfo->scalingFactor;
             config.pixelFormat = kCVPixelFormatType_32BGRA;
             config.minimumFrameInterval = CMTimeMake(1, 60);
             config.queueDepth = 5;
             config.showsCursor = false;

             // traverse app info:
//             for (int i = 0; i < [content.applications count]; i++) {
//                 auto app = content.applications[i];
//                 NSLog(@"app name: %@", app.applicationName);  // Use %@ to print NSString objects
//             }

             // Set up the content filter for the display
             SCContentFilter *filter = nullptr;
             if(args.has_value() && !args->excludingWindowIDs.empty()){
                 // Create a mutable copy of the windows array
                 NSMutableArray<SCWindow *> *mutableWindows = [content.windows mutableCopy];
                 for (int i = (int)content.windows.count - 1; i >= 0; i--) {
                     SCWindow *window = content.windows[i];
                     // Check if windowID is in the vector of excluded IDs
                     if (std::find(args->excludingWindowIDs.begin(), args->excludingWindowIDs.end(), window.windowID) != args->excludingWindowIDs.end()) {
                         // Remove the window from the array
                         [mutableWindows removeObjectAtIndex:i];
                     }
                 }
                 filter = [[SCContentFilter alloc] initWithDisplay:display includingWindows:mutableWindows];
             }else{
                 filter = [[SCContentFilter alloc] initWithDisplay:display includingWindows:content.windows];
             }
             // Set up the stream
             frameReceiver = [SCFrameReceiver alloc];
             [frameReceiver setIsDesktopCap:capMode == CaptureMode::FullDesktopCapture];
             [frameReceiver init];
             stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:frameReceiver];
             dispatch_queue_t streamQueue = dispatch_queue_create("com.yourAppName.streamOutputQueue", DISPATCH_QUEUE_SERIAL);
             [stream addStreamOutput:frameReceiver type:SCStreamOutputTypeScreen sampleHandlerQueue:streamQueue error:&error];
             NSError *startError = nil;
             [stream startCaptureWithCompletionHandler:^( NSError *error){
                 if(error){
                     NSLog(@"Error: Unable to start stream capture: %@", startError);
                 }
             }];
             captureStarted = true;  // Capture succeeded, update the block variable
             // Signal the semaphore to unblock the waiting thread
             dispatch_semaphore_signal(semaphore);
         }];

        // Wait for the semaphore to be signaled (i.e., wait for the completion handler to finish)
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        // Return whether the capture was successfully started or not
        return captureStarted;
    }

    bool startCaptureWithApplicationName(std::string applicationName, std::string captureEventName) {
        // Create a dispatch semaphore to wait for the completion handler
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        __block bool captureStarted = false;  // Use a block variable to capture the result

        // Use the async method to fetch shareable content
        [SCShareableContent getShareableContentExcludingDesktopWindows:NO
               onScreenWindowsOnly:NO
                 completionHandler:^(SCShareableContent *content, NSError *error) {
                     if (error) {
                         NSLog(@"Error: Unable to get shareable content: %@", error);
                         dispatch_semaphore_signal(semaphore);  // Signal the semaphore to unblock
                         return;
                     }
                     capMode = CaptureMode::AppCapture;
                     // Select the main display for capture
                     SCDisplay *display = content.displays.firstObject;
                     if (!display) {
                         NSLog(@"Error: No display found.");
                         dispatch_semaphore_signal(semaphore);  // Signal the semaphore to unblock
                         return;
                     }

                     // traverse app info:
                     SCRunningApplication* targetApplication = nullptr;
                     NSString *targetAppName = [NSString stringWithUTF8String:applicationName.c_str()];
                     for (int i = 0; i < [content.applications count]; i++) {
                         auto app = content.applications[i];
                         if ([app.applicationName isEqualToString:targetAppName]) {
                             targetApplication = app;
                             NSLog(@"appCapture: capture app name: %@", app.applicationName);  // Use %@ to print NSString objects
                             break;
                         }
                     }
                     // Create a configuration for the capture stream
                     SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
                     Message windowMsg;
                     auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
                     auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();
                     if(capMode == CaptureMode::FullDesktopCapture){
                         config.width = display.width * windowInfo->scalingFactor;
                         config.height = display.height * windowInfo->scalingFactor;
                     }else{
                         config.width = display.width * windowInfo->scalingFactor;
                         config.height = display.height * windowInfo->scalingFactor;
                         auto size = getWindowSizesForPID(targetApplication.processID);
                         windowInfo->capturedAppX = std::get<0>(size) * windowInfo->scalingFactor;
                         windowInfo->capturedAppY = std::get<1>(size) * windowInfo->scalingFactor;
                         windowInfo->capturedAppWidth = std::get<2>(size) * windowInfo->scalingFactor;
                         windowInfo->capturedAppHeight = std::get<3>(size) * windowInfo->scalingFactor;
                         windowInfo->capturedWinId = std::get<4>(size);
                         windowInfo->appPid = targetApplication.processID;
                     }
                     config.pixelFormat = kCVPixelFormatType_32BGRA;
                     config.minimumFrameInterval = CMTimeMake(1, 60);
                     config.queueDepth = 5;
                     config.showsCursor = false;

                     // Set up the content filter for the display
                     NSArray<SCRunningApplication *> *applicationsArray = [NSArray arrayWithObjects:targetApplication, nil];
                     SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display includingApplications:applicationsArray exceptingWindows:@[]];
                     // Set up the stream
                     frameReceiver = [[SCFrameReceiver alloc] init];
                     [frameReceiver setCaptureEventName:captureEventName];
                     [frameReceiver setIsDesktopCap:capMode == CaptureMode::FullDesktopCapture];
                     stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:frameReceiver];
                     dispatch_queue_t streamQueue = dispatch_queue_create("com.yourAppName.streamOutputQueue", DISPATCH_QUEUE_SERIAL);
                     [stream addStreamOutput:frameReceiver type:SCStreamOutputTypeScreen sampleHandlerQueue:streamQueue error:&error];
                     NSError *startError = nil;
                     [stream startCaptureWithCompletionHandler:^( NSError *error){
                         if(error){
                             NSLog(@"Error: Unable to start stream capture: %@", startError);
                         }
                     }];
                     captureStarted = true;  // Capture succeeded, update the block variable
                     // Signal the semaphore to unblock the waiting thread
                     dispatch_semaphore_signal(semaphore);
                 }];

        // Wait for the semaphore to be signaled (i.e., wait for the completion handler to finish)
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        // Return whether the capture was successfully started or not
        return captureStarted;
    }

    void stopCapture() {
        [stream stopCaptureWithCompletionHandler:^( NSError *error){
            if(error){
                NSLog(@"Error: Unable to stop stream capture: %@", error);
            }else{
                [frameReceiver setStopCapturing:true];
                while(1){
                    if([frameReceiver stopped]){
                        break;
                    }
                    std::this_thread::sleep_for(std::chrono::milliseconds(20));
                }
            }
        }];

    }
};

MacOSCaptureSCKit::MacOSCaptureSCKit() {
    impl = new Impl();
}

MacOSCaptureSCKit::~MacOSCaptureSCKit() {
    delete impl;
}

bool MacOSCaptureSCKit::startCapture(std::optional<CaptureArgs> args) {
    captureStatus = CaptureStatus::Start;
    return impl->startCapture(args);
}

void MacOSCaptureSCKit::stopCapture() {
    captureStatus = CaptureStatus::Stop;
    impl->stopCapture();
}

bool MacOSCaptureSCKit::startCaptureWithApplicationName(std::string applicationName, std::optional<CaptureArgs> args) {
    captureStatus = CaptureStatus::Start;
    return impl->startCaptureWithApplicationName(applicationName, args->captureEventName);
}

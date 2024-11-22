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
@property (atomic) bool alreadyEnd;
@property std::string captureEventName;

- (void)stream:(SCStream *)stream
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        ofType:(SCStreamOutputType)type;
- (void)streamDidBecomeInactive:(SCStream *)stream;
- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error;
@end

@implementation SCFrameReceiver

- (instancetype)init {
    self = [super init];
    auto mtlDevice = (id<MTLDevice>)MetalPipeline::getGlobalInstance().getRenderPipeline().mtlDeviceRef;
    CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, mtlDevice, NULL, &_textureCache);
    EventRegisterParam eventRegisterParam;
    eventRegisterParam.type = EventType::General;
    eventRegisterParam.eventName = _captureEventName;
    EventManager::getInstance()->registerEvent(eventRegisterParam);
    _alreadyEnd = false;

    return self;
}

- (void)stream:(SCStream *)stream
didStopWithError:(NSError *)error{
    Message message;
    message.msgType = MessageType::Device;
    message.whatHappen = "CaptureDeviceInactive";
    std::cerr << "send inactive msg" << std::endl;
    NotificationCenter::getInstance().pushMessage(message);
    _alreadyEnd = true;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if(self.stopCapturing){
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if(!CMSampleBufferIsValid(sampleBuffer) || !imageBuffer){
        return;
    }
    id<MTLTexture> newTexture = [self createTextureFromImage:imageBuffer];
    if (newTexture) {
        EventParam eventParam;
        eventParam.addParameter("textureId", (void*)newTexture);
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
             //config.minimumFrameInterval = CMTimeMake(1, 25);
             config.queueDepth = 5;
             config.showsCursor = false;

             // Set up the content filter for the display
             SCContentFilter *filter = nullptr;
             NSMutableArray<SCRunningApplication*> *targetApps = [NSMutableArray array];
             if(args.has_value() && !args->excludingAppNames.empty()){
                 for (int i = 0; i < [content.applications count]; i++) {
                     auto app = content.applications[i];
                     // Convert NSString to std::string
                     std::string searchStdString = [app.applicationName UTF8String];
                     if (std::find(args->excludingAppNames.begin(), args->excludingAppNames.end(), searchStdString) != args->excludingAppNames.end()) {
                         [targetApps addObject:app];
                     }
                 }
             }else{
                 // traverse app info:
                 NSString *targetAppName = @"HidingIn";
                 SCRunningApplication* targetApplication = nullptr;
                 for (int i = 0; i < [content.applications count]; i++) {
                     auto app = content.applications[i];
                     if ([app.applicationName isEqualToString:targetAppName]) {
                         targetApplication = app;
                         NSLog(@"appCapture: capture app name: %@", app.applicationName);  // Use %@ to print NSString objects
                         break;
                     }
                 }
                 targetApps = [NSMutableArray arrayWithObjects:targetApplication, nil];

             }
             filter = [[SCContentFilter alloc] initWithDisplay:display excludingApplications:targetApps exceptingWindows:@[]];
             // Set up the stream
             frameReceiver = [SCFrameReceiver alloc];
             [frameReceiver setCaptureEventName:args->captureEventName];
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

    bool startCaptureWithWinId(CaptureArgs args) {
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

                     // Traverse app info:
                     NSMutableArray<SCWindow*> *capWindows = [[content.windows mutableCopy] autorelease];
                     for (int i = (int)[capWindows count] - 1; i >= 0; i--) {  // Start from the end and move backward
                         auto app = capWindows[i];
                         auto findResult = std::find(args.includingWindowIDs.begin(),
                                                     args.includingWindowIDs.end(), app.windowID);
                         if (findResult == args.includingWindowIDs.end()) {
                             [capWindows removeObjectAtIndex:i];  // Safely remove the element
                         }
                     }
                     // Create a configuration for the capture stream
                     SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
                     Message windowMsg;
                     auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
                     auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();

                     config.width = display.width * windowInfo->scalingFactor;
                     config.height = display.height * windowInfo->scalingFactor;
                     auto retRect = std::make_tuple(0,0,0,0);
                     getWindowGeometry(args.includingWindowIDs[0], retRect);
                     windowInfo->capturedAppX = std::get<0>(retRect) * windowInfo->scalingFactor;
                     windowInfo->capturedAppY = std::get<1>(retRect) * windowInfo->scalingFactor;
                     windowInfo->capturedAppWidth = std::get<2>(retRect) * windowInfo->scalingFactor;
                     windowInfo->capturedAppHeight = std::get<3>(retRect) * windowInfo->scalingFactor;
                     windowInfo->capturedWinId = args.includingWindowIDs[0];

                     config.pixelFormat = kCVPixelFormatType_32BGRA;
                     //config.minimumFrameInterval = CMTimeMake(1, 25);
                     config.queueDepth = 5;
                     config.showsCursor = false;

                     // Set up the content filter for the display
                     SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display includingWindows:capWindows];
                     // Set up the stream
                     frameReceiver = [SCFrameReceiver alloc];
                     [frameReceiver setCaptureEventName:args.captureEventName];
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

    bool startCaptureWithApplicationName(CaptureArgs args) {
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
                                                         NSString *targetAppName = [NSString stringWithUTF8String:args.captureAppName.c_str()];
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
                                                         config.width = display.width * windowInfo->scalingFactor;
                                                         config.height = display.height * windowInfo->scalingFactor;
                                                         config.pixelFormat = kCVPixelFormatType_32BGRA;
                                                         config.minimumFrameInterval = CMTimeMake(1, 60);
                                                         config.queueDepth = 5;
                                                         config.showsCursor = false;

                                                         config.width = display.width * windowInfo->scalingFactor;
                                                         config.height = display.height * windowInfo->scalingFactor;
                                                         auto retRect = std::make_tuple(0,0,0,0);
                                                         getWindowGeometry(args.includingWindowIDs[0], retRect);
                                                         windowInfo->capturedAppX = std::get<0>(retRect) * windowInfo->scalingFactor;
                                                         windowInfo->capturedAppY = std::get<1>(retRect) * windowInfo->scalingFactor;
                                                         windowInfo->capturedAppWidth = std::get<2>(retRect) * windowInfo->scalingFactor;
                                                         windowInfo->capturedAppHeight = std::get<3>(retRect) * windowInfo->scalingFactor;
                                                         windowInfo->capturedWinId = args.includingWindowIDs[0];
                                                         windowInfo->appPid = targetApplication.processID;

                                                         // Set up the content filter for the display
                                                         NSArray<SCRunningApplication *> *applicationsArray = [NSArray arrayWithObjects:targetApplication, nil];
                                                         SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display includingApplications:applicationsArray exceptingWindows:@[]];
                                                         // Set up the stream
                                                         frameReceiver = [SCFrameReceiver alloc];
                                                         [frameReceiver setCaptureEventName:args.captureEventName];
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

    void stopCapture() {
        // Create a dispatch semaphore to wait for the completion handler
        if([frameReceiver alreadyEnd]){
            return;
        }
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [stream stopCaptureWithCompletionHandler:^( NSError *error){
            if(error){
                NSLog(@"Error: Unable to stop stream capture: %@", error);
            }else{
                [frameReceiver setStopCapturing:true];
                dispatch_semaphore_signal(semaphore);
            }
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
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

bool MacOSCaptureSCKit::startCaptureWithSpecificWinId(std::optional<CaptureArgs> args) {
    captureStatus = CaptureStatus::Start;
    if(!args.has_value()){
        std::cerr << "cap args cannot be null" << std::endl;
        return false;
    }
    return impl->startCaptureWithApplicationName(args.value());
}

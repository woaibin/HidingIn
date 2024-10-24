// ScreenCapture.mm

#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <MetalKit/MetalKit.h>
#include "MacOSCaptureSCKit.h"
#import <CoreMedia/CoreMedia.h>
#include <iostream>
#include "../com/NotificationCenter.h"
#include "platform/macos/MacUtils.h"

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

// Function to calculate the centered CGRect for a window on a desktop
CGRect calculateRectForWindowAtPosition(CGSize desktopSize, CGSize windowSize, CGPoint windowPosition) {
    // Ensure the window fits within the desktop bounds by adjusting its position if necessary
    CGFloat x = fmax(0, fmin(windowPosition.x, desktopSize.width - windowSize.width));
    CGFloat y = fmax(0, fmin(windowPosition.y, desktopSize.height - windowSize.height));

    // Create a CGRect with the given position and window size
    CGRect windowRect = CGRectMake(x, y, windowSize.width, windowSize.height);

    return windowRect;
}

@interface SCFrameReceiver : NSObject <SCStreamOutput,SCStreamDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) CVMetalTextureRef metalTextureRef;
@property (nonatomic, strong) id<MTLTexture> mtlTexture;
@property (nonatomic, strong) id<MTLTexture> dupTexture;
@property (nonatomic, strong) id<MTLCommandBuffer> commandBuffer;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) NSLock *textureLock;
@property (atomic) bool stopCapturing;
@property (atomic) bool stopped;
@property bool isDesktopCap;

- (void)stream:(SCStream *)stream
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        ofType:(SCStreamOutputType)type;

// Thread-safe methods to get and set the mtlTexture and dupTexture
- (id<MTLTexture>)getMtlTexture;
- (void)setMtlTexture:(id<MTLTexture>)texture;
- (id<MTLTexture>)getDupTexture;
- (void)setDupTexture:(id<MTLTexture>)texture;

@end

@implementation SCFrameReceiver

- (instancetype)init {
    self = [super init];
    self.device = MTLCreateSystemDefaultDevice();
    CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, self.device, NULL, &_textureCache);
    if (self) {
        _textureLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)setMtlTexture:(id<MTLTexture>)texture {
    [self.textureLock lock];
    _mtlTexture = texture;
    [self.textureLock unlock];
}

- (id<MTLTexture>)getMtlTexture {
    id<MTLTexture> texture = nil;
    [self.textureLock lock];
    texture = _mtlTexture;
    [self.textureLock unlock];
    return texture;
}

- (void)setDupTexture:(id<MTLTexture>)texture {
    [self.textureLock lock];
    _dupTexture = texture;
    [self.textureLock unlock];
}

- (id<MTLTexture>)getDupTexture {
    id<MTLTexture> texture = nil;
    [self.textureLock lock];
    texture = _dupTexture;
    [self.textureLock unlock];
    return texture;
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
        Message windowMsg;
        auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
        auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();
        [self setMtlTexture:newTexture];

        if (![self getDupTexture] || windowInfo->needResizeForRender) {
            windowInfo->needResizeForRender = false;
            savePNG(imageBuffer);
            if(self.isDesktopCap){
                [self prepareDupTextureWithWidth:windowInfo->width * windowInfo->scalingFactor
                                          height:windowInfo->height * windowInfo->scalingFactor];
            }else{
                [self prepareDupTextureWithWidth:windowInfo->capturedAppWidth
                                          height:windowInfo->capturedAppHeight];
            }
        }

        if(self.isDesktopCap){
            [self copyTexture:[self getMtlTexture] toTexture:[self getDupTexture]
                            x:windowInfo->xPos * windowInfo->scalingFactor
                            y:windowInfo->yPos * windowInfo->scalingFactor
                       wWidth:windowInfo->width * windowInfo->scalingFactor
                      hHeight:windowInfo->height * windowInfo->scalingFactor];
        }else{
            auto cropRect = calculateRectForWindowAtPosition(CGSizeMake(newTexture.width, newTexture.height),
                                  CGSizeMake(windowInfo->capturedAppWidth, windowInfo->capturedAppHeight),
                                  CGPointMake(windowInfo->capturedAppX, windowInfo->capturedAppY));
            [self copyTexture:[self getMtlTexture] toTexture:[self getDupTexture]
                            x:cropRect.origin.x
                            y:cropRect.origin.y
                       wWidth:cropRect.size.width
                      hHeight:cropRect.size.height];
        }

        Message msg;
        msg.msgType = MessageType::Render;
        msg.whatHappen = "TimeToRender";
        NotificationCenter::getInstance().pushMessage(msg);
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

    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, imageBuffer, NULL, MTLPixelFormatBGRA8Unorm, width, height, 0, &_metalTextureRef);
    if (status != kCVReturnSuccess) {
        NSLog(@"Failed to create Metal texture from image");
        return nil;
    }

    return CVMetalTextureGetTexture(_metalTextureRef);
}

- (void)prepareDupTextureWithWidth:(NSUInteger)width height:(NSUInteger)height {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
    [self setDupTexture:texture];
}

- (void)copyTexture:(id<MTLTexture>)srcTexture toTexture:(id<MTLTexture>)dstTexture x:(int)windowX y:(int)windowY wWidth:(int)width hHeight:(int)height {
    if (!srcTexture || !dstTexture) {
        return;
    }

    if(!_commandQueue){
        _commandQueue = [self.device newCommandQueue];
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];

    [blitEncoder copyFromTexture:srcTexture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(windowX, windowY, 0) sourceSize:MTLSizeMake(width, height, 1) toTexture:dstTexture destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];

    [blitEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
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

    bool startCapture() {
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
             SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display includingWindows:content.windows];
             // Set up the stream
             frameReceiver = [[SCFrameReceiver alloc] init];
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

    bool startCaptureWithApplicationName(std::string applicationName){
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
                auto dupTexture = [frameReceiver getDupTexture];
                auto capTexture = [frameReceiver getMtlTexture];
                if(dupTexture){
                    CFRelease(dupTexture);
                    [frameReceiver setDupTexture:nullptr];
                }
                if(capTexture){
                    CFRelease(capTexture);
                    [frameReceiver setMtlTexture:nullptr];
                }
            }
        }];

    }

    id<MTLTexture> getLatestCaptureFrame() {
        return [frameReceiver getDupTexture];
    }
};

MacOSCaptureSCKit::MacOSCaptureSCKit() {
    impl = new Impl();
}

MacOSCaptureSCKit::~MacOSCaptureSCKit() {
    delete impl;
}

bool MacOSCaptureSCKit::startCapture() {
    captureStatus = CaptureStatus::Start;
    return impl->startCapture();
}

void MacOSCaptureSCKit::stopCapture() {
    captureStatus = CaptureStatus::Stop;
    impl->stopCapture();
}

void *MacOSCaptureSCKit::getLatestCaptureFrame() {
    // first thing first, dump out the image, and see if it matches the desktop:
    auto metalTexture = impl->getLatestCaptureFrame();
    return impl->getLatestCaptureFrame();
}

bool MacOSCaptureSCKit::startCaptureWithApplicationName(std::string applicationName) {
    captureStatus = CaptureStatus::Start;
    return impl->startCaptureWithApplicationName(applicationName);
}
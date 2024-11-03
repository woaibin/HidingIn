// MacosCapture.mm

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#include "MacosCapture.h"
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
                                                 8, // Bits per component (8 bits for each of R, G, B, A)
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
        // Add the image to the destination and finalize it
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

@interface AVFFrameReceiver : NSObject
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign ) CVMetalTextureRef metalTextureRef;
@property (nonatomic) id<MTLTexture> mtlTexture;
@property (nonatomic) id<MTLTexture> dupTexture; // New: Duplicate texture
// Lock for thread-safe access to mtlTexture and dupTexture
@property (nonatomic, strong) NSLock *textureLock;

- (void)  captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)videoFrame
         fromConnection:(AVCaptureConnection *)connection;

// Thread-safe methods to get and set the mtlTexture and dupTexture
- (id<MTLTexture>)getMtlTexture;
- (void)setMtlTexture:(id<MTLTexture>)texture;
- (id<MTLTexture>)getDupTexture;
- (void)setDupTexture:(id<MTLTexture>)texture;

@end

@implementation AVFFrameReceiver

// Initialize the object and create the lock
- (instancetype)init {
    self = [super init];
    self.device = MTLCreateSystemDefaultDevice();
    CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, self.device, NULL, &_textureCache);
    if (self) {
        _textureLock = [[NSLock alloc] init];
    }
    return self;
}

// Thread-safe setter for mtlTexture
- (void)setMtlTexture:(id<MTLTexture>)texture {
    [self.textureLock lock];
    _mtlTexture = texture;
    [self.textureLock unlock];
}

// Thread-safe getter for mtlTexture
- (id<MTLTexture>)getMtlTexture {
    id<MTLTexture> texture = nil;
    [self.textureLock lock];
    texture = _mtlTexture;
    [self.textureLock unlock];
    return texture;
}

// Thread-safe setter for dupTexture
- (void)setDupTexture:(id<MTLTexture>)texture {
    [self.textureLock lock];
    _dupTexture = texture;
    [self.textureLock unlock];
}

// Thread-safe getter for dupTexture
- (id<MTLTexture>)getDupTexture {
    id<MTLTexture> texture = nil;
    [self.textureLock lock];
    texture = _dupTexture;
    [self.textureLock unlock];
    return texture;
}

// Capture output and process frame
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)videoFrame
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(videoFrame);
    id<MTLTexture> newTexture = [self createTextureFromImage:imageBuffer];

    if (newTexture) {
        // Thread-safe set mtlTexture
        [self setMtlTexture:newTexture];

        // Prepare dupTexture if it's not already done
        if (![self getDupTexture]) {
            [self prepareDupTextureWithWidth:newTexture.width height:newTexture.height];
        }

        // Copy contents from mtlTexture to dupTexture
        [self copyTexture:[self getMtlTexture] toTexture:[self getDupTexture]];
    }
}

// Create a Metal texture from a CVImageBufferRef
- (id<MTLTexture>)createTextureFromImage:(CVImageBufferRef)imageBuffer {
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    // flush previously unused texture, free previous metal texture ref:
    CVMetalTextureCacheFlush(self.textureCache, 0);
    if(_metalTextureRef){
        CFRelease(_metalTextureRef);
        _metalTextureRef = NULL;
    }

    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                self.textureCache,
                                                                imageBuffer,
                                                                NULL,
                                                                MTLPixelFormatBGRA8Unorm,
                                                                width,
                                                                height,
                                                                0,
                                                                &_metalTextureRef);
    if (status != kCVReturnSuccess) {
        NSLog(@"Failed to create Metal texture from image");
        return nil;
    }

    return CVMetalTextureGetTexture(_metalTextureRef);
}

// Prepare dupTexture with the same size and format
- (void)prepareDupTextureWithWidth:(NSUInteger)width height:(NSUInteger)height {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                    width:width
                                                                                   height:height
                                                                                mipmapped:NO];
    id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
    [self setDupTexture:texture];
}

// Copy the contents from one texture to another
- (void)copyTexture:(id<MTLTexture>)srcTexture toTexture:(id<MTLTexture>)dstTexture {
    if (!srcTexture || !dstTexture) {
        return;
    }

    // Create a command buffer and blit encoder to perform the copy
    id<MTLCommandQueue> commandQueue = [self.device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];

    // Copy from srcTexture to dstTexture
    [blitEncoder copyFromTexture:srcTexture
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(srcTexture.width, srcTexture.height, 1)
                       toTexture:dstTexture
                destinationSlice:0
                destinationLevel:0
               destinationOrigin:MTLOriginMake(0, 0, 0)];

    // End encoding and commit the command buffer
    [blitEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

@end

class MacosCapture::Impl {
private:
    AVFFrameReceiver* frameReceiver = nullptr;
public:
    AVCaptureSession *captureSession;
    Impl() {
        captureSession = [[AVCaptureSession alloc] init];
    }

    ~Impl() {
        stopCapture();
        // let arc handle:
        //[captureSession release];
    }

    bool startCapture() {
        NSError *error = nil;

        // Get the main screen (display 0)
        AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:CGMainDisplayID()];

        if (!input) {
            NSLog(@"Error: Unable to create screen input.");
            return false;
        }
        input.capturesCursor = NO;
        input.capturesMouseClicks = NO;

        // configure output:
        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        if (!output){
            NSLog(@"Error: cant configure output.");
            return false;
        }

        // force bgra output:
        output.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};

        // set delegate:
        auto queue = dispatch_queue_create("avf_queue", NULL);
        frameReceiver = [[AVFFrameReceiver alloc]init];
        [output setSampleBufferDelegate:frameReceiver queue:queue];

        // set input:
        if ([captureSession canAddInput:input]) {
            [captureSession addInput:input];
        } else {
            NSLog(@"Error: Unable to add screen input to session.");
            return false;
        }


        // set output:
        if ([captureSession canAddOutput:output]) {
            [captureSession addOutput:output];
        } else {
            NSLog(@"Error: Unable to add screen output to session.");
            return false;
        }

        // Start the session
        [captureSession startRunning];
        return true;
    }

    void stopCapture() {
        if ([captureSession isRunning]) {
            [captureSession stopRunning];
        }
    }
};

MacosCapture::MacosCapture() {
    impl = new Impl();
}

MacosCapture::~MacosCapture() {
    delete impl;
}

bool MacosCapture::startCapture() {
    return impl->startCapture();
}

void MacosCapture::stopCapture() {
    impl->stopCapture();
}

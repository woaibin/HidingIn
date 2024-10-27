//
// Created by 宾小康 on 2024/10/26.
//

#include "CompositeCapture.h"
#include "QFile"
#ifdef __APPLE__
#include "macos/MacOSCaptureSCKit.h"
#include "Graphics/MetalProcessor.h"
#include "Metal/Metal.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <Foundation/Foundation.h>
#include <vector>
#endif

static void saveMTLTextureAsPNG(id<MTLTexture> texture) {
    if (!texture) {
        NSLog(@"Invalid texture!");
        return;
    }

    // Get the size and bytes per row of the texture
    NSUInteger width = texture.width;
    NSUInteger height = texture.height;
    NSUInteger bytesPerRow = width * 4;  // Assuming RGBA8Unorm (4 bytes per pixel)

    // Create a buffer to hold the texture data
    std::vector<uint8_t> textureData(height * bytesPerRow);

    // Define the region to read (the entire texture)
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);

    // Get the texture data into the buffer (assuming it's in the RGBA8Unorm format)
    [texture getBytes: textureData.data()
          bytesPerRow: bytesPerRow
           fromRegion: region
          mipmapLevel: 0];

    // Create a CGColorSpace for the RGBA format
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Create a CGContext with the RGBA pixel data
    CGContextRef context = CGBitmapContextCreate(textureData.data(),
                                                 width,
                                                 height,
                                                 8,                   // Bits per component (8 for uint8_t)
                                                 bytesPerRow,         // Bytes per row
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

    if (!context) {
        NSLog(@"Failed to create CGContext!");
        CGColorSpaceRelease(colorSpace);
        return;
    }

    // Create a CGImage from the context
    CGImageRef cgImage = CGBitmapContextCreateImage(context);

    // Get a temporary file path for the PNG
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"captured_texture.png"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];

    // Create a destination for the PNG file
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)fileURL, kUTTypePNG, 1, NULL);
    if (destination) {
        CGImageDestinationAddImage(destination, cgImage, NULL);
        CGImageDestinationFinalize(destination);
        CFRelease(destination);
    } else {
        NSLog(@"Failed to create image destination!");
    }

    // Clean up
    CGContextRelease(context);
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);

    NSLog(@"Saved texture as PNG to %@", filePath);
}

bool CompositeCapture::addCaptureByApplicationName(const std::string &applicationName, std::optional<DesktopCaptureArgs> args) {
    std::shared_ptr<DesktopCapture> captureSource = std::make_shared<DesktopCapture>();
    if(captureSource){
        captureSource->startCaptureWithApplicationName(applicationName);
        m_captureSources.push_back(captureSource);
    }else{
        return false;
    }
    return true;
}

void CompositeCapture::stopAllCaptures() {
    for(auto captureSource : m_captureSources){
        captureSource->stopCapture();
    }
}

void *CompositeCapture::getLatestCompositeFrame() {
    std::vector<void*> inputTextures;
    for(auto source : m_captureSources){
        auto tex = source->getLatestCaptureFrame();
        if(tex){
            inputTextures.push_back(tex);
        }
    }

    if(inputTextures.empty()){
        return nullptr;
    }

    auto retTex = m_textureProcessor->processTextures(inputTextures);

//    if(inputTextures[0]){
//        saveMTLTextureAsPNG((id<MTLTexture>)inputTextures[0]);
//    }

    return retTex;  // Return the composited frame (simplified)
}

bool CompositeCapture::addWholeDesktopCapture(std::optional<DesktopCaptureArgs> args) {
    std::shared_ptr<DesktopCapture> captureSource = std::make_shared<DesktopCapture>();
    if(captureSource){
        captureSource->startCapture(args);
        m_captureSources.push_back(captureSource);
    }else{
        return false;
    }
    return true;
}

CompositeCapture::CompositeCapture() {
    QFile shaderFile(":/shader/textureBlendHide.metal");
    if (!shaderFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        NSLog(@"Failed to open shader file at path: qrc:/shader/render.metal");
        return;
    }

    // Read the entire shader file content into a string
    QByteArray shaderContent = shaderFile.readAll();
    shaderFile.close();
    m_textureProcessor = std::make_shared<TextureProcessor>(shaderContent.constData(),"textureBlendHide");
}

CaptureStatus CompositeCapture::queryCaptureStatus() {
    for(auto& capSource : m_captureSources){
        if(capSource->getCaptureStatus() == CaptureStatus::Start){
            return CaptureStatus::Start;
        }
    }
    return CaptureStatus::Stop;
}

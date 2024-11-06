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
#include <com/NotificationCenter.h>
#include <com/EventListener.h>
#include "../GPUPipeline/macos/MetalPipeline.h"
#include "../utils/WindowLogic.h"
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

bool CompositeCapture::addCaptureByApplicationName(const std::string &applicationName, std::optional<CaptureArgs> args) {
    if(args == std::nullopt){
        std::cerr << "null capture args is not allowed..." << std::endl;
        return false;
    }
    std::shared_ptr<DesktopCapture> captureSource = std::make_shared<DesktopCapture>();
    if(captureSource){
        captureSource->startCaptureWithApplicationName(applicationName, args);


        // register capture event handler:
        EventManager::getInstance()->registerListener(args->captureEventName, [this](EventParam& eventParam){
            CaptureFrameDesc captureFrameDesc;
            captureFrameDesc.texId = std::get<void*>(eventParam.parameters["textureId"]);
            // for capture app, need to crop out the capture area:
            captureFrameDesc.opsToBePerformBeforeComposition = [&](void* texId){
                auto mtlTexture = (id<MTLTexture>)texId;

                Message windowMsg;
                auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
                auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();
                auto cropROI = calculateRectForWindowAtPosition(WindowSize(mtlTexture.width, mtlTexture.height),
                                                                WindowSize(windowInfo->capturedAppWidth, windowInfo->capturedAppHeight),
                                                                WindowPoint(windowInfo->capturedAppX, windowInfo->capturedAppY));

                auto &renderPipeline = MetalPipeline::getGlobalInstance().getRenderPipeline();
                // crop out the app area;
                {
                    REQUEST_TEXTURE(windowInfo->capturedAppWidth,
                                    windowInfo->capturedAppHeight,
                                    mtlTexture.pixelFormat, renderPipeline.mtlDeviceRef);
                    MtlProcessMisc::getGlobalInstance().encodeCropProcessIntoPipeline(
                            std::make_tuple(cropROI.x, cropROI.y, cropROI.width, cropROI.height),
                            texId, retTexture, renderPipeline.mtlCommandBuffer);
                }

                // scale to match window if necessary:
                if(windowInfo->capturedAppWidth != windowInfo->width || windowInfo->capturedAppHeight != windowInfo->height)
                {
                    REQUEST_TEXTURE(windowInfo->width,
                                    windowInfo->height,
                                    mtlTexture.pixelFormat, renderPipeline.mtlDeviceRef);
                    MtlProcessMisc::getGlobalInstance().encodeScaleProcessIntoPipeline(texId, retTexture, renderPipeline.mtlCommandBuffer);
                }
            };
            m_framesSetMutex.lock();
            m_captureFrameSet.insert({m_capOrder++, captureFrameDesc});
            m_framesSetMutex.unlock();
        });

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
    m_captureSources.clear();
}

void *CompositeCapture::getLatestCompositeFrame() {
    return nullptr;
}

bool CompositeCapture::addWholeDesktopCapture(std::optional<CaptureArgs> args) {
    std::shared_ptr<DesktopCapture> captureSource = std::make_shared<DesktopCapture>();
    if(captureSource){
        captureSource->startCapture(args);

        // register capture event handler:
        EventManager::getInstance()->registerListener(args->captureEventName, [this](EventParam& eventParam){
            CaptureFrameDesc captureFrameDesc;
            captureFrameDesc.texId = std::get<void*>(eventParam.parameters["textureId"]);
            // for capture app, need to crop out the capture area:
            captureFrameDesc.opsToBePerformBeforeComposition = [&](void* texId){
                auto mtlTexture = (id<MTLTexture>)texId;

                Message windowMsg;
                auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
                auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();

                auto &renderPipeline = MetalPipeline::getGlobalInstance().getRenderPipeline();
                REQUEST_TEXTURE(windowInfo->width,
                                windowInfo->height,
                                mtlTexture.pixelFormat, renderPipeline.mtlDeviceRef);

                auto cropTuple = std::make_tuple(windowInfo->xPos * windowInfo->scalingFactor,
                                                 windowInfo->yPos * windowInfo->scalingFactor,
                                                 windowInfo->width * windowInfo->scalingFactor,
                                                 windowInfo->height * windowInfo->scalingFactor);
                MtlProcessMisc::getGlobalInstance().encodeCropProcessIntoPipeline(
                        cropTuple, texId, retTexture, renderPipeline.mtlCommandBuffer);
            };
            m_framesSetMutex.lock();
            m_captureFrameSet.insert(std::make_pair(m_capOrder++, captureFrameDesc));
            m_framesSetMutex.unlock();
        });
        m_captureSources.push_back(captureSource);
    }else{
        return false;
    }
    return true;
}

CompositeCapture::CompositeCapture(std::optional<CompositeCaptureArgs> compCapArgs)
        : m_compositeThread(&CompositeCapture::compositeThreadFunc, this)
{
    if(compCapArgs.has_value()){
        m_compCapArgs = compCapArgs.value();
    }
}

CaptureStatus CompositeCapture::queryCaptureStatus() {
    for(auto& capSource : m_captureSources){
        if(capSource->getCaptureStatus() == CaptureStatus::Start){
            return CaptureStatus::Start;
        }
    }
    return CaptureStatus::Stop;
}

void CompositeCapture::compositeThreadFunc() {
    while(!m_stopAllWork){
        std::vector<int> consumeVec;
        auto execFuture = MetalPipeline::getGlobalInstance().sendJobToRenderQueue(
                [&](const std::string& threadName, const MtlRenderPipeline& renderPipelineRes){
            if(m_captureFrameSet.size() < m_compCapArgs.reqCompositeNum){
                return;
            }

            Message windowMsg;
            auto windowMsgResult = NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, windowMsg);
            auto windowInfo = (WindowSubMsg*)windowMsg.subMsg.get();
            void* lastTexId = nullptr;
            m_framesSetMutex.lock();
            for(auto& it : m_captureFrameSet){
                consumeVec.push_back(it.first);
                // will finally match the result size of the result to the window size:
                auto texIdMtl = (id<MTLTexture>)it.second.texId;
                if(lastTexId){
                    // apply high pass:
                    REQUEST_TEXTURE(texIdMtl.width, texIdMtl.height, texIdMtl.pixelFormat, renderPipelineRes.mtlDeviceRef);
                    MtlProcessMisc::getGlobalInstance().encodeGaussianProcessIntoPipeline((void*)texIdMtl,
                                                                                          retTexture,
                                                                                          renderPipelineRes.mtlCommandBuffer);
                    REQUEST_TEXTURE_ANOTHER(texIdMtl.width, texIdMtl.height,
                                            texIdMtl.pixelFormat, renderPipelineRes.mtlDeviceRef);
                    MtlProcessMisc::getGlobalInstance().encodeSubtractProcessIntoPipeline((void*)texIdMtl,
                                                                                          retTexture,
                                                                                          retTextureAnother,
                                                                                          renderPipelineRes.mtlCommandBuffer);

                    // apply hiding filter:
                    std::vector<void*> inputTextures;
                    inputTextures.push_back(lastTexId);
                    inputTextures.push_back(retTextureAnother);
                    // since it renders to the final render target, so we need not to do anything then.
                    auto renderTarget = MetalPipeline::getGlobalInstance().
                            throughRenderingPipelineState("hidingShader", inputTextures);
                }else{
                    if (m_compCapArgs.reqCompositeNum == 1){
                        // if only there's only one frame, we just render the texture to the scene
                        std::vector<void*> inputTextures;
                        inputTextures.push_back(texIdMtl);
                        auto renderTarget = MetalPipeline::getGlobalInstance().
                                throughRenderingPipelineState("basicRenderShader", inputTextures);
                    }else{
                        lastTexId = (void*)texIdMtl;
                    }
                }
            }
            m_captureFrameSet.clear();
            m_framesSetMutex.unlock();
        });
        if(execFuture.valid()){
            execFuture.get();
        }
    }
}

CompositeCapture::~CompositeCapture() {
    m_stopAllWork = true;
    if(m_compositeThread.joinable()){
        m_compositeThread.join();
    }
}

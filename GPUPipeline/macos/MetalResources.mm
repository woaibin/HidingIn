//
// Created by 宾小康 on 2024/11/1.
//

#include "MetalResources.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <unordered_map>

void MtlProcessMisc::initAllProcessors(void* mtlDevice) {
    m_mtlDevice = mtlDevice;
    auto convertMtlDevice = TO_MTL_DEVICE(CFBridgingRelease(mtlDevice));
    m_imageCropFilter = (__bridge void*)[[MPSUnaryImageKernel alloc]initWithDevice:convertMtlDevice];
    m_imageGaussianFilter = (__bridge void*)[[MPSImageGaussianBlur alloc] initWithDevice:convertMtlDevice sigma: 5.0f];
    m_imageScaleFilter = (__bridge void*)[[MPSImageScale alloc] initWithDevice: convertMtlDevice];
    m_imageSubtractFilter = (__bridge void*)[[MPSImageSubtract alloc] initWithDevice: convertMtlDevice];
}

// Encode Crop Process
void MtlProcessMisc::encodeCropProcessIntoPipeline(std::tuple<int, int, int, int> cropROI, void* input,
                                                   void* output, void* commandBuffer) {
    std::lock_guard<std::mutex> cropLock(m_cropMutex);
    auto convertInput = (id<MTLTexture>)CFBridgingRelease(input);
    auto convertOutput = (id<MTLTexture>)CFBridgingRelease(output);
    auto convertCommandBuffer = (id<MTLCommandBuffer>)CFBridgingRelease(commandBuffer);
    auto cropFilter = TO_MPS_UNARY_IMAGE_KERNEL(CFBridgingRelease(m_imageCropFilter));

    // Extract crop region from the tuple:
    int x, y, width, height;
    std::tie(x, y, width, height) = cropROI;
    cropFilter.clipRect.origin = MTLOriginMake(x, y, 0);
    cropFilter.clipRect.size = MTLSizeMake(width, height, 0);
    // Encode the crop process:
    [cropFilter encodeToCommandBuffer: convertCommandBuffer sourceTexture:convertInput destinationTexture:convertOutput];
}

// Encode Scale Process
void MtlProcessMisc::encodeScaleProcessIntoPipeline(void* input, void* output,
                                                    void* commandBuffer) {
    std::lock_guard<std::mutex> scaleLock(m_scaleMutex);
    auto convertInput = (id<MTLTexture>)CFBridgingRelease(input);
    auto convertOutput = (id<MTLTexture>)CFBridgingRelease(output);
    auto convertCommandBuffer = (id<MTLCommandBuffer>)CFBridgingRelease(commandBuffer);
    auto imageScale = TO_MPS_IMAGE_BILINEAR_SCALE(CFBridgingRelease(m_imageScaleFilter));

    MPSScaleTransform scaleTransform;
    scaleTransform.scaleX = (double)convertOutput.width / convertInput.width;   // Horizontal scaling factor
    scaleTransform.scaleY = (double)convertOutput.height / convertInput.height; // Vertical scaling factor
    scaleTransform.translateX = 0.0; // No horizontal translation
    scaleTransform.translateY = 0.0; // No vertical translation
    [imageScale setScaleTransform:&scaleTransform];

    // Encode the scale process
    [imageScale encodeToCommandBuffer:convertCommandBuffer
                        sourceTexture:convertInput
                   destinationTexture:convertOutput];
}

// Encode Gaussian Blur Process
void MtlProcessMisc::encodeGaussianProcessIntoPipeline(void* input, void* output, void* commandBuffer) {
    std::lock_guard<std::mutex> gaussianLock(m_GaussianMutex);

    auto convertInput = (id<MTLTexture>)CFBridgingRelease(input);
    auto convertOutput = (id<MTLTexture>)CFBridgingRelease(output);
    auto convertCommandBuffer = (id<MTLCommandBuffer>)CFBridgingRelease(commandBuffer);

    // Encode the Gaussian blur process
    [TO_MPS_IMAGE_GAUSSIAN(CFBridgingRelease(m_imageGaussianFilter)) encodeToCommandBuffer:convertCommandBuffer
                                                          sourceTexture:convertInput
                                                     destinationTexture:convertOutput];
}

// Encode Subtract Process
void MtlProcessMisc::encodeSubtractProcessIntoPipeline(void* input1, void* input2, void* output, void* commandBuffer) {
    std::lock_guard<std::mutex> subtractLock(m_SubtractMutex);

    auto convertInput1 = (id<MTLTexture>)CFBridgingRelease(input1);
    auto convertInput2 = (id<MTLTexture>)CFBridgingRelease(input2);
    auto convertOutput = (id<MTLTexture>)CFBridgingRelease(output);
    auto convertCommandBuffer = (id<MTLCommandBuffer>)CFBridgingRelease(commandBuffer);

    // Encode the subtract process
    [TO_MPS_IMAGE_SUBTRACT(CFBridgingRelease(m_imageSubtractFilter)) encodeToCommandBuffer:convertCommandBuffer
            primaryTexture:convertInput1
                           secondaryTexture:convertInput2
                           destinationTexture:convertOutput];
}

TextureResource &MtlTextureManager::requestTexture(std::string findId, int width, int height, int format, void* mtlDevice) {
    auto mtlDeviceOC = TO_MTL_DEVICE(CFBridgingRelease(mtlDevice));
    std::lock_guard<std::mutex> textureOpLock(m_textureOpMutex);

    auto createOneFunc = [=](){
        MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)format
                                                                                                     width:width
                                                                                                    height:height
                                                                                                 mipmapped:NO];
        return [mtlDeviceOC newTextureWithDescriptor:textureDescriptor];
    };

    auto findResult = m_textureMaps.find(findId);
    if(findResult != m_textureMaps.end()){
        auto mtlTex = (id<MTLTexture>)CFBridgingRelease(findResult->second.texturePtr);
        if(mtlTex.width != width || mtlTex.height != height || mtlTex.pixelFormat != format){
            // recreate one:
            createOneFunc();
        }
        return findResult->second;
    }

    // not found suitable, create one:
    TextureResource res;
    res.texturePtr = (__bridge void*)createOneFunc();
    auto insertItem = m_textureMaps.insert({findId, res});

    return insertItem.first->second;
}

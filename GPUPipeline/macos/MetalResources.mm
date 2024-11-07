//
// Created by 宾小康 on 2024/11/1.
//

#include "MetalResources.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <unordered_map>

void MtlProcessMisc::initAllProcessors(void* mtlDevice) {
    bool isInit = m_mtlDevice != nullptr;
    m_mtlDevice = mtlDevice;
    if(!isInit){
        auto convertMtlDevice = TO_MTL_DEVICE(mtlDevice);
        m_imageCropFilter = (void*)[[MPSImageLanczosScale alloc]initWithDevice:convertMtlDevice];
        m_imageGaussianFilter = (void*)[[MPSImageGaussianBlur alloc] initWithDevice:convertMtlDevice sigma: 5.0f];
        m_imageScaleFilter = (void*)[[MPSImageBilinearScale alloc] initWithDevice: convertMtlDevice];
        m_imageSubtractFilter = (void*)[[MPSImageSubtract alloc] initWithDevice: convertMtlDevice];
    }
}

// Encode Crop Process
void MtlProcessMisc::encodeCropProcessIntoPipeline(std::tuple<int, int, int, int> cropROI, void* input,
                                                   void* output, void* commandQueue) {
    std::lock_guard<std::mutex> cropLock(m_cropMutex);
    auto convertInput = (id<MTLTexture>)input;
    auto convertOutput = (id<MTLTexture>)output;
    auto convertCommandQueue = (id<MTLCommandQueue>)commandQueue;
    auto commandBuffer = [convertCommandQueue commandBuffer];
    auto cropFilter = TO_MPS_CROP_FILTER(m_imageCropFilter);

    int x, y, width, height;
    std::tie(x, y, width, height) = cropROI;

    MPSScaleTransform scaleTransform;
    scaleTransform.scaleX = 1;   // Horizontal scaling factor
    scaleTransform.scaleY = 1; // Vertical scaling factor
    scaleTransform.translateX = -x  * scaleTransform.scaleX ; // No horizontal translation
    scaleTransform.translateY = -y  * scaleTransform.scaleY; // No vertical translation
    [cropFilter setScaleTransform:&scaleTransform];

    MTLRegion cropRegion;
    cropRegion.origin = MTLOriginMake(0, 0, 0);
    cropRegion.size = MTLSizeMake(width, height, 1);
    [cropFilter setClipRect:cropRegion];

    // Encode the crop process:
    [cropFilter encodeToCommandBuffer: commandBuffer sourceTexture:convertInput destinationTexture:convertOutput];
    [commandBuffer commit];
}

// Encode Scale Process
void MtlProcessMisc::encodeScaleProcessIntoPipeline(void* input, void* output,
                                                    void* commandQueue) {
    std::lock_guard<std::mutex> scaleLock(m_scaleMutex);
    auto convertInput = (id<MTLTexture>)input;
    auto convertOutput = (id<MTLTexture>)output;
    auto convertCommandQueue = (id<MTLCommandQueue>)commandQueue;
    auto commandBuffer = [convertCommandQueue commandBuffer];
    auto imageScale = TO_MPS_IMAGE_BILINEAR_SCALE(m_imageScaleFilter);

    MPSScaleTransform scaleTransform;
    scaleTransform.scaleX = (double)convertOutput.width / convertInput.width;   // Horizontal scaling factor
    scaleTransform.scaleY = (double)convertOutput.height / convertInput.height; // Vertical scaling factor
    scaleTransform.translateX = 0.0; // No horizontal translation
    scaleTransform.translateY = 0.0; // No vertical translation
    [imageScale setScaleTransform:&scaleTransform];
    
    
    // Encode the scale process
    [imageScale encodeToCommandBuffer:commandBuffer
                        sourceTexture:convertInput
                   destinationTexture:convertOutput];
}

// Encode Gaussian Blur Process
void MtlProcessMisc::encodeGaussianProcessIntoPipeline(void* input, void* output, void* commandQueue) {
    std::lock_guard<std::mutex> gaussianLock(m_GaussianMutex);

    auto convertInput = (id<MTLTexture>)input;
    auto convertOutput = (id<MTLTexture>)output;
    auto convertCommandQueue = (id<MTLCommandQueue>)commandQueue;
    auto commandBuffer = [convertCommandQueue commandBuffer];

    // Encode the Gaussian blur process
    [TO_MPS_IMAGE_GAUSSIAN(m_imageGaussianFilter) encodeToCommandBuffer:commandBuffer
                                                          sourceTexture:convertInput
                                                     destinationTexture:convertOutput];
}

// Encode Subtract Process
void MtlProcessMisc::encodeSubtractProcessIntoPipeline(void* input1, void* input2, void* output, void* commandQueue) {
    std::lock_guard<std::mutex> subtractLock(m_SubtractMutex);

    auto convertInput1 = (id<MTLTexture>)input1;
    auto convertInput2 = (id<MTLTexture>)input2;
    auto convertOutput = (id<MTLTexture>)output;
    auto convertCommandQueue = (id<MTLCommandQueue>)commandQueue;
    auto commandBuffer = [convertCommandQueue commandBuffer];

    // Encode the subtract process
    [TO_MPS_IMAGE_SUBTRACT(m_imageSubtractFilter) encodeToCommandBuffer:commandBuffer
            primaryTexture:convertInput1
                           secondaryTexture:convertInput2
                           destinationTexture:convertOutput];
}

TextureResource &MtlTextureManager::requestTexture(std::string findId, int width, int height, int format, void* mtlDevice) {
    auto mtlDeviceOC = TO_MTL_DEVICE(mtlDevice);
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
        auto mtlTex = (id<MTLTexture>)findResult->second.texturePtr;
        if(mtlTex.width != width || mtlTex.height != height || mtlTex.pixelFormat != format){
            // recreate one:
            createOneFunc();
        }
        return findResult->second;
    }

    // not found suitable, create one:
    TextureResource res;
    res.texturePtr = (void*)createOneFunc();
    auto insertItem = m_textureMaps.insert({findId, res});

    return insertItem.first->second;
}

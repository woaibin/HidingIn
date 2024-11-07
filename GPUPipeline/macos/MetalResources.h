//
// Created by 宾小康 on 2024/10/30.
//

#ifndef HIDINGIN_METALRESOURCES_H
#define HIDINGIN_METALRESOURCES_H

#include <memory>
#include "vector"
#include <mutex>
#include <string>

#define TO_MTL_DEVICE(DEVICE_OPAQUE) (id<MTLDevice>)DEVICE_OPAQUE
#define TO_MTL_COMMAND_QUEUE(QUEUE_OPAQUE) (id<MTLCommandQueue>)QUEUE_OPAQUE
#define TO_MTL_COMMAND_BUFFER(COMMAND_BUFFER) (id<MTLCommandBuffer>)COMMAND_BUFFER
#define TO_MTL_PIPELINE_STATE(PIPELINE_STATES) (id<MTLRenderPipelineState>)PIPELINE_STATES
#define TO_MPS_UNARY_IMAGE_KERNEL(IMG_KERNEL) (MPSUnaryImageKernel*)IMG_KERNEL
#define TO_MPS_IMAGE_BILINEAR_SCALE(IMG_BILINEAR) (MPSImageBilinearScale*)IMG_BILINEAR
#define TO_MPS_CROP_FILTER(IMG_CROP) (MPSImageLanczosScale*)IMG_CROP
#define TO_MPS_IMAGE_GAUSSIAN(IMG_GAUSSIAN) (MPSImageGaussianBlur*)IMG_GAUSSIAN
#define TO_MPS_IMAGE_SUBTRACT(IMG_SUBTRACT) (MPSImageSubtract*)IMG_SUBTRACT
struct MtlRenderPipeline{
    void* mtlDeviceRef;
    void* mtlCommandQueue;
    void* mtlCommandBuffer;
    void* mtlRenderCommandEncoder;
    void* mtlRenderPassDesc;
    std::unordered_map<std::string, void*> mtlPipelineStates;
    void* vertexBuffer;
    void* renderTarget;
};

struct MtlComputePipeline{
    void* mtlDeviceRef;
    void* mtlCommandQueue;
    void* mtlCommandBuffer;
    void* mtlComputeCommandEncoder;
    std::unordered_map<std::string, void*> mtlPipelineStates;
};

struct MtlBlitPipeline{
    void* mtlDeviceRef;
    void* mtlCommandQueue;
    void* mtlCommandBuffer;
    void* mtlBlitCommandEncoder;
};

struct TextureResource{
    void* texturePtr = nullptr;
};

// texture request helper, it will create a 'retTexture' in place.
#define REQUEST_TEXTURE(width, height, format, mtlDevice) \
    void* retTexture = nullptr;                                       \
    do {                                                   \
        std::string fileName = __FILE__;                   \
        std::string funName = __func__;                    \
        std::string lineName = std::to_string(__LINE__);        \
        auto finalFindId = fileName + "-" + funName + "-" + lineName; \
        retTexture = MtlTextureManager::getGlobalInstance()           \
        .requestTexture(finalFindId, width, height, format, mtlDevice).texturePtr; \
    } while (0)

// texture request helper, it will create a 'retTextureAnother' in place.
#define REQUEST_TEXTURE_ANOTHER(width, height, format, mtlDevice) \
    void* retTextureAnother = nullptr;                                       \
    do {                                                   \
        std::string fileName = __FILE__;                   \
        std::string funName = __func__;                    \
        std::string lineName = std::to_string(__LINE__);        \
        auto finalFindId = fileName + "-" + funName + "-" + lineName; \
        retTextureAnother = MtlTextureManager::getGlobalInstance()           \
        .requestTexture(finalFindId, width, height, format, mtlDevice).texturePtr; \
    } while (0)
class MtlTextureManager{
private:
    std::unordered_map<std::string, TextureResource> m_textureMaps;
    std::mutex m_textureOpMutex;

public:
    static MtlTextureManager& getGlobalInstance(){
        static MtlTextureManager textureManager;
        return textureManager;
    }

    TextureResource& requestTexture(std::string findId, int width, int height, int format, void* mtlDevice);
private:
    MtlTextureManager() = default;

public:
    MtlTextureManager(const MtlTextureManager&) = delete;
    MtlTextureManager& operator=(const MtlTextureManager&) = delete;
    MtlTextureManager(MtlTextureManager&&) = delete;
    MtlTextureManager& operator=(MtlTextureManager&&) = delete;
};

class MtlProcessMisc{
public:
    static MtlProcessMisc& getGlobalInstance(){
        static MtlProcessMisc processMisc;
        return processMisc;
    }
    void initAllProcessors(void* mtlDevice);
    void encodeCropProcessIntoPipeline(std::tuple<int, int, int, int> cropROI, void* input,
                                       void* output, void* commandBuffer);
    void encodeScaleProcessIntoPipeline(void* input, void* output, void* commandBuffer);
    void encodeGaussianProcessIntoPipeline(void* input, void* output, void* commandBuffer);
    void encodeSubtractProcessIntoPipeline(void* input1, void* input2, void* output, void* commandBuffer);

private:
    // Private constructor to prevent external instantiation
    MtlProcessMisc() = default;

public:
    MtlProcessMisc(const MtlProcessMisc&) = delete;
    MtlProcessMisc& operator=(const MtlProcessMisc&) = delete;
    MtlProcessMisc(MtlProcessMisc&&) = delete;
    MtlProcessMisc& operator=(MtlProcessMisc&&) = delete;

private:
    void* m_mtlDevice = nullptr;
    void* m_imageCropFilter = nullptr;
    void* m_imageScaleFilter = nullptr;
    void* m_imageGaussianFilter = nullptr;
    void* m_imageSubtractFilter = nullptr;

    std::mutex m_cropMutex;
    std::mutex m_scaleMutex;
    std::mutex m_GaussianMutex;
    std::mutex m_SubtractMutex;
};

#endif //HIDINGIN_METALRESOURCES_H

//
// Created by 宾小康 on 2024/10/29.
//

#include "MetalPipeline.h"
#import <Metal/Metal.h>
#import "MetalKit/MetalKit.h"
#include "../com/NotificationCenter.h"

MetalPipeline::MetalPipeline() {
    std::vector<std::string> vecRenderThreadPool = { "renderQueue" };
    std::vector<std::string> vecComputeThreadPool = { "computeQueue1", "computeQueue2"};
    std::vector<std::string> vecBlitThreadPool = { "blitQueue1", "blitQueue2" };
    m_renderingPipelineTasks = std::make_unique<TaskQueue>(1, vecRenderThreadPool, 10, true);
    m_computePipelineTasks = std::make_unique<TaskQueue>(2, vecComputeThreadPool, 20);
    m_blitPipelineTasks = std::make_unique<TaskQueue>(1, vecBlitThreadPool, 10);
}

void MetalPipeline::initGlobalMetalPipeline(PipelineConfiguration &pipelineInitConfiguration) {
    auto& inst = getGlobalInstance();
    inst.prepRenderPipeline(pipelineInitConfiguration);
    inst.prepComputePipeline(pipelineInitConfiguration);
    inst.prepBlitPipeline(pipelineInitConfiguration);
    inst.isInit = true;
    EventManager::getInstance()->triggerEvent("gpuPipelineInit", EventParam());
}

std::future<void> MetalPipeline::sendJobToRenderQueue(const GpuRenderTask& renderTask) {
    auto retFuture = m_renderingPipelineTasks->enqueueTask([=, this](const std::string& threadName) {
        renderTask(threadName, m_mtlRenderPipeline);
    });

    // need to trigger update rendering to qt:
    if(!triggerRenderUpdateFunc){
        std::cerr << "warning, trigger render update function is not valid..." << std::endl;
        return retFuture;
    }

    triggerRenderUpdateFunc();
    return retFuture;
}

std::future<void> MetalPipeline::sendJobToComputeQueue(const GpuComputeTask& computeTask) {
    return m_renderingPipelineTasks->enqueueTask([=, this](const std::string& threadName){
       computeTask(threadName, m_mtlComputePipeline);
    });
}

std::future<void> MetalPipeline::sendJobToBlitQueue(const GpuBlitTask &blitTask) {
    return m_blitPipelineTasks->enqueueTask([=, this](const std::string& threadName){
        blitTask(threadName, m_blitPipeline);
    });
}

void MetalPipeline::prepRenderPipeline(PipelineConfiguration& pipelineInitConfiguration, bool isUpdate) {
    auto mtlDeviceOC = TO_MTL_DEVICE(CFBridgingRelease(pipelineInitConfiguration.graphicsDevice));
    m_mtlRenderPipeline.mtlDeviceRef = (__bridge void*)mtlDeviceOC;

    // qquick got its own render command queue and buffer, we should get from it:
    m_mtlRenderPipeline.mtlCommandBuffer = pipelineInitConfiguration.mtlRenderCommandBuffer;
    m_mtlRenderPipeline.mtlCommandQueue = pipelineInitConfiguration.mtlRenderCommandQueue;
    m_mtlRenderPipeline.mtlRenderCommandEncoder = pipelineInitConfiguration.mtlRenderCommandEncoder;
    m_mtlRenderPipeline.mtlRenderPassDesc = pipelineInitConfiguration.mtlRenderPassDesc;

    if(isUpdate){
        return;
    }

    // prep vertices:
    {
        // Define the vertices (position and color)
        static const float quadVertices[] = {
                -1.0,  1.0, 0.0, 1.0,  // top left
                1.0,  1.0, 1.0, 1.0,  // top right
                -1.0, -1.0, 0.0, 0.0,  // bottom left
                1.0, -1.0, 1.0, 0.0   // bottom right
        };
        // Create the vertex buffer, storing the vertex data
        m_mtlRenderPipeline.vertexBuffer = (__bridge void*) [mtlDeviceOC newBufferWithBytes:quadVertices
                                                     length:sizeof(quadVertices)
                                                    options:MTLResourceStorageModeShared];
    }

    // prep shaders, pipeline states:
    {
        for(auto& shaderDesc : pipelineInitConfiguration.renderShaders){
            NSString *shaderSource = [NSString stringWithUTF8String:shaderDesc.shaderContent.c_str()];
            NSString *vertFunc = [NSString stringWithUTF8String:shaderDesc.functionToGoVert.c_str()];
            NSString *fragFunc = [NSString stringWithUTF8String:shaderDesc.functionToGoFrag.c_str()];
            if (!shaderSource) {
                NSLog(@"Failed to read shader source from: qrc:/shader/render.metal");
                return;
            }

            NSError *error = nil;
            id<MTLLibrary> library = [(id<MTLDevice>)mtlDeviceOC newLibraryWithSource:shaderSource options:nil error:&error];
            if (!library) {
                NSLog(@"Failed to compile shader library: %@", error);
                return;
            }

            id<MTLFunction> vertexFunction = [library newFunctionWithName:vertFunc];
            id<MTLFunction> fragmentFunction = [library newFunctionWithName:fragFunc];

            // Create a render pipeline descriptor and set up the shaders
            MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
            pipelineDescriptor.vertexFunction = vertexFunction;
            pipelineDescriptor.fragmentFunction = fragmentFunction;
            pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            pipelineDescriptor.colorAttachments[0].blendingEnabled = false;
            pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            pipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;

            auto pipelineState = [mtlDeviceOC newRenderPipelineStateWithDescriptor:pipelineDescriptor error: &error];
            m_mtlRenderPipeline.mtlPipelineStates.insert({shaderDesc.shaderDesc, (__bridge void*)pipelineState});
        }
    }

//    // here, we create our own render target, and present it in the qt scene graph rendering:
//    Message msg;
//    NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
//    auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
//    MTLTextureDescriptor *desc = [[MTLTextureDescriptor alloc] init];
//    desc.textureType = MTLTextureType2D;
//    desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
//    desc.width = windowInfo->width;
//    desc.height = windowInfo->height;
//    desc.mipmapLevelCount = 1;
//    desc.resourceOptions = MTLResourceStorageModePrivate;
//    desc.storageMode = MTLStorageModePrivate;
//    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
//    m_renderTarget = (__bridge void*)[mtlDeviceOC newTextureWithDescriptor: desc];
}

void MetalPipeline::prepComputePipeline(PipelineConfiguration& pipelineInitConfiguration) {
    auto mtlDeviceOC = TO_MTL_DEVICE(pipelineInitConfiguration.graphicsDevice);
    m_mtlComputePipeline.mtlDeviceRef = (__bridge void*)mtlDeviceOC;

    // qquick got its own render command queue and buffer, we should get from it:
    m_mtlComputePipeline.mtlCommandQueue =
            (__bridge void*)[mtlDeviceOC newCommandQueue];
    m_mtlComputePipeline.mtlCommandBuffer =
            (__bridge void*)
                    [TO_MTL_COMMAND_QUEUE(CFBridgingRelease(m_mtlComputePipeline.mtlCommandQueue)) commandBuffer];
    m_mtlComputePipeline.mtlComputeCommandEncoder =
            (__bridge void*)
                    [TO_MTL_COMMAND_BUFFER(CFBridgingRelease(m_mtlComputePipeline.mtlCommandBuffer)) computeCommandEncoder];

    // prep shaders, pipeline states:
    {
        for(auto& shaderDesc : pipelineInitConfiguration.computeShaders){
            NSString *shaderSource = [NSString stringWithUTF8String:shaderDesc.shaderContent.c_str()];
            NSString *computeFunc = [NSString stringWithUTF8String:shaderDesc.functionToGoCompute.c_str()];
            if (!shaderSource) {
                NSLog(@"Failed to read shader source from: qrc:/shader/render.metal");
                return;
            }

            NSError *error = nil;
            id<MTLLibrary> library = [(id<MTLDevice>)mtlDeviceOC newLibraryWithSource:shaderSource options:nil error:&error];
            if (!library) {
                NSLog(@"Failed to compile shader library: %@", error);
                return;
            }

            id<MTLFunction> computeShaderProcFunc = [library newFunctionWithName:computeFunc];

            auto pipelineState = [mtlDeviceOC newComputePipelineStateWithFunction:computeShaderProcFunc error: &error];
            m_mtlComputePipeline.mtlPipelineStates.insert({shaderDesc.shaderDesc, (__bridge void*)pipelineState});
        }
    }
}

void MetalPipeline::prepBlitPipeline(PipelineConfiguration& pipelineInitConfiguration) {
    auto mtlDeviceOC = TO_MTL_DEVICE(CFBridgingRelease(pipelineInitConfiguration.graphicsDevice));
    m_blitPipeline.mtlDeviceRef = (__bridge void*)mtlDeviceOC;

    // qquick got its own render command queue and buffer, we should get from it:
    m_blitPipeline.mtlCommandQueue = (__bridge void*)[mtlDeviceOC newCommandQueue];
    m_blitPipeline.mtlCommandBuffer = (__bridge void*)[TO_MTL_COMMAND_QUEUE(CFBridgingRelease(m_blitPipeline.mtlCommandQueue)) commandBuffer];
    m_blitPipeline.mtlBlitCommandEncoder = (__bridge void*)[TO_MTL_COMMAND_BUFFER(CFBridgingRelease(m_blitPipeline.mtlCommandBuffer)) blitCommandEncoder];
}

void MetalPipeline::executeAllRenderTasksInPlace() {
    m_renderingPipelineTasks->execAllTasksInPlace();
}

void MetalPipeline::setTriggerRenderUpdateFunc(std::function<void()> func) {
    triggerRenderUpdateFunc = func;
}

void MetalPipeline::updateRenderPipelineRes(PipelineConfiguration & pipelineConfiguration) {
    prepRenderPipeline(pipelineConfiguration, true);
}

MtlBlitPipeline &MetalPipeline::getBlitPipeline() {
    return m_blitPipeline;
}

MtlComputePipeline &MetalPipeline::getComputePipeline() {
    return m_mtlComputePipeline;
}

MtlRenderPipeline &MetalPipeline::getRenderPipeline() {
    return m_mtlRenderPipeline;
}


void* MetalPipeline::throughRenderingPipelineState(std::string pipelineDesc, std::vector<void*>& inputTextures) {
    auto pipelineState = (__bridge id<MTLRenderPipelineState>)m_mtlRenderPipeline.mtlPipelineStates[pipelineDesc];
    auto encoder = (__bridge id<MTLRenderCommandEncoder>)m_mtlRenderPipeline.mtlRenderCommandEncoder;
    auto renderPassDesc = (MTLRenderPassDescriptor*)CFBridgingRelease(m_mtlRenderPipeline.mtlRenderPassDesc);
    [encoder setVertexBuffer:(__bridge id <MTLBuffer>)(m_mtlRenderPipeline.vertexBuffer) offset:0 atIndex:0];
    for(auto i = 0; i < inputTextures.size(); i++){
        [encoder setFragmentTexture:(__bridge id<MTLTexture>)inputTextures[i] atIndex: i];
    }
    [encoder setRenderPipelineState:pipelineState];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];
    [encoder endEncoding];

    // return output renderTarget:
    return (__bridge void*)renderPassDesc.colorAttachments[0].texture;
}

void MetalPipeline::throughComputePipelineState(std::string pipelineDesc, std::vector<void*>& inputTextures, void* resultTexture) {
    auto pipelineState = (__bridge id<MTLComputePipelineState>) m_mtlComputePipeline.mtlPipelineStates[pipelineDesc];
    auto encoder = (__bridge id<MTLComputeCommandEncoder>)m_mtlComputePipeline.mtlCommandBuffer;
    [encoder setComputePipelineState:pipelineState];
    for(auto i = 0; i< inputTextures.size(); i++){
        [encoder setTexture:(__bridge id<MTLTexture>)inputTextures[i] atIndex:i];
    }

    // Bind the output texture
    [encoder setTexture:(__bridge id<MTLTexture>)resultTexture atIndex:(int)inputTextures.size()];

    // Configure thread groups and grid size based on the first texture (assuming they are the same size)
    // The texture size (assuming all input textures are the same size)
    NSUInteger width = ((__bridge id<MTLTexture>)resultTexture).width;
    NSUInteger height = ((__bridge id<MTLTexture>)resultTexture).height;

    // Get the maximum allowed threads per threadgroup for this compute pipeline
    NSUInteger maxThreadsPerThreadgroup = pipelineState.maxTotalThreadsPerThreadgroup;

    // Get the thread execution width (the number of threads per threadgroup that can execute in parallel)
    NSUInteger threadExecutionWidth = pipelineState.threadExecutionWidth;

    // Calculate an optimal threadgroup size based on the texture size and hardware limits
    MTLSize threadGroupSize = MTLSizeMake(threadExecutionWidth, maxThreadsPerThreadgroup / threadExecutionWidth, 1);

    // Ensure that the grid size covers the entire texture by calculating the number of threadgroups needed
    MTLSize gridSize = MTLSizeMake(width,
                                   height, 1);

    // Dispatch the compute shader
    [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];

    [encoder endEncoding];
}

void MetalPipeline::throughBlitPipelineState(void *inputTexture, void *outputTexture) {
    // Convert the input and output texture pointers to MTLTexture objects.
    auto inputTex = (__bridge id<MTLTexture>)inputTexture;
    auto outputTex = (__bridge id<MTLTexture>)outputTexture;

    // Create the blit command encoder from the stored command encoder.
    auto blitEncoder = (__bridge id<MTLBlitCommandEncoder>)m_blitPipeline.mtlBlitCommandEncoder;
    auto blitCommandBuffer = (__bridge id<MTLCommandBuffer>)m_blitPipeline.mtlCommandBuffer;

    // Ensure the textures have the same size, otherwise the operation will fail.
    MTLSize textureSize = MTLSizeMake(inputTex.width, inputTex.height, inputTex.depth);

    // Perform the copy operation from inputTexture to outputTexture.
    [blitEncoder copyFromTexture:inputTex
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:textureSize
                       toTexture:outputTex
                destinationSlice:0
                destinationLevel:0
               destinationOrigin:MTLOriginMake(0, 0, 0)];

    // End encoding (this finalizes the blit operation).
    [blitEncoder endEncoding];
    [blitCommandBuffer commit];
    [blitCommandBuffer waitUntilCompleted];
}

void MetalPipeline::registerInitDoneHandler(std::function<void()> initDoneFunc) {
    EventManager::getInstance()->registerListener("gpuPipelineInit", [=](EventParam& eventParam){
        initDoneFunc();
    });
}

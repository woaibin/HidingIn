//
// Created by 宾小康 on 2024/10/29.
//

#include "MetalPipeline.h"
#import <Metal/Metal.h>
#import "MetalKit/MetalKit.h"
#include "../com/NotificationCenter.h"
#include <future>

MetalPipeline::MetalPipeline() {
    std::vector<std::string> vecRenderThreadPool = { "renderQueue" };
    std::vector<std::string> vecComputeThreadPool = { "computeQueue1", "computeQueue2"};
    std::vector<std::string> vecBlitThreadPool = { "blitQueue1", "blitQueue2" };
    m_renderingPipelineTasks = std::make_unique<TaskQueue>(1, vecRenderThreadPool, 10);
    m_computePipelineTasks = std::make_unique<TaskQueue>(2, vecComputeThreadPool, 20);
    m_blitPipelineTasks = std::make_unique<TaskQueue>(1, vecBlitThreadPool, 10);
}

void MetalPipeline::initGlobalMetalPipeline(PipelineConfiguration &pipelineInitConfiguration) {
    auto& inst = getGlobalInstance();
    inst.prepRenderPipeline(pipelineInitConfiguration);
    MtlProcessMisc::getGlobalInstance().initAllProcessors(pipelineInitConfiguration.graphicsDevice);

    //getGlobalInstance().prepComputePipeline(pipelineInitConfiguration);
    //getGlobalInstance().prepBlitPipeline(pipelineInitConfiguration);
}

std::future<void> MetalPipeline::sendJobToRenderQueue(const GpuRenderTask& renderTask) {
    // need to trigger update rendering to qt:
    auto retFuture = m_renderingPipelineTasks->enqueueTask([=, this](const std::string& threadName) {
        renderTask(threadName, m_mtlRenderPipeline);
    });

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
    auto mtlDeviceOC = TO_MTL_DEVICE(pipelineInitConfiguration.graphicsDevice);
    m_mtlRenderPipeline.mtlDeviceRef = (void*)mtlDeviceOC;
    
    if(isUpdate){
        return;
    }
    
    // prep basic res
    {
        auto commandQueue =[mtlDeviceOC newCommandQueue];
        m_mtlRenderPipeline.mtlCommandQueue = (void*) commandQueue;
    }

    // prep vertices:
    {
        // Define the vertices (position and color)
        static const float quadVertices[] = {
                -1.0,  1.0, 0.0, 0.0,  // top left
                1.0,  1.0, 1.0, 0.0,  // top right
                -1.0, -1.0, 0.0, 1.0,  // bottom left
                1.0, -1.0, 1.0, 1.0   // bottom right
        };
        // Create the vertex buffer, storing the vertex data
        m_mtlRenderPipeline.vertexBuffer = (void*) [mtlDeviceOC newBufferWithBytes:quadVertices
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
            pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
            pipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;

            auto pipelineState = [mtlDeviceOC newRenderPipelineStateWithDescriptor:pipelineDescriptor error: &error];
            m_mtlRenderPipeline.mtlPipelineStates.insert({shaderDesc.shaderDesc, (void*)pipelineState});
        }
    }
}

void MetalPipeline::prepComputePipeline(PipelineConfiguration& pipelineInitConfiguration) {
    auto mtlDeviceOC = MTLCreateSystemDefaultDevice();
    m_mtlComputePipeline.mtlDeviceRef = (void*)mtlDeviceOC;

    // qquick got its own render command queue and buffer, we should get from it:
    auto commandQueue = [mtlDeviceOC newCommandQueue];
    m_mtlComputePipeline.mtlCommandQueue =
            (void*)commandQueue;

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
            m_mtlComputePipeline.mtlPipelineStates.insert({shaderDesc.shaderDesc, (void*)pipelineState});
        }
    }
    m_mtlComputePipeline.mtlCommandBuffer =
            (void*)
                    [commandQueue commandBuffer];
    m_mtlComputePipeline.mtlComputeCommandEncoder =
            (void*)
                    [TO_MTL_COMMAND_BUFFER(m_mtlComputePipeline.mtlCommandBuffer) computeCommandEncoder];
}

void MetalPipeline::prepBlitPipeline(PipelineConfiguration& pipelineInitConfiguration) {
    auto mtlDeviceOC = TO_MTL_DEVICE(pipelineInitConfiguration.graphicsDevice);
    m_blitPipeline.mtlDeviceRef = (void*)mtlDeviceOC;
    auto commandQueue = [mtlDeviceOC newCommandQueue];
    // qquick got its own render command queue and buffer, we should get from it:
    m_blitPipeline.mtlCommandQueue = (void*)commandQueue;
    m_blitPipeline.mtlCommandBuffer = (void*)[commandQueue commandBuffer];
    m_blitPipeline.mtlBlitCommandEncoder = (void*)[TO_MTL_COMMAND_BUFFER(m_blitPipeline.mtlCommandBuffer) blitCommandEncoder];
}

void MetalPipeline::executeAllRenderTasksInPlace() {
    m_renderingPipelineTasks->execAllTasksInPlace();
}

void MetalPipeline::setTriggerRenderUpdateFunc(std::function<void()> func) {
    m_triggerRenderUpdateFunc = func;
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
    auto findPipelineState = m_mtlRenderPipeline.mtlPipelineStates.find(pipelineDesc);
    if(findPipelineState == m_mtlRenderPipeline.mtlPipelineStates.end()){
        return {};
    }
    auto pipelineState = (id<MTLRenderPipelineState>)findPipelineState->second;

    auto renderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    m_mtlRenderPipeline.mtlRenderPassDesc = renderPassDesc;
    renderPassDesc.colorAttachments[0].texture = (id<MTLTexture>)m_mtlRenderPipeline.renderTarget;
    renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0);
    renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

    auto commandQueue =(id<MTLCommandQueue>)m_mtlRenderPipeline.mtlCommandQueue;
    auto commandBuffer = [commandQueue commandBuffer];
    auto encoder = [commandBuffer
                    renderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDesc];

    Message msg;
    NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
    auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
    MTLViewport vp;
    vp.originX = 0;
    vp.originY = 0;
    vp.width = windowInfo->width * windowInfo->scalingFactor;
    vp.height = windowInfo->height  * windowInfo->scalingFactor;
    vp.znear = 0;
    vp.zfar = 1;

    [encoder setViewport: vp];

    [encoder setVertexBuffer:(id <MTLBuffer>)(m_mtlRenderPipeline.vertexBuffer) offset:0 atIndex:0];
    for(auto i = 0; i < inputTextures.size(); i++){
        [encoder setFragmentTexture:(id<MTLTexture>)inputTextures[i] atIndex: i];
    }
    [encoder setRenderPipelineState:pipelineState];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];

    [encoder endEncoding];
    
    [commandBuffer commit];
    
    m_triggerRenderUpdateFunc();

    // return output renderTarget:
    return (void*)renderPassDesc.colorAttachments[0].texture;
}

void MetalPipeline::throughComputePipelineState(std::string pipelineDesc, std::vector<void*>& inputTextures, void* resultTexture) {
    auto pipelineState = (id<MTLComputePipelineState>) m_mtlComputePipeline.mtlPipelineStates[pipelineDesc];
    auto encoder = (id<MTLComputeCommandEncoder>)m_mtlComputePipeline.mtlCommandBuffer;
    [encoder setComputePipelineState:pipelineState];
    for(auto i = 0; i< inputTextures.size(); i++){
        [encoder setTexture:(id<MTLTexture>)inputTextures[i] atIndex:i];
    }

    // Bind the output texture
    [encoder setTexture:(id<MTLTexture>)resultTexture atIndex:(int)inputTextures.size()];

    // Configure thread groups and grid size based on the first texture (assuming they are the same size)
    // The texture size (assuming all input textures are the same size)
    NSUInteger width = ((id<MTLTexture>)resultTexture).width;
    NSUInteger height = ((id<MTLTexture>)resultTexture).height;

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
    auto inputTex = (id<MTLTexture>)inputTexture;
    auto outputTex = (id<MTLTexture>)outputTexture;

    // Create the blit command encoder from the stored command encoder.
    auto blitEncoder = (id<MTLBlitCommandEncoder>)m_blitPipeline.mtlBlitCommandEncoder;
    auto blitCommandBuffer = (id<MTLCommandBuffer>)m_blitPipeline.mtlCommandBuffer;

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
    EventManager::getInstance()->registerListener("gpuRenderPipelineInit", [=](EventParam& eventParam){
        initDoneFunc();
    });
}

void MetalPipeline::cleanUp() {
    m_renderingPipelineTasks.reset();
    m_computePipelineTasks.reset();
    m_blitPipelineTasks.reset();
}

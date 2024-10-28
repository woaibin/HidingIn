#import "MetalProcessor.h"
#import "MetalKit/MetalKit.h"
#include <MetalPerformanceShaders/MetalPerformanceShaders.h>

MetalProcessor::MetalProcessor(const char* shaderBuffer, const std::string& functionName) {
    // Initialize the Metal device and command queue
    device = MTLCreateSystemDefaultDevice();
    if (!device) {
        std::cerr << "Failed to create Metal device!" << std::endl;
        return;
    }
    commandQueue = [(id<MTLDevice>)device newCommandQueue];

    // Load shader from the provided path
    if (!loadShaderFromPath(shaderBuffer, functionName)) {
    }
}

MetalProcessor::~MetalProcessor() {
    // Metal objects are reference-counted and automatically released
}

bool MetalProcessor::loadShaderFromPath(const char* shaderBuffer, const std::string& functionName) {
    NSError *error = nil;

    // Load the shader source from the provided file path
    NSString *shaderSource = [NSString stringWithUTF8String:shaderBuffer];
    if (error) {
        std::cerr << "Error reading shader file: " << [[error localizedDescription] UTF8String] << std::endl;
        return false;
    }

    // Create a Metal library from the shader source
    id<MTLLibrary> library = [(id<MTLDevice>)device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!library || error) {
        std::cerr << "Failed to create library from shader source: " << [[error localizedDescription] UTF8String] << std::endl;
        return false;
    }

    // Get the compute shader function from the library
    id<MTLFunction> function = [library newFunctionWithName:[NSString stringWithUTF8String:functionName.c_str()]];
    if (!function) {
        std::cerr << "Failed to find compute shader function: " << functionName << std::endl;
        return false;
    }

    // Create the compute pipeline state
    computePipelineState = [(id<MTLDevice>)device newComputePipelineStateWithFunction:function error:&error];
    if (!computePipelineState || error) {
        std::cerr << "Failed to create compute pipeline state: " << [[error localizedDescription] UTF8String] << std::endl;
        return false;
    }

    return true;
}

void* MetalProcessor::processTextures(const std::vector<void*>& inputTextures) {
    if (inputTextures.empty()) {
        std::cerr << "No textures provided for processing!" << std::endl;
        return nil;
    }

    // Lazily create the output texture based on the first input texture's format and size, if not already created
    if (!outputTexture) {
        outputTexture = createOutputTexture(inputTextures[0]);
    }
    auto outputMTLTex =(id<MTLTexture>)outputTexture;
    auto pipeLineState = (id<MTLComputePipelineState>)computePipelineState;

    // Create a command buffer and a compute command encoder
    id<MTLCommandBuffer> commandBuffer = [(id<MTLCommandQueue>)commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

    // Set the compute pipeline state
    [encoder setComputePipelineState:(id<MTLComputePipelineState>)computePipelineState];

    // Bind all input textures to the shader
    for (int i = 0; i < inputTextures.size(); ++i) {
        [encoder setTexture:(id<MTLTexture>)inputTextures[i] atIndex:i];
    }

    // Configure thread groups and grid size based on the first texture (assuming they are the same size)
    // The texture size (assuming all input textures are the same size)
    NSUInteger width = outputMTLTex.width;
    NSUInteger height = outputMTLTex.height;

    // Bind the output texture
    [encoder setTexture:outputMTLTex atIndex:(int)inputTextures.size()];

    // Get the maximum allowed threads per threadgroup for this compute pipeline
    NSUInteger maxThreadsPerThreadgroup = pipeLineState.maxTotalThreadsPerThreadgroup;

    // Get the thread execution width (the number of threads per threadgroup that can execute in parallel)
    NSUInteger threadExecutionWidth = pipeLineState.threadExecutionWidth;

    // Calculate an optimal threadgroup size based on the texture size and hardware limits
    MTLSize threadGroupSize = MTLSizeMake(threadExecutionWidth, maxThreadsPerThreadgroup / threadExecutionWidth, 1);

    // Ensure that the grid size covers the entire texture by calculating the number of threadgroups needed
    MTLSize gridSize = MTLSizeMake(width,
                                   height, 1);

    // Dispatch the compute shader
    [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];
    [encoder endEncoding];

    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        if (commandBuffer.error) {
            // If there was an error in the command buffer execution
            NSLog(@"Command buffer execution failed with error: %@", commandBuffer.error);
        }
    }];

    // Commit the command buffer and wait for the GPU to complete the task
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    // Return the processed output texture
    return outputTexture;
}

void *MetalProcessor::createOutputTexture(void *referenceTexture) {
    // Create a texture descriptor based on the reference texture (typically the first input texture)
    auto mtlInputTex = (id<MTLTexture>)referenceTexture;
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlInputTex.pixelFormat
                                                                                                 width:mtlInputTex.width
                                                                                                height:mtlInputTex.height
                                                                                             mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

    // Create the output texture only the first time this method is called
    outputTexture = [(id<MTLDevice>)device newTextureWithDescriptor:textureDescriptor];
    outputTexture2 = [(id<MTLDevice>)device newTextureWithDescriptor:textureDescriptor];
    if (!outputTexture) {
        std::cerr << "Failed to create output texture!" << std::endl;
    }
    if (!outputTexture2) {
        std::cerr << "Failed to create output texture2!" << std::endl;
    }
    return outputTexture;
}

void *MetalProcessor::createScaleTextureWithWidthAndHeight(void *refTex, int width, int height) {
    // Create a texture descriptor based on the reference texture (typically the first input texture)
    auto mtlInputTex = (id<MTLTexture>)refTex;
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlInputTex.pixelFormat
                                                                                                 width:width
                                                                                                height:height
                                                                                             mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

    // Create the output texture only the first time this method is called
    scaleTexture = [(id<MTLDevice>)device newTextureWithDescriptor:textureDescriptor];
    if (!scaleTexture) {
        std::cerr << "Failed to create output texture!" << std::endl;
    }
    return scaleTexture;
}

void *MetalProcessor::applyGaussianBlur(void *inputTexture, float sigma) {
    MPSImageGaussianBlur* gaussianBlur = [[MPSImageGaussianBlur alloc] initWithDevice:static_cast<id <MTLDevice>>(device) sigma:sigma];
    id<MTLCommandBuffer> commandBuffer = [(id<MTLCommandQueue>)commandQueue commandBuffer];

    if(!outputTexture){
        createOutputTexture(inputTexture);
    }

    auto blurredTexture = (id<MTLTexture>)outputTexture;

    [gaussianBlur encodeToCommandBuffer:commandBuffer sourceTexture:(id<MTLTexture>)inputTexture destinationTexture:blurredTexture];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    return blurredTexture;
}

void *MetalProcessor::applyImageSubtraction(void *originalTexture, void *blurredTexture) {
    MPSImageSubtract* subtract = [[MPSImageSubtract alloc] initWithDevice:static_cast<id <MTLDevice>>(device)];
    id<MTLCommandBuffer> commandBuffer = [(id<MTLCommandQueue>)commandQueue commandBuffer];

    if(!outputTexture2){
        createOutputTexture(originalTexture);
    }

    auto highPassTexture = (id<MTLTexture>)outputTexture2;

    [subtract encodeToCommandBuffer:commandBuffer primaryTexture:(id<MTLTexture>)originalTexture secondaryTexture:(id<MTLTexture>)blurredTexture destinationTexture:highPassTexture];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    return highPassTexture;
}

void *MetalProcessor::applyHighPassFilter(void *inputTexture) {
    auto inputMtlTexture = (__bridge id<MTLTexture>)inputTexture;
    // Step 1: Apply Gaussian blur (low-pass filter)
    float blurSigma = 10.0f; // Adjust based on desired low-pass strength
    auto blurredTexture = static_cast<id <MTLTexture>>(applyGaussianBlur(inputTexture, blurSigma));

    // Step 2: Subtract blurred image from original to get high-pass filtered image
    auto highPassTexture = static_cast<id <MTLTexture>>(applyImageSubtraction(inputTexture, blurredTexture));

    return (__bridge void*)highPassTexture;
}

void *MetalProcessor::applyScale(void *inputTexture, int outputWidth, int outputHeight) {
    MPSImageBilinearScale* imgScale = [[MPSImageBilinearScale alloc] initWithDevice:static_cast<id <MTLDevice>>(device)];
    auto inputMtlTex = (id<MTLTexture>)inputTexture;
    // finish this:
    MPSScaleTransform scaleTransform;
    scaleTransform.scaleX = (double)outputWidth / inputMtlTex.width;   // Horizontal scaling factor
    scaleTransform.scaleY = (double)outputHeight / inputMtlTex.height; // Vertical scaling factor
    scaleTransform.translateX = 0.0; // No horizontal translation
    scaleTransform.translateY = 0.0; // No vertical translation
    [imgScale setScaleTransform:&scaleTransform];
    id<MTLCommandBuffer> commandBuffer = [(id<MTLCommandQueue>)commandQueue commandBuffer];

    if(!scaleTexture){
        createScaleTextureWithWidthAndHeight(inputTexture, outputWidth, outputHeight);
    }

    auto scaleTex = (id<MTLTexture>)scaleTexture;

    [imgScale encodeToCommandBuffer:commandBuffer sourceTexture:(id<MTLTexture>)inputTexture destinationTexture:scaleTex];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    return scaleTex;
}
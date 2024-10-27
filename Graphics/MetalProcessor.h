#ifndef METAL_PROCESSOR_H
#define METAL_PROCESSOR_H

#include <iostream>
#include <string>
class MetalProcessor {
public:
    MetalProcessor(const char* shaderBuffer, const std::string& functionName);
    ~MetalProcessor();

    // Process the input texture using the compute shader
    void* processTextures(const std::vector<void*>& inputTextures);

private:
    /*id<MTLDevice>*/void* device;
    /*id<MTLCommandQueue>*/void* commandQueue;
    /*id<MTLComputePipelineState>*/void* computePipelineState;
    /*id<MTLTexture>*/void* outputTexture;  // Lazily created output texture


    bool loadShaderFromPath(const char* shaderBuffer, const std::string& functionName);

    void* createOutputTexture(void* referenceTexture);  // Helper to create output texture
};

#endif // METAL_PROCESSOR_H
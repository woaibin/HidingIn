#ifndef METAL_PROCESSOR_H
#define METAL_PROCESSOR_H

#include <iostream>
#include <string>
#import <QSGDynamicTexture>
#import <QSGTexture>

class MetalProcessor {
public:
    MetalProcessor(const char* shaderBuffer, const std::string& functionName);
    ~MetalProcessor();

    // Process the input texture using the compute shader
    void* processTextures(const std::vector<void*>& inputTextures);

    void* applyHighPassFilter(void* inputTexture);
    void* applyScale(void* inputTexture, int outputWidth, int outputHeight);

private:
    /*id<MTLDevice>*/void* device;
    /*id<MTLCommandQueue>*/void* commandQueue;
    /*id<MTLComputePipelineState>*/void* computePipelineState;
    /*id<MTLTexture>*/void* outputTexture;  // Lazily created output texture
    /*id<MTLTexture>*/void* outputTexture2;  // Lazily created output texture
    /*id<MTLTexture>*/void* scaleTexture;  // Lazily created output texture

    bool loadShaderFromPath(const char* shaderBuffer, const std::string& functionName);

    void* createOutputTexture(void* referenceTexture);  // Helper to create output texture
    void* createScaleTextureWithWidthAndHeight(void* refTex, int width, int height);

    // Helper for high-pass filter(not waited for completion)
    void* applyGaussianBlur(void* inputTexture, float sigma);
    void* applyImageSubtraction(void* originalTexture, void* blurredTexture);
};

#endif // METAL_PROCESSOR_H
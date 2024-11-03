//
// Created by 宾小康 on 2024/10/31.
//

#ifndef HIDINGIN_PIPELINECONFIGURATION_H
#define HIDINGIN_PIPELINECONFIGURATION_H

#include "string"

struct ShaderDesc{
    std::string shaderContent;
    std::string shaderDesc;
    std::string functionToGoVert;
    std::string functionToGoFrag;
    std::string functionToGoCompute;
};

struct PipelineConfiguration{
    void* graphicsDevice = nullptr;
    void* mtlRenderCommandQueue = nullptr;
    void* mtlRenderCommandBuffer = nullptr;
    void* mtlRenderCommandEncoder = nullptr;
    void* mtlRenderPassDesc = nullptr;
    std::vector<ShaderDesc> renderShaders;
    std::vector<ShaderDesc> computeShaders;
};

#endif //HIDINGIN_PIPELINECONFIGURATION_H

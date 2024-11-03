//
// Created by 宾小康 on 2024/10/29.
//

#ifndef HIDINGIN_METALPIPELINE_H
#define HIDINGIN_METALPIPELINE_H

#include "utils/TaskQueue.h"
#include "MetalResources.h"
#include "../PipelineConfiguration.h"
#include "../com/EventListener.h"
#include "memory"

using GpuRenderTask = std::function<void(const std::string& threadName, const MtlRenderPipeline& renderPipelineRes)>;
using GpuComputeTask = std::function<void(const std::string& threadName, const MtlComputePipeline& computePipelineRes)>;
using GpuBlitTask = std::function<void(const std::string& threadName, const MtlBlitPipeline& blitPipelineRes)>;

struct StateExchangeTextureSet;
class MetalPipeline {
private:
    MetalPipeline();

public:
    // Deleted copy constructor and assignment operator to forbid copying
    MetalPipeline(const MetalPipeline&) = delete;
    MetalPipeline& operator=(const MetalPipeline&) = delete;
    // Deleted move constructor and move assignment operator to forbid moving
    MetalPipeline(MetalPipeline&&) = delete;
    MetalPipeline& operator=(MetalPipeline&&) = delete;

public:
    static MetalPipeline& getGlobalInstance(){
        static MetalPipeline metalPipeline;
        if(!metalPipeline.isInit){
            // register init event:
            EventRegisterParam eventRegisterParam;
            eventRegisterParam.eventName = "gpuPipelineInit";
            eventRegisterParam.type = EventType::General;
            EventManager::getInstance()->registerEvent(eventRegisterParam);
        }
        return metalPipeline;
    }

    static void initGlobalMetalPipeline(PipelineConfiguration&);

public:
    std::future<void> sendJobToRenderQueue(const GpuRenderTask& renderTask);
    std::future<void> sendJobToComputeQueue(const GpuComputeTask& computeTask);
    std::future<void> sendJobToBlitQueue(const GpuBlitTask& blitTask);

    MtlRenderPipeline& getRenderPipeline();
    MtlComputePipeline& getComputePipeline();
    MtlBlitPipeline& getBlitPipeline();

    void* throughRenderingPipelineState(std::string pipelineDesc, std::vector<void*>& inputTextures);
    void throughComputePipelineState(std::string pipelineDesc, std::vector<void*>& inputTextures, void* resultTexture);
    void throughBlitPipelineState(void* inputTexture, void* outputTexture); // resource copy method

    void registerInitDoneHandler(std::function<void()>);

public:
    void executeAllRenderTasksInPlace();
    void setTriggerRenderUpdateFunc(std::function<void()> func);
    void updateRenderPipelineRes(PipelineConfiguration&); // not sure if the inner resources change in qt, update it for every pass

private:
    void prepComputePipeline(PipelineConfiguration& pipelineInitConfiguration);
    void prepBlitPipeline(PipelineConfiguration& pipelineInitConfiguration);
    void prepRenderPipeline(PipelineConfiguration& pipelineInitConfiguration, bool isUpdate = false);

private:
    std::unique_ptr<TaskQueue> m_renderingPipelineTasks;
    std::unique_ptr<TaskQueue> m_computePipelineTasks;
    std::unique_ptr<TaskQueue> m_blitPipelineTasks;

private:
    // mtl res:
    MtlComputePipeline m_mtlComputePipeline;
    MtlRenderPipeline m_mtlRenderPipeline;
    MtlBlitPipeline m_blitPipeline;

private:
    bool isInit = false;
    std::function<void()> triggerRenderUpdateFunc;
    void* m_renderTarget;
};


#endif //HIDINGIN_METALPIPELINE_H

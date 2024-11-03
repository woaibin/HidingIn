#include <memory>
#include <cmath>
#ifdef __APPLE__
#include "macos/MetalPipeline.h"
#endif

struct StateExchangeTextureSet{
public:
    StateExchangeTextureSet(std::shared_ptr<void*> textureA,
                            std::shared_ptr<void*> textureB){
        // initially, A as the first state(input), B as the second state(output):
        m_textureWrapperFirst = textureA;
        m_textureWrapperSecond = textureB;
    }

    std::shared_ptr<void*> getFirst(){
        return m_textureWrapperFirst;
    }

    std::shared_ptr<void*> getSecond(){
        return m_textureWrapperSecond;
    }

    // copy original to the input, for the first processor, it doesnt do the sampling, so just copy it to the output
    void sync(){
#ifdef __APPLE__
        MetalPipeline::getGlobalInstance().throughBlitPipelineState(m_textureWrapperSecond.get(), m_textureWrapperFirst.get());
#endif
    }

    void stateTransition(){
        std::swap(m_textureWrapperFirst, m_textureWrapperSecond);
    }

public:
    std::shared_ptr<void*> m_textureWrapperFirst;
    std::shared_ptr<void*> m_textureWrapperSecond;
};

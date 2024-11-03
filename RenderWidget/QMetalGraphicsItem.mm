#include "QMetalGraphicsItem.h"
#include <QDebug>
#include <utility>
#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <QFile>
#include <iostream>
#include <chrono>
#include <rhi/qrhi.h>
#include "../com/NotificationCenter.h"

// Constructor
QMetalGraphicsItem::QMetalGraphicsItem() {
    // Connecting to the windowChanged signal to handle when the item is associated with a window
    connect(this, &QQuickItem::windowChanged, this, &QMetalGraphicsItem::handleWindowChanged);
    connect(this, &QMetalGraphicsItem::triggerRender, this, [this](){
        window()->update();
    });

    setObjectName("metalGraphics");
}

void QMetalGraphicsItem::onBeforeRendering() {
    QSGRendererInterface *rif = window()->rendererInterface();
    // We are not prepared for anything other than running with the RHI and its Metal backend.
    Q_ASSERT(rif->graphicsApi() == QSGRendererInterface::Metal);
}

void QMetalGraphicsItem::onBeforeRenderPassRecording() {
    const QQuickWindow::GraphicsStateInfo &stateInfo(window()->graphicsStateInfo());
    QSGRendererInterface *rif = window()->rendererInterface();
    window()->beginExternalCommands();

    auto rhiSwapChain = (QRhiSwapChain*)rif->getResource(window(), QSGRendererInterface::RhiSwapchainResource);
    auto renderTarget = rhiSwapChain->currentFrameRenderTarget();
    auto renderPassDesc = renderTarget->renderPassDescriptor()->nativeHandles();

    static bool isInit = false;
    if(!isInit){
        isInit = true;
        // Read the shader from the Qt resource file
        std::vector<ShaderDesc> renderShaders;
        ShaderDesc shaderDesc;
        QFile basicRenderShaderFile(":/shader/render.metal");
        if (!basicRenderShaderFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            NSLog(@"Failed to open shader file at path: qrc:/shader/render.metal");
            return;
        }
        QByteArray basicRenderShaderContent = basicRenderShaderFile.readAll();
        shaderDesc.shaderContent = basicRenderShaderContent.toStdString();
        shaderDesc.functionToGoVert = "vertexFunction";
        shaderDesc.shaderDesc = "basicRenderShader";
        shaderDesc.functionToGoFrag = "fragmentFunction";
        renderShaders.push_back(shaderDesc);
        basicRenderShaderFile.close();

        QFile blendHideRenderShaderFile(":/shader/textureBlendHide.metal");
        if (!blendHideRenderShaderFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            NSLog(@"Failed to open shader file at path: qrc:/shader/render.metal");
            return;
        }
        QByteArray blendHideRenderShaderContent = blendHideRenderShaderFile.readAll();
        shaderDesc.shaderContent = blendHideRenderShaderContent.toStdString();
        shaderDesc.functionToGoVert = "vertexFunction";
        shaderDesc.shaderDesc = "hidingShader";
        shaderDesc.functionToGoFrag = "fragmentFunction";
        renderShaders.push_back(shaderDesc);
        blendHideRenderShaderFile.close();

        PipelineConfiguration pipelineConfiguration;
        pipelineConfiguration.graphicsDevice = rif->getResource(window(), QSGRendererInterface::DeviceResource);
        pipelineConfiguration.mtlRenderCommandQueue = rif->getResource(window(), QSGRendererInterface::CommandQueueResource);
        pipelineConfiguration.mtlRenderCommandEncoder = rif->getResource(window(), QSGRendererInterface::CommandEncoderResource);
        pipelineConfiguration.mtlRenderPassDesc = rif->getResource(window(), QSGRendererInterface::RenderPassResource);
        pipelineConfiguration.mtlRenderCommandBuffer = nil;
        pipelineConfiguration.renderShaders = renderShaders;

        initMetalRenderingPipeline(pipelineConfiguration);
    }

    auto& mtlPipeline = MetalPipeline::getGlobalInstance();
    PipelineConfiguration pipelineConfiguration;
    pipelineConfiguration.graphicsDevice = rif->getResource(window(), QSGRendererInterface::DeviceResource);
    pipelineConfiguration.mtlRenderCommandQueue = rif->getResource(window(), QSGRendererInterface::CommandQueueResource);
    pipelineConfiguration.mtlRenderCommandEncoder = rif->getResource(window(), QSGRendererInterface::CommandEncoderResource);
    pipelineConfiguration.mtlRenderCommandBuffer = nil;
    mtlPipeline.updateRenderPipelineRes(pipelineConfiguration);

    auto encoder = (id<MTLRenderCommandEncoder>) CFBridgingRelease(rif->getResource(
            window(), QSGRendererInterface::CommandEncoderResource));
    assert(encoder);
    QSize logicalSize = window()->size();
    qreal devicePixelRatioFloat = window()->devicePixelRatio();
    QSize physicalSize = logicalSize * devicePixelRatioFloat;
    MTLViewport vp;
    vp.originX = 0;
    vp.originY = 0;
    vp.width = physicalSize.width();
    vp.height = physicalSize.height();
    vp.znear = 0;
    vp.zfar = 1;

    [encoder setViewport: vp];
    mtlPipeline.executeAllRenderTasksInPlace();

    // to-do perform basic rendering:


    window()->endExternalCommands();
}

// Method to set the texture fetching function
void QMetalGraphicsItem::setTextureFetcher(std::function<void*()> fetcher) {
    textureFetcher = fetcher;
}

void QMetalGraphicsItem::handleWindowChanged(QQuickWindow *win) {
    if (win) {
        connect(win, &QQuickWindow::beforeSynchronizing, this, &QMetalGraphicsItem::sync, Qt::DirectConnection);
        connect(win, &QQuickWindow::sceneGraphInvalidated, this, &QMetalGraphicsItem::cleanup, Qt::DirectConnection);

        win->setObjectName("metalGraphicsWindow");
    }
}

void QMetalGraphicsItem::sync() {
    // Initializing resources is done before starting to encode render
    // commands, regardless of wanting an underlay or overlay.
    connect(window(), &QQuickWindow::beforeRendering, this, &QMetalGraphicsItem::onBeforeRendering, Qt::DirectConnection);
    // Here we want an underlay and therefore connect to
    // beforeRenderPassRecording. Changing to afterRenderPassRecording
    // would render the squircle on top (overlay).
    connect(window(), &QQuickWindow::beforeRenderPassRecording, this, &QMetalGraphicsItem::onBeforeRenderPassRecording, Qt::DirectConnection);
}

void QMetalGraphicsItem::cleanup() {

}

void QMetalGraphicsItem::readMsgThreadFunc() {
    while(1){
        auto msg = NotificationCenter::getInstance().receiveMessage();
        if(msg.msgType == MessageType::Control && msg.whatHappen == "quit"){
            break;
        }else if(msg.msgType == MessageType::Render){
            requestRender();
        }
    }
}

void QMetalGraphicsItem::initMetalRenderingPipeline(PipelineConfiguration &pipelineInitConfiguration) {
    // set trigger render update func:
    MetalPipeline::getGlobalInstance().setTriggerRenderUpdateFunc([this](){
        requestRender();
    });

    // init all pipelines:
    MetalPipeline::initGlobalMetalPipeline(pipelineInitConfiguration);
}

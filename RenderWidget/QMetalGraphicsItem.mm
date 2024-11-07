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
    setFlag(ItemHasContents, true);
    connect(this, &QMetalGraphicsItem::triggerRender, this, [this](){
        window()->update();
    });

    setObjectName("metalGraphics");
}

void QMetalGraphicsItem::onBeforeRendering() {
    QSGRendererInterface *rif = window()->rendererInterface();
    // We are not prepared for anything other than running with the RHI and its Metal backend.
    Q_ASSERT(rif->graphicsApi() == QSGRendererInterface::Metal);

    auto& mtlPipeline = MetalPipeline::getGlobalInstance();
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
        pipelineConfiguration.mtlRenderCommandBuffer = rif->getResource(window(), QSGRendererInterface::CommandListResource);
        pipelineConfiguration.renderShaders = renderShaders;

        initMetalRenderingPipeline(pipelineConfiguration);
    }else{
        PipelineConfiguration pipelineConfiguration;
        pipelineConfiguration.graphicsDevice = rif->getResource(window(), QSGRendererInterface::DeviceResource);
        pipelineConfiguration.mtlRenderCommandQueue = rif->getResource(window(), QSGRendererInterface::CommandQueueResource);
        pipelineConfiguration.mtlRenderCommandEncoder = rif->getResource(window(), QSGRendererInterface::CommandEncoderResource);
        pipelineConfiguration.mtlRenderPassDesc = rif->getResource(window(), QSGRendererInterface::RenderPassResource);
        pipelineConfiguration.mtlRenderCommandBuffer = rif->getResource(window(), QSGRendererInterface::CommandListResource);

        MetalPipeline::getGlobalInstance().updateRenderPipelineRes(pipelineConfiguration);
    }
    //mtlPipeline.executeAllRenderTasksInPlace();
}

void QMetalGraphicsItem::handleWindowChanged(QQuickWindow *win) {
    if (win) {
        connect(win, &QQuickWindow::beforeSynchronizing, this, &QMetalGraphicsItem::sync, Qt::DirectConnection);
        connect(win, &QQuickWindow::sceneGraphInvalidated, this, &QMetalGraphicsItem::cleanup, Qt::DirectConnection);

        win->setObjectName("metalGraphicsWindow");
    }
}

void QMetalGraphicsItem::sync() {
    connect(window(), &QQuickWindow::beforeRendering, this, &QMetalGraphicsItem::onBeforeRendering, Qt::DirectConnection);
    connect(window(), &QQuickWindow::afterRendering, this, &QMetalGraphicsItem::afterRenderingDone, Qt::DirectConnection);
}

void QMetalGraphicsItem::cleanup() {

}

void QMetalGraphicsItem::initMetalRenderingPipeline(PipelineConfiguration &pipelineInitConfiguration) {
    // set trigger render update func:
    MetalPipeline::getGlobalInstance().setTriggerRenderUpdateFunc([this](){
        requestRender();
    });

    // init all pipelines:
    MetalPipeline::initGlobalMetalPipeline(pipelineInitConfiguration);
}

void QMetalGraphicsItem::afterRenderingDone() {
    if(!MetalPipeline::getGlobalInstance().isRenderingInitDoneBefore()){
        MetalPipeline::getGlobalInstance().setRenderingInitDone();
        EventManager::getInstance()->triggerEvent("gpuRenderPipelineInit", EventParam());
    }
}

QSGNode *QMetalGraphicsItem::updatePaintNode(QSGNode *oldNode, QQuickItem::UpdatePaintNodeData *) {
    // Create a new node if necessary
    QCustomRenderNode* node = static_cast<QCustomRenderNode*>(oldNode);
    if (!node) {
        node = new QCustomRenderNode(this);

    }

    node->setTextureCoordinatesTransform(QSGSimpleTextureNode::NoTransform);
    node->setFiltering(QSGTexture::Linear);
    node->setRect(0, 0, width(), height());

    auto metalPipeline = MetalPipeline::getGlobalInstance().getRenderPipeline();
    if(!metalPipeline.renderTarget){
        QSGRendererInterface *rif = window()->rendererInterface();
        auto device = (id<MTLDevice>) rif->getResource(window(), QSGRendererInterface::DeviceResource);
        Message msg;
        NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
        auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
        MTLTextureDescriptor *desc = [[MTLTextureDescriptor alloc] init];
        desc.textureType = MTLTextureType2D;
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.width = windowInfo->width * windowInfo->scalingFactor;
        desc.height = windowInfo->height  * windowInfo->scalingFactor;
        desc.mipmapLevelCount = 1;
        desc.resourceOptions = MTLResourceStorageModePrivate;
        desc.storageMode = MTLStorageModePrivate;
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        auto texture = [device newTextureWithDescriptor: desc];
        [desc release];

        QSGTexture *wrapper = QNativeInterface::QSGMetalTexture::fromNative(
                texture, window(), QSize(texture.width, texture.height));

        MetalPipeline::getGlobalInstance().setRenderTarget(texture);
        node->setTexture(wrapper);
    }else{
        auto mtlTexture = (id<MTLTexture>)metalPipeline.renderTarget;
        QSGTexture *wrapper = QNativeInterface::QSGMetalTexture::fromNative(
                mtlTexture, window(), QSize(mtlTexture.width, mtlTexture.height));
        node->setTexture(wrapper);
    }

    window()->update();
    return node;
}
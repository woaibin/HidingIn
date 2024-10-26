#include "QMetalGraphicsItem.h"
#include <QDebug>
#include <utility>
#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <QFile>
#include <iostream>
#include <chrono>
#include "../com/NotificationCenter.h"

// Constructor
QMetalGraphicsItem::QMetalGraphicsItem(): readMsgThread(&QMetalGraphicsItem::readMsgThreadFunc, this) {
    // Connecting to the windowChanged signal to handle when the item is associated with a window
    connect(this, &QQuickItem::windowChanged, this, &QMetalGraphicsItem::handleWindowChanged);
    connect(this, &QMetalGraphicsItem::triggerRender, this, [this](){
        window()->update();
    });
    setObjectName("metalGraphics");
}
// Slot: Called before rendering starts
void QMetalGraphicsItem::onBeforeRendering() {
    //std::cerr << "on before rendering start" << std::endl;
    QSGRendererInterface *rif = window()->rendererInterface();

    // We are not prepared for anything other than running with the RHI and its Metal backend.
    Q_ASSERT(rif->graphicsApi() == QSGRendererInterface::Metal);

    mtlDevice = (id<MTLDevice>) rif->getResource(window(), QSGRendererInterface::DeviceResource);
    Q_ASSERT(mtlDevice);

    // Define the vertices (position and color)
    static const float quadVertices[] = {
            -1.0,  1.0, 0.0, 0.0,  // top left
            1.0,  1.0, 1.0, 0.0,  // top right
            -1.0, -1.0, 0.0, 1.0,  // bottom left
            1.0, -1.0, 1.0, 1.0   // bottom right
    };
    if(!m_initialized){
        //std::cerr << "on before rendering init" << std::endl;
        // Create the vertex buffer, storing the vertex data
        vertexBuffer = [(id<MTLDevice>)mtlDevice newBufferWithBytes:quadVertices
                                                             length:sizeof(quadVertices)
                                                            options:MTLResourceStorageModeShared];

        setUpPipeline();
        m_initialized = true;
    }
    //std::cerr << "on before rendering stop" << std::endl;
}

// Slot: Called before each render pass is recorded
void QMetalGraphicsItem::onBeforeRenderPassRecording() {
    // Capture start time
//    auto start = std::chrono::high_resolution_clock::now();
    const QQuickWindow::GraphicsStateInfo &stateInfo(window()->graphicsStateInfo());

    QSGRendererInterface *rif = window()->rendererInterface();

    if(!textureFetcher){
        return;
    }
    auto latestTexture = (id<MTLTexture>)textureFetcher();
    if(!latestTexture){
        return;
    }
    //qDebug() << "rendering item: " << idName;
    window()->beginExternalCommands();
    id<MTLRenderCommandEncoder> encoder = (id<MTLRenderCommandEncoder>) rif->getResource(
            window(), QSGRendererInterface::CommandEncoderResource);
    id<MTLCommandBuffer> cb = (id<MTLCommandBuffer>) rif->getResource(window(), QSGRendererInterface::CommandListResource);
    Q_ASSERT(encoder);

    // Get the device pixel ratio
    // Get the size in logical pixels
    QSize logicalSize = window()->size();
    qreal devicePixelRatioFloat = window()->devicePixelRatio();

    // Calculate the size in physical pixels
    QSize physicalSize = logicalSize * devicePixelRatioFloat;

    MTLViewport vp;
    vp.originX = 0;
    vp.originY = 0;
    vp.width = physicalSize.width();
    vp.height = physicalSize.height();
    vp.znear = 0;
    vp.zfar = 1;
    [encoder setViewport: vp];

    [encoder setVertexBuffer:static_cast<id <MTLBuffer>>(vertexBuffer) offset:0 atIndex:0];
    [encoder setFragmentTexture:latestTexture atIndex: 0];
    [encoder setRenderPipelineState: (id<MTLRenderPipelineState>)pipelineState];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];

    window()->endExternalCommands();

    // Capture end time
//    auto end = std::chrono::high_resolution_clock::now();
//    auto duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
//    std::cout << "Time cost: " << duration_ms << " ms\n";
}

// Method to set the texture fetching function
void QMetalGraphicsItem::setTextureFetcher(std::function<void*()> fetcher) {
    textureFetcher = fetcher;
}

void QMetalGraphicsItem::setUpPipeline() {
    NSError *error = nil;

    // Read the shader from the Qt resource file
    QFile shaderFile(":/shader/render.metal");

    if (!shaderFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        NSLog(@"Failed to open shader file at path: qrc:/shader/render.metal");
        return;
    }

    // Read the entire shader file content into a string
    QByteArray shaderContent = shaderFile.readAll();
    shaderFile.close();

    // Convert QByteArray to NSString (Metal expects NSString for the shader source)
    NSString *shaderSource = [NSString stringWithUTF8String:shaderContent.constData()];

    if (!shaderSource) {
        NSLog(@"Failed to read shader source from: qrc:/shader/render.metal");
        return;
    }

    // Compile the shader source into a Metal library
    id<MTLLibrary> library = [(id<MTLDevice>)mtlDevice newLibraryWithSource:shaderSource options:nil error:&error];

    if (!library) {
        NSLog(@"Failed to compile shader library: %@", error);
        return;
    }

    // Get the vertex and fragment functions from the shader library
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertexFunction"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragmentFunction"];

    // Create a render pipeline descriptor and set up the shaders
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.colorAttachments[0].blendingEnabled = false;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    auto macView =(NSView*) window()->winId();
    NSString* layerFormat = macView.layer.contentsFormat;
    if(![layerFormat  isEqual: @"RGBA8"]){
        qFatal() << "QMetalGraphicsItem::setUpPipeline: not supported this format: " << layerFormat.cString;
        return;
    }
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // Create the render pipeline state object
    pipelineState = [(id<MTLDevice>)mtlDevice newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];

    if (!pipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }
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

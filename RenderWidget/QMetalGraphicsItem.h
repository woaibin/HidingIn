#ifndef QMETALGRAPHICSITEM_H
#define QMETALGRAPHICSITEM_H

#include <QQuickItem>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <thread>
#include <GPUPipeline/macos/MetalPipeline.h>
// Declare the QMetalGraphicsItem class
class QMetalGraphicsItem : public QQuickItem
{
Q_OBJECT

public:
    // Constructor
    QMetalGraphicsItem();
    // Method to set the texture fetching function
    void setTextureFetcher(std::function<void*()> fetcher);

signals:
    void triggerRender();  // Signal to trigger rendering in the main thread

private:
    void setUpPipeline();
    void requestRender() {
        // Emit the signal to trigger rendering
        emit triggerRender();
    }
    void readMsgThreadFunc();
    void initMetalRenderingPipeline(PipelineConfiguration& pipelineInitConfiguration);

public slots:
    void sync();
    void cleanup();
    void handleWindowChanged(QQuickWindow *win);
    // Slot called before rendering starts
    void onBeforeRendering();
    void setIdName(std::string name){
        idName = name;
    }
    // Slot called before each render pass is recorded
    void onBeforeRenderPassRecording();

private:
    // Function to fetch the texture
    std::function<void*()> textureFetcher;
    std::thread readMsgThread;
    void* vertexBuffer = nullptr;
    void* mtlDevice = nullptr;
    void* pipelineState = nullptr;
    void* commandQueue = nullptr;
    bool m_initialized = false;
    std::string idName = "";
};

#endif // QMETALGRAPHICSITEM_H
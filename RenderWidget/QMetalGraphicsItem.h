#ifndef QMETALGRAPHICSITEM_H
#define QMETALGRAPHICSITEM_H

#include <QQuickItem>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <thread>
#include <GPUPipeline/macos/MetalPipeline.h>
#include <QPainter>
#include "QCustomRenderNode.h"
#include "../GPUPipeline/macos/MetalPipeline.h"
// Declare the QMetalGraphicsItem class
class QMetalGraphicsItem : public QQuickItem
{
Q_OBJECT
    Q_PROPERTY(qreal t READ t WRITE setT NOTIFY tChanged)
    QML_ELEMENT

public:
    // Constructor
    QMetalGraphicsItem();
    void setCouldRender(){
        couldRender = true;
    }
    
    qreal t() const { return m_t; }
    void setT(qreal t);

signals:
    void triggerRender();  // Signal to trigger rendering in the main thread
    void tChanged();

private:
    void setUpPipeline();
    void requestRender() {
        // Emit the signal to trigger rendering
        emit triggerRender();
    }
    void readMsgThreadFunc();
    void initMetalRenderingPipeline(PipelineConfiguration& pipelineInitConfiguration);

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;


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
    void afterRenderingDone();

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
    std::atomic_bool couldRender = false;
    qreal m_t = 0;
private:
    bool needsRepaint = true;
};

#endif // QMETALGRAPHICSITEM_H

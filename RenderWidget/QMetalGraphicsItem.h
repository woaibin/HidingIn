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
#include "QCustomRenderNode.h"
// Declare the QMetalGraphicsItem class
class QMetalGraphicsItem : public QQuickItem
{
Q_OBJECT

public:
    // Constructor
    QMetalGraphicsItem();

    void doNotUpdate(){
        dontUpdate = true;
    }

    void stopAllWork();

    void enableUpdate();

signals:
    void triggerRender();  // Signal to trigger rendering in the main thread

private:
    void requestRender() {
        // Emit the signal to trigger rendering
        emit triggerRender();
    }
    void initMetalRenderingPipeline(PipelineConfiguration& pipelineInitConfiguration);

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

public slots:
    void sync();
    void cleanup();
    void handleWindowChanged(QQuickWindow *win);
    // Slot called before rendering starts
    void onBeforeRendering();
    void setIdName(std::string name){
        idName = name;
    }
    void afterRenderingDone();

private:
    std::string idName = "";
    int lastWidth = -1;
    int lastHeight = -1;
    QSGTexture* lastRenderTargetTexture = nullptr;
    bool dontUpdate = false;
    QCustomRenderNode* m_customRenderNode = nullptr;
    bool isInit = false;
};

#endif // QMETALGRAPHICSITEM_H

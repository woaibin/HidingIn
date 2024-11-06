//
// Created by 宾小康 on 2024/11/5.
//

#ifndef HIDINGIN_QCUSTOMRENDERNODE_H
#define HIDINGIN_QCUSTOMRENDERNODE_H
#include "QObject"
#include "QSGSimpleTextureNode"
#include "QSGTextureProvider"
#include "QQuickItem"
class QCustomRenderNode :public QSGTextureProvider,public QSGSimpleTextureNode {
Q_OBJECT
public:
    explicit QCustomRenderNode(QQuickItem *item);
    ~QCustomRenderNode() override;
    QSGTexture *texture() const override;

private:

private:
    QQuickItem *m_item;
    QQuickWindow *m_window;
};


#endif //HIDINGIN_QCUSTOMRENDERNODE_H

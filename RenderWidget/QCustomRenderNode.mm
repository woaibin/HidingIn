//
// Created by 宾小康 on 2024/11/5.
//

#include "QCustomRenderNode.h"

QCustomRenderNode::QCustomRenderNode(QQuickItem *item) {
    m_window = item->window();
}

QCustomRenderNode::~QCustomRenderNode() {

}

QSGTexture *QCustomRenderNode::texture() const {
    return QSGSimpleTextureNode::texture();
}

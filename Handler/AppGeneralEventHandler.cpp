//
// Created by 宾小康 on 2024/10/23.
//

#include "AppGeneralEventHandler.h"

bool AppGeneralEventHandler::eventFilter(QObject *watched, QEvent *event) {
    if(watched->objectName() != "metalGraphicsWindow"){
        return QObject::eventFilter(watched, event);
    }
    // to-do: handle continually pressing a key:
    if (event->type() == QEvent::Type::KeyRelease) {

        // Convert the key event to a string (for simplicity, assuming ASCII)
        QKeyEvent *keyEvent = static_cast<QKeyEvent *>(event);
        remoteInputController->sendKey(keyEvent->nativeVirtualKey());
    } else if (event->type() == QEvent::Type::MouseButtonPress) {
        if (remoteInputController) {
            // Cast the event to QMouseEvent to access mouse position
            QMouseEvent *mouseEvent = static_cast<QMouseEvent *>(event);
            QPointF mousePos = mouseEvent->globalPos();

            // Send the mouse click event to the remote controller
            remoteInputController->sendMouseClickAt(mousePos.x(), mousePos.y());
            qDebug() << "Mouse clicked at:" << mousePos;
        }
    }

    // Pass the event to the base class
    return QObject::eventFilter(watched, event);
}

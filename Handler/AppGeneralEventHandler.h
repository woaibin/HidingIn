//
// Created by 宾小康 on 2024/10/23.
//

#ifndef HIDINGIN_APPGENERALEVENTHANDLER_H
#define HIDINGIN_APPGENERALEVENTHANDLER_H
#include "QObject"
#include "QDebug"
#include "QEvent"
#include "QMouseEvent"
#include "QKeyEvent"
#ifdef __APPLE__
#include "../Control/macos/RemoteInputControllerMacOS.h"
using RemoteInputController = RemoteInputControllerMacOS;
#endif

using AppItemDBClickHandler = std::function<void(QString appName)>;

class AppGeneralEventHandler : public QObject{
Q_OBJECT
public:
    explicit AppGeneralEventHandler(QObject* parent = nullptr) : QObject(parent){

    }

public slots:
    Q_INVOKABLE void onItemDoubleClicked(QString appName) {
        if(m_appItemDbClickHandler){
            m_appItemDbClickHandler(appName);
        }
    }

public:
    void setOnAppItemDBClickHandlerFunc(AppItemDBClickHandler handleFunc){
        m_appItemDbClickHandler = handleFunc;
    }

    void initRemoteInputController(int pid){
        remoteInputController = std::make_shared<RemoteInputController>(pid);
    }

// QObject interface
public:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    AppItemDBClickHandler m_appItemDbClickHandler;
    std::shared_ptr<RemoteInputController> remoteInputController;
};


#endif //HIDINGIN_APPGENERALEVENTHANDLER_H

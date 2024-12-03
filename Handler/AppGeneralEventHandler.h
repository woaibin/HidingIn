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
using AppItemDBClickHandler = std::function<void(QString appName, QString winId, QString appPid)>;

class AppGeneralEventHandler : public QObject{
Q_OBJECT
public:
    explicit AppGeneralEventHandler(QObject* parent = nullptr) : QObject(parent){

    }

public slots:
    Q_INVOKABLE void onItemDoubleClicked(QString appName, QString winId, QString appPid) {
        if(m_appItemDbClickHandler){
            m_appItemDbClickHandler(appName, winId, appPid);
        }
    }

public:
    void setOnAppItemDBClickHandlerFunc(AppItemDBClickHandler handleFunc){
        m_appItemDbClickHandler = handleFunc;
    }

private:
    AppItemDBClickHandler m_appItemDbClickHandler;
};


#endif //HIDINGIN_APPGENERALEVENTHANDLER_H

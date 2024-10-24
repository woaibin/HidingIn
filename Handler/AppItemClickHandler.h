//
// Created by 宾小康 on 2024/10/23.
//

#ifndef HIDINGIN_APPITEMCLICKHANDLER_H
#define HIDINGIN_APPITEMCLICKHANDLER_H
#include "QObject"
#include "QDebug"

using AppItemDBClickHandler = std::function<void(QString appName)>;

class AppItemClickHandler : public QObject{
Q_OBJECT
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

private:
    AppItemDBClickHandler m_appItemDbClickHandler;
};


#endif //HIDINGIN_APPITEMCLICKHANDLER_H

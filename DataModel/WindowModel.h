// WindowModel.h
#ifndef WINDOWMODEL_H
#define WINDOWMODEL_H

#include <QString>

class WindowModel {
public:
    WindowModel(QString handle, QString name, QString content)
            : m_windowHandle(std::move(handle)), m_appName(std::move(name)), m_frameContent(std::move(content)) {}

    const QString &windowHandle() const { return m_windowHandle; }
    const QString &appName() const { return m_appName; }
    const QString &frameContent() const { return m_frameContent; }

private:
    QString m_windowHandle;
    QString m_appName;
    QString m_frameContent;
};

#endif // WINDOWMODEL_H
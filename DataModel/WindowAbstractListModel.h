// WindowAbstractListModel.h
#ifndef WINDOWABSTRACTLISTMODEL_H
#define WINDOWABSTRACTLISTMODEL_H

#include <QAbstractListModel>
#include <QList>
#include "WindowModel.h"  // Include the WindowModel class
#include "SnapShotImageProvider.h"
class WindowAbstractListModel : public QAbstractListModel {
Q_OBJECT

public:
    enum WindowRoles {
        WindowHandleRole = Qt::UserRole + 1,
        AppNameRole,
        FrameContentRole
    };

    explicit WindowAbstractListModel(QObject *parent = nullptr)
            : QAbstractListModel(parent) {}

    // Add a window to the model
    void addWindow(const WindowModel &window) {
        beginInsertRows(QModelIndex(), rowCount(), rowCount());
        m_windows.append(window);
        endInsertRows();
    }

    // Override rowCount
    int rowCount(const QModelIndex &parent = QModelIndex()) const override {
        Q_UNUSED(parent);
        return m_windows.count();
    }

    // Override data
    QVariant data(const QModelIndex &index, int role) const override {
        if (index.row() < 0 || index.row() >= m_windows.count())
            return {};

        const WindowModel &window = m_windows[index.row()];

        switch (role) {
            case WindowHandleRole:
                return window.windowHandle();
            case AppNameRole:
                return window.appName();
            case FrameContentRole:
                return window.frameContent();
        }

        return {};
    }

    // Override roleNames to map roles with QML property names
    QHash<int, QByteArray> roleNames() const override {
        QHash<int, QByteArray> roles;
        roles[WindowHandleRole] = "windowHandle";
        roles[AppNameRole] = "appName";
        roles[FrameContentRole] = "frameContent";
        return roles;
    }

    void enum10Apps();

    SnapShotImageProvider& getImgProvider(){
        return m_snapShotImageProvider;
    }

private:
    QList<WindowModel> m_windows;  // List of WindowModel objects
    SnapShotImageProvider m_snapShotImageProvider;
};

#endif // WINDOWABSTRACTLISTMODEL_H
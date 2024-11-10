// WindowAbstractListModel.h
#ifndef WINDOWABSTRACTLISTMODEL_H
#define WINDOWABSTRACTLISTMODEL_H

#include <QAbstractListModel>
#include <QList>
#include "WindowModel.h"  // Include the WindowModel class
#include "SnapShotImageProvider.h"
#include <QRegularExpression>
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

    void updateWindows(){
        clearItemData(QModelIndex());
        beginInsertRows(QModelIndex(), rowCount(), rowCount());
        endInsertRows();
    }

    // Override rowCount
    int rowCount(const QModelIndex &parent = QModelIndex()) const override {
        Q_UNUSED(parent);
        return m_windowsForShow.count();
    }

    // Override data
    QVariant data(const QModelIndex &index, int role) const override {
        if (index.row() < 0 || index.row() >= m_windowsForShow.count())
            return {};

        const WindowModel &window = m_windowsForShow[index.row()];

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

    void enumAllApps();

    SnapShotImageProvider& getImgProvider(){
        return m_snapShotImageProvider;
    }

    WindowModel& getWindowModelByAppName(const std::string& appName) {
        auto it = std::find_if(m_windowsFull.begin(), m_windowsFull.end(), [&appName](const WindowModel& window) {
            return window.appName() == appName;
        });

        if (it != m_windowsFull.end()) {
            return *it;
        }

        throw std::runtime_error("Window with app name '" + appName + "' not found.");
    }

    bool matchesFromInitials(const QString& appName, const QString& searchTerm) {
        // Use QRegularExpression to split the app name by any whitespace characters
        QRegularExpression wordDelimiter("\\s+");
        QStringList words = appName.split(wordDelimiter, Qt::SkipEmptyParts);

        // Check if any word starts with the search term
        for (const QString& word : words) {
            if (word.startsWith(searchTerm, Qt::CaseInsensitive)) {
                return true;  // Return true if any word starts with the search term
            }
        }
        return false;
    }

    // Use QString instead of std::string
    Q_INVOKABLE void searchApp(const QString& appName) {
        beginResetModel();  // Notify views that we're about to change the data.

        m_windowsForShow.clear();  // Clear the current list of windows for display.

        if (appName.isEmpty()) {
            // If search string is empty, show all apps
            m_windowsForShow = m_windowsFull;
        } else {
            // Search for windows where the app name starts with the search term at the beginning of any word
            for (const auto& window : m_windowsFull) {
                if (matchesFromInitials(window.appName(), appName)) {
                    m_windowsForShow.push_back(window);
                }
            }
        }

        endResetModel();  // Notify views that the data has been updated.
    }
private:
    QList<WindowModel> m_windowsFull;  // List of WindowModel objects
    QList<WindowModel> m_windowsForShow;  // List of WindowModel objects
    SnapShotImageProvider m_snapShotImageProvider;
};

#endif // WINDOWABSTRACTLISTMODEL_H
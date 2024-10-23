//
// Created by 宾小康 on 2024/10/23.
//

#ifndef HIDINGIN_SNAPSHOTIMAGEPROVIDER_H
#define HIDINGIN_SNAPSHOTIMAGEPROVIDER_H
#include "QQuickImageProvider"
#include <unordered_map>

class SnapShotImageProvider : public QQuickImageProvider {
public:
    SnapShotImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

    // Add an image with a specific ID
    void addImage(const QString &id, const QImage &image) {
        m_appSnapShotMaps[id.toStdString()] = image;
    }

    // Override the requestImage method to return the image associated with the ID
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override {
        if (m_appSnapShotMaps.contains(id.toStdString())) {
            QImage image = m_appSnapShotMaps[id.toStdString()];
            if (size)
                *size = image.size();

            if (requestedSize.width() > 0 && requestedSize.height() > 0)
                return image.scaled(requestedSize.width(), requestedSize.height(), Qt::KeepAspectRatio);

            return image;
        } else {
            // Return a default placeholder if the ID is not found
            return {};
        }
    }

private:
    std::unordered_map<std::string, QImage> m_appSnapShotMaps;
};


#endif //HIDINGIN_SNAPSHOTIMAGEPROVIDER_H

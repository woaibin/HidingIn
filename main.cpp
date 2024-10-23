#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQuick>
#include "DataModel/WindowAbstractListModel.h"
#include "RenderWidget/QMetalGraphicsItem.h"
#ifdef __APPLE__
//#include "DesktopCapture/macos/MacosCapture.h"
#include "DesktopCapture/macos/MacOSCaptureSCKit.h"
#include "com/NotificationCenter.h"
#include "platform/macos/MacUtils.h"
#include <QProcessEnvironment>
#endif

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

#ifdef __APPLE__
    MacOSCaptureSCKit screenCapture;
    //MacosCapture screenCapture;
#endif

    // Set the environment variable
    qputenv("QT_QUICK_CONTROLS_IGNORE_CUSTOMIZATION_WARNINGS", "1");

    Message msg;
    msg.msgType = MessageType::Render;
    msg.whatHappen = "";
    msg.subMsg = std::make_shared<WindowSubMsg>(250,250, 1200, 800, getScalingFactor());
    NotificationCenter::getInstance().pushMessage(msg, true);

    // Start capturing screen content and save it to "output.mov"
    if (screenCapture.startCapture()) {
        qDebug() << "start screen capturing";
    } else {
        qDebug() << "failed to start screen capturing";
    }

#ifdef __APPLE__
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Metal);
#endif

    // Set up the QML engine
    QQmlApplicationEngine engine;
    // Register QMetalGraphicsItem with QML under the module name "CustomItems"
    auto ret = qmlRegisterType<QMetalGraphicsItem>("CustomItems", 1, 0, "MetalGraphicsItem");

    // Create the model and add data to it
    WindowAbstractListModel windowModel;
    auto& imgProvider = windowModel.getImgProvider();
    engine.addImageProvider("appsnapshotprovider", &imgProvider);
    windowModel.enum10Apps();

    // Expose the model to QML
    engine.rootContext()->setContextProperty("windowListModel", &windowModel);

    // Load the main QML file
    const QUrl url(QStringLiteral("qrc:/main.qml"));

    engine.load(url);

    // Access the root object
    auto rootObjects = engine.rootObjects();
    QObject *rootObject = engine.rootObjects().first();
    QQuickWindow *window = qobject_cast<QQuickWindow *>(rootObject);
    if (window) {
        // Connect to the widthChanged signal
        QObject::connect(window, &QQuickWindow::widthChanged, [](int newWidth) {
            Message msg;
            NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
            auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
            windowInfo->width = newWidth;
            windowInfo->needResizeForRender = true;
        });

        // Connect to the heightChanged signal
        QObject::connect(window, &QQuickWindow::heightChanged, [](int newHeight) {
            Message msg;
            NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
            auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
            windowInfo->height = newHeight;
            windowInfo->needResizeForRender = true;
        });

        // Connect to the xChanged signal (window position x)
        QObject::connect(window, &QQuickWindow::xChanged, [](int newX) {
            Message msg;
            NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
            auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
            windowInfo->xPos = newX;
        });

        // Connect to the yChanged signal (window position y)
        QObject::connect(window, &QQuickWindow::yChanged, [](int newY) {
            Message msg;
            NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
            auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
            windowInfo->yPos = newY;
        });
    }

    // Find the MetalGraphicsItem instance by object name or hierarchy
    QObject *item = rootObject->findChild<QObject*>("metalGraphicsItemName");
    if (item) {
        QMetalGraphicsItem *metalItem = qobject_cast<QMetalGraphicsItem*>(item);
        if (metalItem) {
            // Call the method on the instance
            metalItem->setTextureFetcher([&]() -> void* {
                // Return your MTLTexture here
                return screenCapture.getLatestCaptureFrame();
            });
        }
    }

    // Connect to the engine's object creation signal
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                if (!obj && url == objUrl)
                    QCoreApplication::exit(-1);
            }, Qt::QueuedConnection);

    // If the main QML file cannot be loaded, terminate the application
    if (engine.rootObjects().isEmpty())
        return -1;
    auto finalRet = app.exec();
    screenCapture.stopCapture();
    return finalRet;
}
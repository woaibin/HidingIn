#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQuick>
#include "DataModel/WindowAbstractListModel.h"
#include "RenderWidget/QMetalGraphicsItem.h"
#ifdef __APPLE__
//#include "DesktopCapture/macos/MacosCapture.h"
#include "DesktopCapture/macos/MacOSCaptureSCKit.h"
#include "platform/macos/MacUtils.h"
#endif
#include <QProcessEnvironment>
#include <utility>
#include "com/NotificationCenter.h"
#include "Handler/AppGeneralEventHandler.h"
#include "DesktopCapture/CompositeCapture.h"

// Function to make all windows ignore mouse input
void ignoreMouseInputForAllWindows() {
    // Get the list of all top-level windows
    const QList<QWindow *> windows = QGuiApplication::topLevelWindows();

    // Iterate through each window and set it to ignore mouse events
    for (QWindow *window : windows) {
        if (window) {
            // Set the window to ignore mouse events
            window->setFlags(window->flags() | Qt::WindowTransparentForInput);
            // Optional: you can print the window title or some info for debugging
            qDebug() << "Ignoring mouse input for window:" << window->title();
        }
    }
}

// Function to get the current application window
QQuickWindow* getCurrentWindow() {
    // Get the list of top-level windows
    const QList<QWindow *> windows = QGuiApplication::topLevelWindows();

    // Find the first visible QQuickWindow
    for (QWindow *window : windows) {
        QQuickWindow *quickWindow = qobject_cast<QQuickWindow *>(window);
        if (quickWindow && quickWindow->isVisible()) {
            return quickWindow; // Return the first visible window
        }
    }

    return nullptr; // No visible window found
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

#ifdef __APPLE__
    MacOSCaptureSCKit screenCapture;
    //MacOSCaptureSCKit appCapture;
    CompositeCapture compositeCapture;
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

    AppGeneralEventHandler handler;  // Create an instance of the handler

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
    QObject *transparentBgCaptureItem = rootObject->findChild<QObject*>("transparentBgCapture");
    if (transparentBgCaptureItem) {
        QMetalGraphicsItem *metalItem = qobject_cast<QMetalGraphicsItem*>(transparentBgCaptureItem);
        metalItem->setIdName("bgCap");
        if (metalItem) {
            // Call the method on the instance
            metalItem->setTextureFetcher([&]() -> void* {
                // Return your MTLTexture here
                if(screenCapture.getCaptureStatus() == CaptureStatus::Start){
                    return screenCapture.getLatestCaptureFrame();
                }else{
                    return nullptr;
                }
            });
        }
    }
    QObject *appCaptureItem = rootObject->findChild<QObject*>("appCapture");
    if (appCaptureItem) {
        QMetalGraphicsItem *metalItem = qobject_cast<QMetalGraphicsItem*>(appCaptureItem);
        metalItem->setIdName("appCap");
        if (metalItem) {
            // Call the method on the instance
            metalItem->setTextureFetcher([&]() -> void* {
                // Return your MTLTexture here
                if(compositeCapture.queryCaptureStatus() == CaptureStatus::Start){
                    return compositeCapture.getLatestCompositeFrame();
                }else{
                    return nullptr;
                }
            });
        }
    }

    // find out all app items:
    auto appItem = rootObject->findChild<QObject*>("appItems");
    if (appItem) {
        QObject::connect(appItem, SIGNAL(appItemDoubleClicked(QString)), &handler, SLOT(onItemDoubleClicked(QString)));
        QMetalGraphicsItem *metalItem = qobject_cast<QMetalGraphicsItem*>(appCaptureItem);
        handler.setOnAppItemDBClickHandlerFunc([&](QString appName){
            screenCapture.stopCapture();
            DesktopCaptureArgs captureArgs;
            captureArgs.excludingWindowIDs = getCurrentAppWindowIDVec();
            compositeCapture.addWholeDesktopCapture(captureArgs);
            compositeCapture.addCaptureByApplicationName(appName.toStdString());
            //appCapture.startCaptureWithApplicationName(appName.toStdString());
            auto currentWindow = getCurrentWindow();
            auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
//#ifdef __APPLE__
//            void *nativeWindow = (void*)currentWindow->winId();
//            stickToApp(windowInfo->capturedWinId, windowInfo->appPid, nativeWindow);
//#endif
//            ignoreMouseInputForAllWindows();
        });

    } else {
        qWarning() << "Rectangle object not found!";
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
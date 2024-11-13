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
#include "Handler/AppWindowListener.h"

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

    // Set the environment variable
    qputenv("QT_QUICK_CONTROLS_IGNORE_CUSTOMIZATION_WARNINGS", "1");

    Message msg;
    msg.msgType = MessageType::Render;
    msg.whatHappen = "";
    msg.subMsg = std::make_shared<WindowSubMsg>(250,250, 1200, 800, getScalingFactor());
    NotificationCenter::getInstance().pushMessage(msg, true);

#ifdef __APPLE__
    //MacOSCaptureSCKit appCapture;
    CompositeCaptureArgs compositeCaptureArgs;
    CompositeCapture compositeCapture(compositeCaptureArgs);
#endif

    MetalPipeline::getGlobalInstance().registerInitDoneHandler([&]{
        CaptureArgs captureArgs;
        captureArgs.captureEventName = "DesktopCapture";
        captureArgs.excludingWindowIDs = getCurrentAppWindowIDVec();
        if (compositeCapture.addWholeDesktopCapture(captureArgs)) {
            qDebug() << "start screen capturing";
        } else {
            qDebug() << "failed to start screen capturing";
        }
    });
#ifdef __APPLE__
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Metal);
#endif

    // Set up the QML engine
    auto* engine = new QQmlApplicationEngine();
    AppGeneralEventHandler handler;  // Create an instance of the handler

    // Register QMetalGraphicsItem with QML under the module name "CustomItems"
    auto ret = qmlRegisterType<QMetalGraphicsItem>("CustomItems", 1, 0, "MetalGraphicsItem");
    ret = qmlRegisterType<QCustomRenderNode>("CustomRenderItems", 1, 0, "MetalRenderGraphicsItem");

    // Create the model and add data to it
    WindowAbstractListModel windowModel;
    auto& imgProvider = windowModel.getImgProvider();
    engine->addImageProvider("appsnapshotprovider", &imgProvider);
    windowModel.enumAllApps();

    // Expose the model to QML
    engine->rootContext()->setContextProperty("windowListModel", &windowModel);

    // Load the main QML file
    const QUrl url(QStringLiteral("qrc:/main.qml"));

    engine->load(url);
    static QObject s_instance;
    QQmlEngine::setObjectOwnership(&s_instance, QQmlEngine::CppOwnership);

    // Access the root object
    auto rootObjects = engine->rootObjects();
    QObject *rootObject = engine->rootObjects().first();
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
    }
    QObject *appCaptureItem = rootObject->findChild<QObject*>("appCapture");
    if (appCaptureItem) {
        QMetalGraphicsItem *metalItem = qobject_cast<QMetalGraphicsItem*>(appCaptureItem);
        metalItem->setIdName("appCap");
    }

    // find out all app items:
    std::shared_ptr<AppWindowListener> appWinListener = nullptr;
    auto appItem = rootObject->findChild<QObject*>("appItems");
    if (appItem) {
        QObject::connect(appItem, SIGNAL(appItemDoubleClicked(QString)), &handler, SLOT(onItemDoubleClicked(QString)));
        QMetalGraphicsItem *metalItem = qobject_cast<QMetalGraphicsItem*>(appCaptureItem);
        handler.setOnAppItemDBClickHandlerFunc([&, appWinListener](QString appName) mutable{
            auto currentWindow = getCurrentWindow();
            void *nativeWindow = (void*)currentWindow->winId();
            auto& appModel = windowModel.getWindowModelByAppName(appName.toStdString());
            auto appWindowId = (int)std::stoi(appModel.windowHandle().toStdString());
            auto appRect = resizeAndMoveOverlayWindow(nativeWindow, appWindowId);
            auto windowInfo = (WindowSubMsg*)msg.subMsg.get();
            // update info:
            windowInfo->xPos = std::get<0>(appRect);
            windowInfo->yPos = std::get<1>(appRect);
            windowInfo->width = std::get<2>(appRect);
            windowInfo->height = std::get<3>(appRect);
            windowInfo->appPid = std::stoi(appModel.pid().toStdString());
            ignoreMouseInputForAllWindows();
            MetalPipeline::getGlobalInstance().markRenderTargetDirty();

            compositeCapture.stopAllCaptures();
            CaptureArgs captureDesktopArgs;
            captureDesktopArgs.excludingWindowIDs = getCurrentAppWindowIDVec();
            captureDesktopArgs.excludingWindowIDs.push_back(appWindowId);
            captureDesktopArgs.captureEventName = "SpecificDesktopCapture";
            compositeCapture.addWholeDesktopCapture(captureDesktopArgs);

            CaptureArgs captureAppArgs;
            captureAppArgs.captureEventName = appName.toStdString() + "Capture";
            captureAppArgs.includingWindowIDs.push_back(appWindowId);
            compositeCapture.addCaptureByApplicationName(appName.toStdString(), captureAppArgs);

#ifdef __APPLE__
            stickToApp(windowInfo->capturedWinId, windowInfo->appPid, nativeWindow);
#endif

            appWinListener = std::make_shared<AppWindowListener>(windowInfo->appPid, appWindowId);
            // Set the callbacks
            appWinListener->setOnWindowMovedCallback([nativeWindow](float x, float y) {
                std::cout << "Window moved to: (" << x << ", " << y << ")" << std::endl;
                QMetaObject::invokeMethod(QGuiApplication::instance(), [nativeWindow, x, y]() {
                    // Execute some UI-related code here
                    Message msg;
                    NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
                    auto capWinInfo = (WindowSubMsg*)msg.subMsg.get();

                    // Calculate the real cursor position based on scaling
                    int realX = x * capWinInfo->scalingFactor;
                    int realY = y * capWinInfo->scalingFactor;

                    // Check if the cursor is within the window bounds
                    if (isMouseInWindowWithID(nativeWindow)) {
                        // Call wakeUpAppByPID only if cursor is within the window bounds
                        wakeUpAppByPID(capWinInfo->appPid);
                    }

                    // If window position has changed, stick to the app
                    if (capWinInfo->capturedAppX != realX || capWinInfo->capturedAppY != realY) {
                        stickToApp(capWinInfo->capturedWinId, capWinInfo->appPid, nativeWindow);
                    }
                }, Qt::QueuedConnection);
            });

            appWinListener->setOnWindowResizedCallback([nativeWindow](float width, float height) {
                std::cout << "Window resized to: (" << width << ", " << height << ")" << std::endl;
                QMetaObject::invokeMethod(QGuiApplication::instance(), [nativeWindow, width, height]() {
                    Message msg;
                    NotificationCenter::getInstance().getPersistentMessage(MessageType::Render, msg);
                    auto capWinInfo = (WindowSubMsg*)msg.subMsg.get();
                    int realWidth = width * capWinInfo->scalingFactor;
                    int realHeight = height * capWinInfo->scalingFactor;

                    // Check if the cursor is within the window bounds
                    if (isMouseInWindowWithID(nativeWindow)) {
                        // Call wakeUpAppByPID only if cursor is within the window bounds
                        wakeUpAppByPID(capWinInfo->appPid);
                    }

                    if(capWinInfo->capturedAppWidth != realWidth || capWinInfo->capturedAppHeight != realHeight){
                        stickToApp(capWinInfo->capturedWinId, capWinInfo->appPid, nativeWindow);
                    }
                }, Qt::QueuedConnection);

            });

            // Start monitoring (AX API or CGWindow API)
            appWinListener->startCGWindowMonitoring();
        });

    } else {
        qWarning() << "Rectangle object not found!";
    }
    // Connect to the engine's object creation signal
    QObject::connect(engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                if (!obj && url == objUrl)
                    QCoreApplication::exit(-1);
            }, Qt::QueuedConnection);

    auto finalRet = app.exec();
    compositeCapture.stopAllCaptures();
    compositeCapture.cleanUp();
    MetalPipeline::getGlobalInstance().cleanUp();
    return finalRet;
}
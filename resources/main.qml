import QtQuick 2.15
import QtQuick.Controls 2.15
import CustomItems 1.0

ApplicationWindow {
    visible: true
    id: appWindow
    width: 1200
    height: 800
    x: 250
    y: 250
    title: "HidingIn"
    flags: Qt.FramelessWindowHint |Qt.WindowStaysOnTopHint
    StackView {
        id: stackView
        anchors.fill: parent

        initialItem: HomePage{
        }

        // Loaders for each page
        Loader {
            id: capturedAppLoader
            source: "CapturedAppPage.qml"
        }
    }
}

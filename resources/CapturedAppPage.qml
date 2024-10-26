// CapturedApp.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import CustomItems 1.0

Item {
    id: capturedAppPage
    width: 1200
    height: 800

    // Define custom signals that can be connected to C++
    // signal keyPressed(int key)
    // signal mouseClicked(int x, int y)

    MetalGraphicsItem {
        anchors.fill: parent
        id: appCaptureItem
        objectName: "appCapture"
    }

    Button {
        text: "Go Back to First Page"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: {
            stackView.pop()  // Go back to the previous page
        }
    }
}
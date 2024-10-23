// CapturedApp.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: capturedAppPage
    width: 1200
    height: 800

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Text {
            text: "This is the Second Page"
            font.pixelSize: 24
            anchors.centerIn: parent
        }
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
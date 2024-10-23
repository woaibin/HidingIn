import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Rectangle {
    id: customTitleBar
    width: parent.width
    height: 40
    color: "transparent"
    border.color: Qt.rgba(0.5, 0.5, 0.5, 0.2)
    border.width: 2
    // Property to access the parent Window (like ApplicationWindow)
    //property Window windowControl

    // Title text (can be customized via the "title" property)
    property string title: "Custom Title Bar"

    // Title text display
    Text {
        text: customTitleBar.title
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        font.pixelSize: 16
    }

    // Close button
    Button {
        text: "X"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        onClicked: Window.window.close()
        background: Rectangle {
            color: "transparent"  // Make the background transparent
            border.color: "black"  // Keep the border color
            border.width: 1        // Set border width
            radius: 3              // Optional: Add rounded corners if needed
        }
        z: 100
    }

    // Minimize button
    Button {
        text: "_"
        anchors.right: parent.right
        anchors.rightMargin: 40
        anchors.verticalCenter: parent.verticalCenter
        onClicked: Window.window.showMinimized()
        background: Rectangle {
            color: "transparent"  // Make the background transparent
            border.color: "black"  // Keep the border color
            border.width: 1        // Set border width
            radius: 3              // Optional: Add rounded corners if needed
        }
        z: 100
    }

    // Enable dragging the window by clicking and dragging the custom title bar
    MouseArea {
        id: titleBarMouseArea
        anchors.fill: parent
        drag.target: null  // We handle the window dragging manually

        // Store the position where the user clicked
        property real startX
        property real startY

        onPressed: {
            // Save the initial mouse position relative to the window
            startX = mouse.x
            startY = mouse.y
        }

        onPositionChanged: {
            // Move the window based on mouse movement
            Window.window.x += mouse.x - startX
            Window.window.y += mouse.y - startY
        }
        z: 99
    }
}
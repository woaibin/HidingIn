// HomePage.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: homePage
    width: 1200
    height: 800

    // Your existing ApplicationWindow-like structure (without ApplicationWindow)
    FullScreenBackground {
        z: -100
    }

    CustomizeTitleBar {
        id: customTitleBar
        //windowControl: homePage    // Pass the Item as the windowControl
        title: "My Custom App"      // Set the title for the custom title bar
        width: parent.width         // Make the title bar span the entire width
    }

    SplitView {
        width: parent.width
        anchors.fill: parent
        anchors.top: parent.top
        anchors.topMargin: 40
        orientation: Qt.Horizontal
        handle: Rectangle {
            implicitWidth: 2
            implicitHeight: 2
            color: "gray"
            opacity: 0.1  // Set the opacity of the handle (splitter)
            border.color: "black"
        }

        NavSection {
            implicitWidth: 200
        }

        AppListComponent {
            inputWidth: 1000
            inputHeight: 800
        }
    }

    Button {
        text: "Go to Second Page"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: {
            stackView.push(capturedAppLoader)
        }
    }
}
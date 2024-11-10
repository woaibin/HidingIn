import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: appListComponent

    property alias model: appListView.model  // Expose the model property for external use
    property string searchText: ""  // Search text for filtering
    property int inputWidth: width
    property int inputHeight: height

    ColumnLayout {
        anchors.fill: parent

        // Search bar at the top
        Rectangle {
            id: searchBar
            height: 50
            color: "transparent"  // Purple background for the search bar
            width: inputWidth * 0.5
            Layout.alignment: Qt.AlignHCenter  // Align the search bar horizontally in the parent

            RowLayout {
                anchors.fill: parent
                TextField {
                    id: searchField
                    placeholderText: "Search for app..."
                    Layout.fillWidth: true
                    onTextChanged: {
                        appListComponent.searchText = text
                        windowListModel.searchApp(text)
                    }
                }
            }
        }

        // ListView to display window data
        ScrollView {
            Layout.fillHeight: true
            clip: true
            background: Rectangle { color: "transparent" }
            ScrollBar.vertical: ScrollBar {
                background: Rectangle { color: "transparent" }
                policy: ScrollBar.AlwaysOff
            }
            Layout.alignment: Qt.AlignHCenter  // Align the search bar horizontally in the parent
            width: inputWidth

            ListView {
                id: appListView
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                model: windowListModel  // The ListModel is defined below
                objectName: "appItems"

                signal appItemDoubleClicked(appName: string)  // Custom signal to emit on double-click

                delegate: Item {
                    width: 1000  // Set both width and height to make it a square
                    height: 300
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onDoubleClicked: {
                            stackView.push(capturedAppLoader)
                            appListView.appItemDoubleClicked(appName)  // Emit the signal to the C++ side
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: 10
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5

                            // App frame content (using a Rectangle for rounded corners)
                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height * 0.9  // Ensure the image area is square
                                radius: 5  // Rounded corners for the image container
                                clip: true  // Clip the image to the rounded corners
                                anchors.horizontalCenter: parent.horizontalCenter

                                Image {
                                    anchors.fill: parent
                                    source: frameContent  // Placeholder image or actual app frame
                                    fillMode: Image.PreserveAspectCrop

                                }
                            }

                            // App name text
                            Text {
                                text: appName
                                color: "yellow"
                                font.bold: true
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter  // Center the text horizontally
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // App window handle or other metadata
                            Text {
                                text: "Handle: " + windowHandle
                                color: "yellow"
                                font.pixelSize: 7
                                horizontalAlignment: Text.AlignHCenter  // Center the text horizontally
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
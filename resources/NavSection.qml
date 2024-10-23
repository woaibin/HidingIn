import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: navSection
    width: parent.width * 0.2
    anchors.top : parent.top
    anchors.topMargin: parent.height * 0.03

    Column {
        spacing: 60
        anchors.fill:parent
        anchors.horizontalCenter:parent.horizontalCenter
        Rectangle {
            width: parent.width
            height: 50
            anchors.left: parent.left
            anchors.leftMargin: 10
            color: "transparent"
            Text{
                text: "HidingIn"
                font.pointSize: 30
                font.bold: true
            }
        }
        Rectangle {
            width: parent.width
            height: 50
            color: "transparent"
            Row{
                spacing: 15  // The distance between each child
                anchors.left: parent.left
                anchors.leftMargin: 20
                Image {
                    source: "qrc:/icon/home.png"  // Access the resource using qrc:/ prefix
                    width: 32
                    height: 32
                }
                Text{
                    text: "Home"
                    font.pointSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 50
            color: "transparent"
            Row{
                spacing: 15  // The distance between each child
                anchors.left: parent.left
                anchors.leftMargin: 20
                Image {
                    source: "qrc:/icon/home.png"  // Access the resource using qrc:/ prefix
                    width: 32
                    height: 32
                }
                Text{
                    text: "Settings"
                    font.pointSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 50
            color: "transparent"
        }
    }
}
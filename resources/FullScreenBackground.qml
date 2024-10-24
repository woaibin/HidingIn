// FullScreenBackground.qml
import QtQuick 2.15
import CustomItems 1.0

Item {
    // The source of the background image can be set from outside
    //property alias source: backgroundImage.source

    // Fill the parent (i.e., the window or container using this component)
    anchors.fill: parent

    // Image {
    //     id: backgroundImage
    //     anchors.fill: parent  // Ensure the image fills the whole space
    //     fillMode: Image.PreserveAspectCrop  // Preserve aspect ratio and crop as necessary
    //     z: -1  // Ensure it's behind other elements
    // }
    MetalGraphicsItem {
        anchors.fill: parent
        id: backgroundCaptureItem
        objectName: "transparentBgCapture"
    }
}
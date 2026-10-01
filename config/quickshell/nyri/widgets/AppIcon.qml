import QtQuick
import qs.theme

Item {
    id: root
    property url source
    property real implicitSize: 24
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) * 0.26
        color: Colors.m3secondaryContainer
        visible: appImage.status !== Image.Ready
        MIcon {
            anchors.centerIn: parent
            icon: "apps"
            size: Math.min(parent.width, parent.height) * 0.64
            color: Colors.m3onSecondaryContainer
        }
    }
    property real raster: 72
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    Image {
        id: appImage
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: status === Image.Ready
        sourceSize: Qt.size(Math.max(1, Math.ceil(root.raster * root.dpr)), Math.max(1, Math.ceil(root.raster * root.dpr)))
    }
}

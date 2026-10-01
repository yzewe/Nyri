import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Island {
    id: root

    readonly property var player: Media.player
    property real room: Infinity
    readonly property real textRoom: Math.min(200, room - padding * 2 - 28 * 2 - spacing * 2)
    visible: player !== null
    padding: 6
    spacing: 8

    StateLayer {
        parent: root
        radius: root.height / 2
        onClicked: Panels.toggleFrom("player", root)
    }

    ClippingRectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: Colors.m3primaryContainer
        Image {
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            sourceSize: Qt.size(128, 128)
            asynchronous: true
        }
    }
    FlowText {
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.o.bar.mediaTitle && root.textRoom >= 40
        maxWidth: root.textRoom
        width: implicitWidth
        elide: Text.ElideRight
        textStyle: Type.labelLarge
        text: root.player?.trackTitle || root.player?.identity || ""
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        size: 28
        iconSize: 18
        icon: root.player?.isPlaying ? "pause" : "play_arrow"
        onClicked: root.player?.togglePlaying()
    }
}

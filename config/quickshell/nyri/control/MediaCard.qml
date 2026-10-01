import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Rectangle {
    id: root

    required property bool active
    readonly property var player: Media.player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool hasArt: art.status === Image.Ready

    implicitHeight: 212
    radius: Shape.extraLarge
    color: Colors.m3surfaceContainerHigh

    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {
        running: root.active && root.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player.positionChanged()
    }

    ClippingRectangle {
        id: cover
        anchors.right: parent.right
        width: parent.width * 0.62
        height: parent.height
        radius: root.radius

        Image {
            id: art
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            sourceSize: Qt.size(512, 512)
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { EffectAnim {} }
        }

        MaterialShape {
            visible: !root.hasArt
            anchors.right: parent.right
            anchors.rightMargin: -40
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height * 1.1
            height: width
            shape: "cookie9Sided"
            color: Colors.m3secondaryContainer
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.color }
                GradientStop { position: 0.45; color: Qt.alpha(root.color, 0.75) }
                GradientStop { position: 1.0; color: Qt.alpha(root.color, 0.05) }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 72
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(root.color, 0) }
                GradientStop { position: 1.0; color: Qt.alpha(root.color, 0.92) }
            }
        }
    }

    Column {
        x: 20
        y: 18
        width: parent.width * 0.62
        spacing: 2

        Row {
            spacing: 6
            bottomPadding: 8

            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "graphic_eq"
                size: 16
                color: Colors.m3primary
            }
            FlowText {
                anchors.verticalCenter: parent.verticalCenter
                textStyle: Type.labelMedium
                color: Colors.m3primary
                text: root.player?.identity ?? ""
            }
        }

        FlowText {
            width: parent.width
            elide: Text.ElideRight
            textStyle: ({ size: 22, weight: 650, rond: 50 })
            text: root.player?.trackTitle || "Ничего не играет"
        }

        FlowText {
            width: parent.width
            elide: Text.ElideRight
            textStyle: Type.bodyMedium
            color: Colors.m3onSurfaceVariant
            text: root.player?.trackArtist ?? ""
        }
    }

    Row {
        id: controls
        x: 14
        y: 110
        spacing: 6
        enabled: root.player !== null
        opacity: enabled ? 1 : 0.4
        Behavior on opacity { EffectAnim {} }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_previous"
            size: 44
            iconSize: 26
            enabled: root.player?.canGoPrevious ?? false
            opacity: enabled ? 1 : 0.4
            onClicked: root.player.previous()
        }

        Item {
            id: play
            anchors.verticalCenter: parent.verticalCenter
            width: 60
            height: 60
            scale: squish.value
            SpringValue { id: squish; target: playArea.pressed ? 0.86 : 1; damping: 0.45; stiffness: 900; epsilon: 0.001 }

            MaterialShape {
                anchors.fill: parent
                shape: root.playing ? "square" : "circle"
                color: Colors.m3primary
            }
            MIcon {
                anchors.centerIn: parent
                icon: root.playing ? "pause" : "play_arrow"
                size: 30
                fill: 1
                color: Colors.m3onPrimary
            }
            StateLayer {
                id: playArea
                radius: root.playing ? width * 0.3 : width / 2
                color: Colors.m3onPrimary
                onClicked: root.player?.togglePlaying()
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_next"
            size: 44
            iconSize: 26
            enabled: root.player?.canGoNext ?? false
            opacity: enabled ? 1 : 0.4
            onClicked: root.player.next()
        }
    }

    Row {
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: parent.width - 40
        spacing: 12
        visible: root.player?.lengthSupported ?? false

        MText {
            id: pos
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            textStyle: Type.labelMedium
            font.features: { "tnum": 1 }
            color: Colors.m3onSurfaceVariant
            text: root.fmt(root.player?.position ?? 0)
        }

        WavyProgress {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - pos.width - len.width - 24
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
            wavy: root.playing
            flowing: root.active && root.playing
            onSeek: v => { if (root.player?.canSeek) root.player.position = v * root.player.length }
        }

        MText {
            id: len
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            textStyle: Type.labelMedium
            font.features: { "tnum": 1 }
            color: Colors.m3onSurfaceVariant
            text: root.fmt(root.player?.length ?? 0)
        }
    }
}

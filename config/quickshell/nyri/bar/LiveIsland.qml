import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Island {
    id: root

    property bool media: true
    readonly property var items: media ? Activities.loud : Activities.loud.filter(a => a.kind !== "media")
    readonly property var main: items[0] ?? null
    readonly property var rest: items.slice(1, 4)
    readonly property bool loud: main?.tone === "error"
    readonly property bool has: main !== null

    padding: has ? 6 : 0
    spacing: 8
    widthSpeed: loud ? "fast" : "default"
    color: loud ? Colors.m3errorContainer : Colors.m3surfaceContainer
    readonly property bool present: grow.value > 0.02
    visible: present
    opacity: Math.min(1, grow.value * 1.5) * Math.min(1, intro * 2)
    SpringValue { id: grow; target: root.has ? 1 : 0; damping: 0.62; stiffness: 420 }

    property real now: Date.now()
    Timer {
        running: root.visible && (root.main?.since > 0 || root.main?.until > 0)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
    function clock(ms) {
        const s = Math.max(0, Math.round(ms / 1000)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0");
    }

    StateLayer {
        parent: root
        radius: root.height / 2
        color: root.loud ? Colors.m3onErrorContainer : Colors.m3onSurface
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton || !root.main) Panels.toggleFrom("live", root);
            else if (root.main.kind === "media") Panels.toggleFrom("player", root);
            else if (["record", "timer", "stopwatch", "job", "copy", "update", "done", "downloaded"].indexOf(root.main.kind) >= 0) Panels.toggleFrom("live", root);
            else Activities.open(root.main);
        }
    }

    Item {
        id: badge
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28

        CircularProgress {
            anchors.fill: parent
            anchors.margins: -2
            readonly property bool ring: (root.main?.progress ?? -1) >= 0 && ["media", "phone", "bt"].indexOf(root.main?.kind) < 0
            visible: ring
            stroke: 3
            value: Math.max(0, root.main?.progress ?? 0)
            activeColor: root.loud ? Colors.m3error : Colors.m3primary
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: (root.main?.progress ?? -1) >= 0 && ["media", "phone", "bt"].indexOf(root.main?.kind) < 0 ? 4 : 0
            radius: width / 2
            visible: !art.visible
            color: root.loud ? Colors.m3error : Colors.m3primaryContainer
            SequentialAnimation on opacity {
                running: root.loud && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) parent.opacity = 1
            }
            MIcon {
                anchors.centerIn: parent
                icon: root.main?.icon ?? ""
                size: parent.width > 22 ? 18 : 14
                fill: 1
                color: root.loud ? Colors.m3onError : Colors.m3onPrimaryContainer
            }
        }
        ClippingRectangle {
            id: art
            anchors.fill: parent
            radius: width / 2
            visible: root.main?.kind === "media" && cover.status === Image.Ready
            Image {
                id: cover
                anchors.centerIn: parent
                width: parent.width + 2
                height: parent.height + 2
                source: root.main?.kind === "media" ? (root.main.cover || Media.art) : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                sourceSize: Qt.size(128, 128)
                asynchronous: true
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio * 2), Math.ceil(height * Screen.devicePixelRatio * 2))
                transformOrigin: Item.Center
                RotationAnimation on rotation {
                    running: art.visible && root.visible
                    from: 0; to: 360; duration: 8000; loops: Animation.Infinite
                }
            }
        }
    }

    FlowText {
        anchors.verticalCenter: parent.verticalCenter
        maxWidth: 190
        width: implicitWidth
        elide: Text.ElideRight
        textStyle: Type.labelLargeEmph
        animate: root.main?.kind !== "mic" && root.main?.kind !== "camera" && !root.loud
        color: root.loud ? Colors.m3onErrorContainer : Colors.m3onSurface
        text: root.main?.title ?? ""
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.main?.kind === "media"
        spacing: 2
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                radius: 1.5
                height: 6
                color: Colors.m3primary
                SequentialAnimation on height {
                    running: root.visible && root.main?.kind === "media"
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 120 }
                    NumberAnimation { to: 14; duration: 280 + index * 60; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 5; duration: 320 + index * 40; easing.type: Easing.InQuad }
                }
            }
        }
    }

    RollingText {
        anchors.verticalCenter: parent.verticalCenter
        visible: text !== ""
        textStyle: Type.labelLargeEmph
        color: root.loud ? Colors.m3error : Colors.m3primary
        text: (root.main?.frozen ?? -1) >= 0 ? root.clock(root.main.frozen)
            : root.main?.until > 0 ? root.clock(root.main.until - root.now)
            : root.main?.since > 0 ? root.clock(root.now - root.main.since) : ""
    }

    Repeater {
        model: root.rest.length
        Rectangle {
            required property int index
            readonly property var a: root.rest[index]
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 12
            color: a?.tone === "error" ? Colors.m3error : Colors.m3secondaryContainer
            MIcon {
                anchors.centerIn: parent
                icon: parent.a?.icon ?? ""
                size: 15
                fill: 1
                color: parent.a?.tone === "error" ? Colors.m3onError : Colors.m3onSecondaryContainer
            }
        }
    }

    Item { width: 2; height: 1 }
}

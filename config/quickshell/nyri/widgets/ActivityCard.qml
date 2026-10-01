import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services

Rectangle {
    id: root

    required property var activity
    readonly property var a: activity
    readonly property bool loud: a?.tone === "error"
    property bool compact: false

    implicitHeight: col.implicitHeight + 24

    SpringValue { id: born; target: 1; damping: 0.62; stiffness: 420; Component.onCompleted: { value = 0; running = true; } }
    scale: 0.85 + 0.15 * Math.min(1.05, born.value)
    opacity: Math.min(1, born.value * 1.5)
    radius: Shape.largeIncreased
    color: loud ? Colors.m3errorContainer : Colors.m3surfaceContainerHigh
    Behavior on color { ColorAnim {} }

    readonly property color ink: loud ? Colors.m3onErrorContainer : Colors.m3onSurface
    readonly property color soft: loud ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant

    property real now: Date.now()
    Timer {
        running: root.visible && (root.a?.since > 0 || root.a?.until > 0)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
    function clock(ms) {
        const s = Math.max(0, Math.round(ms / 1000)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0");
    }
    readonly property string time: a?.frozen >= 0 && a?.frozen !== undefined ? clock(a.frozen) : a?.until > 0 ? clock(a.until - now) : a?.since > 0 ? clock(now - a.since) : ""

    StateLayer {
        radius: root.radius
        color: root.ink
        onClicked: Activities.open(root.a)
    }

    Column {
        id: col
        x: 14
        y: 12
        width: parent.width - 28
        spacing: 10

        Row {
            width: parent.width
            spacing: 12

            Item {
                width: 44
                height: 44
                anchors.verticalCenter: parent.verticalCenter

                MaterialShape {
                    anchors.fill: parent
                    visible: !cover.visible
                    shape: root.a?.kind === "timer" ? "clover4Leaf" : root.loud ? "softBurst" : "cookie9Sided"
                    color: root.loud ? Colors.m3error : Colors.m3primaryContainer
                    rotation: spin.value
                    SpringValue { id: spin; target: 0; damping: 0.6; stiffness: 90 }
                }
                MIcon {
                    anchors.centerIn: parent
                    visible: !cover.visible
                    icon: root.a?.icon ?? ""
                    size: 22
                    fill: 1
                    color: root.loud ? Colors.m3onError : Colors.m3onPrimaryContainer
                }
                ClippingRectangle {
                    id: cover
                    anchors.fill: parent
                    radius: Shape.medium
                    visible: (root.a?.cover ?? "") !== "" && img.status === Image.Ready
                    Image { id: img; anchors.fill: parent; source: root.a?.cover || (root.a?.kind === "media" ? Media.art : ""); fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true; sourceSize: Qt.size(176, 176) }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - 12 - (timeText.visible ? timeText.width + 12 : 0)
                spacing: 1
                FlowText {
                    width: parent.width
                    elide: Text.ElideRight
                    textStyle: Type.titleSmall
                    color: root.ink
                    text: root.a?.title ?? ""
                }
                FlowText {
                    width: parent.width
                    visible: text !== ""
                    elide: Text.ElideRight
                    textStyle: Type.labelMedium
                    color: root.soft
                    text: root.a?.text ?? ""
                }
            }

            RollingText {
                id: timeText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.time !== ""
                textStyle: Type.titleMediumEmph
                color: root.loud ? Colors.m3onErrorContainer : Colors.m3primary
                text: root.time
            }
        }

        Item {
            width: parent.width
            height: 16
            visible: (root.a?.progress ?? -1) >= 0 || root.a?.progress === -2
            WavyProgress {
                anchors.fill: parent
                value: root.a?.progress >= 0 ? root.a.progress : 0.35
                wavy: true
                flowing: root.visible
                activeColor: root.loud ? Colors.m3onErrorContainer : Colors.m3primary
            }
        }

        Flow {
            width: parent.width
            spacing: 8
            visible: !root.compact && (root.a?.actions?.length ?? 0) > 0

            Repeater {
                model: root.a?.actions ?? []
                Rectangle {
                    id: act
                    required property var modelData
                    height: 36
                    width: actRow.implicitWidth + 28
                    radius: actLayer.pressed ? Shape.medium : height / 2
                    color: root.loud ? Colors.m3error : Colors.m3secondaryContainer
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    Row {
                        id: actRow
                        anchors.centerIn: parent
                        spacing: 6
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: act.modelData.icon; size: 18; fill: 1; color: root.loud ? Colors.m3onError : Colors.m3onSecondaryContainer }
                        MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; color: root.loud ? Colors.m3onError : Colors.m3onSecondaryContainer; text: act.modelData.label }
                    }
                    StateLayer {
                        id: actLayer
                        radius: act.radius
                        color: root.loud ? Colors.m3onError : Colors.m3onSecondaryContainer
                        onClicked: {
                            spin.target += 90;
                            if (act.modelData.key === "folder") Activities.open(root.a);
                            else Activities.act(root.a.id, act.modelData.key);
                        }
                    }
                }
            }
        }
    }
}

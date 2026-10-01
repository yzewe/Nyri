import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

PanelWindow {
    id: root

    readonly property real progress: spring.value

    SpringValue {
        id: spring
        target: Osd.shown ? 1 : 0
        damping: Osd.shown ? 0.6 : 1.0
        stiffness: Osd.shown ? 600 : 500
    }

    screen: Panels.screen
    visible: true
    color: "transparent"
    readonly property string where: {
        const p = Config.o.osd.position;
        if (p === "top" || p === "bottom" || p === "center") return p;
        return (p === "opposite") !== Panels.barBottom ? "bottom" : "top";
    }
    anchors.top: where === "top"
    anchors.bottom: where === "bottom"
    margins.top: where === "top" ? (Panels.barBottom ? 24 : 12 + 40 + 8) : 0
    margins.bottom: where === "bottom" ? (Panels.barBottom ? 12 + 40 + 8 : 32) : 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Osd.kind === "layout" ? 232 : Osd.kind === "mic" ? 320 : card.full + 32
    implicitHeight: card.height + 32
    mask: Region {}

    WlrLayershell.namespace: "nyri-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property var spec: {
        switch (Osd.kind) {
        case "volume":
            return { icon: Audio.icon, value: Audio.muted ? 0 : Audio.volume, dim: Audio.muted };
        case "mic":
            return { icon: Audio.micMuted ? "mic_off" : "mic", text: Audio.micMuted ? "Микрофон выключен" : "Микрофон включён" };
        case "brightness":
            return { icon: Brightness.level < 0.35 ? "brightness_low" : Brightness.level < 0.7 ? "brightness_medium" : "brightness_high", value: Brightness.level };
        case "caps":
            return { icon: "keyboard_capslock", text: Toggles.capsLock ? "Caps Lock включён" : "Caps Lock выключен", dim: !Toggles.capsLock };
        case "layout":
            return { icon: "keyboard", text: Compositor.layoutNames[Compositor.layoutIndex] ?? "" };
        }
        return { icon: "info" };
    }

    Card {
        id: card
        visible: Osd.kind !== "layout" && Osd.kind !== "mic"
        readonly property real full: row.implicitWidth + 8 + 20
        y: 16 + (1 - root.progress) * (root.where === "bottom" ? 24 : -24)
        width: 56 + (full - 56) * Math.max(0, root.progress)
        x: 16 + (full - width) / 2
        height: 56
        radius: height / 2
        color: Colors.m3surfaceContainerHigh
        elevation: 3
        opacity: Math.max(0, Math.min(1, root.progress * 3))
        clip: true

        Row {
            id: row
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: root.spec.dim ? Colors.m3surfaceContainerHighest : Colors.m3primaryContainer

                MIcon {
                    anchors.centerIn: parent
                    icon: root.spec.icon
                    fill: 1
                    color: root.spec.dim ? Colors.m3onSurfaceVariant : Colors.m3onPrimaryContainer
                }
            }

            Reveal {
                shown: root.spec.value !== undefined
            MSlider {
                implicitWidth: 220
                implicitHeight: 40
                width: 220
                interactive: false
                value: root.spec.value ?? 0
                activeColor: root.spec.dim ? Colors.m3outline : Colors.m3primary
            }
            }

            Reveal {
                shown: root.spec.value !== undefined
            Item {
                implicitWidth: 34
                implicitHeight: 24

                RollingText {
                    anchors.centerIn: parent
                    textStyle: Type.titleMediumEmph
                    text: String(Math.round((root.spec.value ?? 0) * 100))
                }
            }
            }

            Reveal {
                shown: root.spec.text !== undefined
            FlowText {
                rightPadding: 12
                textStyle: Type.titleMediumEmph
                text: root.spec.text ?? ""
            }
            }
        }
    }

    Rectangle {
        visible: Osd.kind === "layout" || Osd.kind === "mic"
        readonly property real fullWidth: layoutText.implicitWidth + 66
        x: (root.width - width) / 2
        y: 16 + (1 - root.progress) * (root.where === "bottom" ? 24 : -24)
        width: 56 + (fullWidth - 56) * Math.max(0, Math.min(1, root.progress))
        height: 56
        radius: 28
        color: Colors.m3surfaceContainerHigh
        opacity: Math.max(0, Math.min(1, root.progress * 2))
        clip: true

        MIcon {
            x: 17 - Math.max(0, Math.min(1, root.progress))
            anchors.verticalCenter: parent.verticalCenter
            icon: root.spec.icon
            size: 22
            color: Colors.m3primary
        }
        FlowText {
            id: layoutText
            x: 50
            width: implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            textStyle: Type.titleMedium
            animate: (Osd.kind === "layout" || Osd.kind === "mic") && root.progress > 0.95
            opacity: Math.max(0, Math.min(1, (root.progress - 0.15) * 1.4))
            text: root.spec.text ?? ""
        }
    }
}

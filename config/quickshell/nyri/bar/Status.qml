import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets

Island {
    id: root

    readonly property bool chips: Config.o.bar.style === "chips"
    readonly property var segs: [
        Toggles.recording ? "rec" : "",
        Config.o.bar.layout ? "layout" : "",
        Audio.sink !== null && Config.o.bar.volume ? "volume" : "",
        Notifs.count > 0 || Notifs.dnd || Toggles.caffeine ? "notif" : "",
        "battery"
    ].filter(Boolean)
    function seg(id) { return segs[0] === id ? (segs.length === 1 ? "only" : "first") : segs[segs.length - 1] === id ? "last" : "middle"; }
    split: true
    padding: chips ? 0 : 4
    spacing: chips ? 3 : 0

    Reveal {
        shown: Toggles.recording

        Chip {
            pill: root.chips
            segment: root.seg("rec")
            segmentColor: Colors.m3errorContainer
            id: rec
            property int secs: 0
            onClicked: Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"])

            Timer {
                running: Toggles.recording
                interval: 1000
                repeat: true
                triggeredOnStart: true
                onTriggered: rec.secs = Math.floor((Date.now() - Toggles.recordingSince) / 1000)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Colors.m3error
            }

            RollingText {
                anchors.verticalCenter: parent.verticalCenter
                textStyle: Type.labelLargeEmph
                color: Colors.m3error
                text: Math.floor(rec.secs / 60) + ":" + String(rec.secs % 60).padStart(2, "0")
            }
        }
    }

    Chip {
        pill: root.chips
        segment: root.seg("layout")
        visible: Config.o.bar.layout
        onClicked: Compositor.action("switch-layout", "next")

        MText {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            horizontalAlignment: Text.AlignHCenter
            textStyle: Type.labelLargeEmph
            color: Colors.m3onSurfaceVariant
            text: Compositor.layoutShort
        }

        Reveal {
            shown: Toggles.capsLock

            Rectangle {
                implicitWidth: capsText.implicitWidth + 10
                implicitHeight: 18
                radius: 6
                color: Colors.m3primary

                MText {
                    id: capsText
                    anchors.centerIn: parent
                    textStyle: Type.labelSmall
                    font.variableAxes: ({ "wght": 800 })
                    color: Colors.m3onPrimary
                    text: "CAPS"
                }
            }
        }
    }

    Chip {
        pill: root.chips
        segment: root.seg("volume")
        visible: Audio.sink !== null && Config.o.bar.volume
        onClicked: m => m.button === Qt.RightButton ? Panels.toggleFrom("control", root) : Audio.toggleMute()
        onWheel: event => { if (!Audio.muted) Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)); }

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Audio.icon
            fill: Audio.muted ? 0 : 1
            color: Audio.muted ? Colors.m3outline : Colors.m3onSurfaceVariant
        }

        RollingText {
            anchors.verticalCenter: parent.verticalCenter
            textStyle: Type.labelLarge
            color: Colors.m3onSurfaceVariant
            text: String(Audio.muted ? 0 : Math.round(Audio.volume * 100))
        }
    }

    Reveal {
        shown: Notifs.count > 0 || Notifs.dnd || Toggles.caffeine

        Chip {
            pill: root.chips
            segment: root.seg("notif")
            padding: 8
            spacing: 2
            onClicked: Panels.toggleFrom("control", root)

            Reveal {
                shown: Toggles.caffeine
                MIcon {
                    icon: "coffee"
                    size: 18
                    fill: 1
                    color: Colors.m3primary
                }
            }

            Reveal {
                shown: Notifs.dnd || Notifs.count > 0
                MIcon {
                    icon: Notifs.dnd ? "do_not_disturb_on" : "notifications_unread"
                    size: 18
                    fill: 1
                    color: Notifs.dnd ? Colors.m3onSurfaceVariant : Colors.m3primary
                }
            }
        }
    }

    Chip {
        pill: root.chips
        segment: root.seg("battery")
        id: batteryChip
        padding: 8
        onClicked: Panels.toggleFrom("power", batteryChip, "battery")
        Battery {}
    }
}

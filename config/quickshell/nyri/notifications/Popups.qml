import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

PanelWindow {
    id: root

    screen: Panels.screen
    visible: Notifs.popups.count > 0 || exitTimer.running
    color: "transparent"
    readonly property string side: Config.o.notifications.position
    readonly property int away: side === "left" ? -1 : 1
    readonly property int gap: 12
    anchors { top: true; right: side === "right"; left: side === "left" }
    margins { top: Panels.barBottom ? 4 : 12 + 40 + 4; right: 0 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 400 + 24
    implicitHeight: (screen?.height ?? 1080) - (Panels.barBottom ? 4 + 12 + 40 + 12 : 12 + 40 + 4 + 12)
    mask: Region { item: hit }

    Item {
        id: hit
        x: stack.x
        y: stack.y
        width: stack.width
        height: stack.implicitHeight
    }

    WlrLayershell.namespace: "nyri-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Timer {
        id: exitTimer
        interval: 240
    }
    Connections {
        target: Notifs.popups
        function onCountChanged() { if (Notifs.popups.count === 0) exitTimer.restart() }
    }

    Column {
        id: stack
        x: 12
        y: 8
        width: 400
        spacing: root.gap

        Repeater {
            model: Notifs.popups

            Item {
                id: slot

                required property int nid
                readonly property var notif: Notifs.find(nid)
                readonly property real full: Math.max(card.implicitHeight, 1)

                property string phase: "idle"
                property bool done: false
                property real xoff: 0
                property real box: full

                width: stack.width
                height: phase === "collapse" ? box : full
                clip: phase === "collapse"

                Behavior on height {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                        onFinished: if (slot.phase === "collapse" && slot.height < 2) slot.finish()
                    }
                }

                function leave(dir) {
                    if (phase !== "idle") return;
                    phase = "out";
                    exit.to = (dir < 0 ? -1 : 1) * (width + 24);
                    exit.restart();
                }

                function finish() {
                    if (done) return;
                    done = true;
                    if (notif) notif.dismiss();
                    else Notifs.hidePopup(nid);
                }

                NotificationCard {
                    id: card
                    width: parent.width
                    height: implicitHeight
                    y: 0
                    x: drag.active ? drag.activeTranslation.x : slot.xoff
                    notif: slot.notif
                    popup: true
                    animateClose: true
                    onCloseRequested: slot.leave(root.away)
                }

                HoverHandler { id: hover }

                Timer {
                    interval: Notifs.timeoutFor(slot.notif)
                    running: interval > 0 && slot.phase === "idle" && !hover.hovered
                    onTriggered: slot.leave(root.away)
                }

                NumberAnimation {
                    id: exit
                    target: slot
                    property: "xoff"
                    duration: 100
                    easing.type: Easing.InCubic
                    onFinished: {
                        slot.box = 0;
                        slot.phase = "collapse";
                    }
                }

                NumberAnimation {
                    id: back
                    target: slot
                    property: "xoff"
                    to: 0
                    duration: 160
                    easing.type: Easing.OutCubic
                }

                DragHandler {
                    id: drag
                    target: null
                    enabled: slot.phase === "idle"
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (active) {
                            back.stop();
                            return;
                        }
                        if (slot.phase !== "idle") return;
                        slot.xoff = activeTranslation.x;
                        if (Math.abs(slot.xoff) > slot.width * 0.28)
                            slot.leave(Math.sign(slot.xoff) || root.away);
                        else
                            back.restart();
                    }
                }
            }
        }
    }
}

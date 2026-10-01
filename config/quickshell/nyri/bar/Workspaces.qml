import QtQuick
import qs.theme
import qs.services
import qs.widgets

Island {
    id: root

    required property string output
    readonly property var list: Compositor.workspacesOn(output)

    readonly property string look: Config.o.bar.workspaces
    padding: look === "numbers" ? 6 : 14
    spacing: look === "numbers" ? 4 : 6

    Repeater {
        model: root.list.length

        Item {
            id: dot

            required property int index
            readonly property var ws: root.list[index]
            readonly property bool active: ws?.is_active ?? false
            readonly property bool urgent: ws?.is_urgent ?? false
            readonly property bool occupied: ws ? Compositor.windowCount(ws.id) > 0 : false

            anchors.verticalCenter: parent.verticalCenter
            width: w.value
            height: h.value

            SpringValue {
                id: w
                target: root.look === "numbers" ? (dot.active ? 40 : 28)
                      : root.look === "dots" ? (dot.active ? 14 : hit.containsMouse ? 10 : 8)
                      : dot.active ? 36 : hit.containsMouse ? 14 : 10
                damping: 0.55; stiffness: 700
            }
            SpringValue {
                id: h
                target: root.look === "numbers" ? 28 : root.look === "dots" ? (dot.active ? 14 : hit.containsMouse ? 10 : 8) : dot.active ? 12 : 10
                damping: 0.55; stiffness: 700
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: dot.urgent ? Colors.m3error
                     : dot.active ? Colors.m3primary
                     : root.look === "numbers" ? (dot.occupied ? Colors.m3secondaryContainer : "transparent")
                     : dot.occupied ? Colors.m3onSurfaceVariant
                     : Colors.m3outlineVariant

                Behavior on color { ColorAnim {} }

                MText {
                    anchors.centerIn: parent
                    visible: root.look === "numbers"
                    textStyle: Type.labelLargeEmph
                    color: dot.active ? Colors.m3onPrimary : dot.occupied ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                    text: dot.ws?.idx ?? ""
                }
            }

            MouseArea {
                id: hit
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Compositor.action("focus-workspace", String(dot.ws.idx))
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Compositor.action(event.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up")
    }
}

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets
import qs.popouts

Island {
    id: root

    required property var barWindow
    readonly property int inline: 4
    readonly property var items: SystemTray.items.values
    readonly property bool hasItems: items.length > 0

    padding: 4
    spacing: 0

    TrayContextMenu { id: contextMenu; hostWindow: root.barWindow }

    Repeater {
        model: ScriptModel { values: root.items.slice(0, root.inline) }

        TrayIcon {
            required property var modelData
            item: modelData
            window: root.barWindow
        }
    }

    Chip {
        id: more
        visible: root.items.length > root.inline
        padding: 6
        onClicked: Panels.toggleFrom("tray", more)

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "expand_more"
            size: 20
            rotation: Panels.current === "tray" ? 180 : 0
            color: Colors.m3onSurfaceVariant

            Behavior on rotation { SpatialAnim { speed: "fast" } }
        }

        MText {
            anchors.verticalCenter: parent.verticalCenter
            textStyle: Type.labelMedium
            color: Colors.m3onSurfaceVariant
            text: "+" + (root.items.length - root.inline)
        }
    }

    component TrayIcon: Chip {
        id: chip

        property var item
        property var window

        padding: 8
        implicitWidth: 32

        property bool born: false
        Component.onCompleted: Qt.callLater(() => chip.born = true)
        SpringValue { id: pop; target: chip.born ? 1 : 0; damping: 0.55; stiffness: 420 }

        TrayGlyph {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            source: chip.item.icon
            scale: Math.max(0, pop.value)
            rotation: (1 - pop.value) * -120
            opacity: Math.min(1, Math.max(0, pop.value))
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !chip.item.onlyMenu) {
                chip.item.activate();
            } else if (mouse.button === Qt.MiddleButton) {
                chip.item.secondaryActivate();
            } else if (chip.item.hasMenu) {
                contextMenu.openFor(chip.item, chip);
            }
        }
        onWheel: event => chip.item.scroll(event.angleDelta.y, false)
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

PanelWindow {
    id: root

    property bool open: false
    property int current: 0
    property var list: []
    readonly property real progress: spring.value

    SpringValue {
        id: spring
        target: root.open ? 1 : 0
        damping: root.open ? 0.6 : 1.0
        stiffness: root.open ? 700 : 600
    }

    function step(dir) {
        if (!open) {
            list = Object.values(Compositor.windows).sort((a, b) =>
                (b.focus_timestamp?.secs ?? 0) - (a.focus_timestamp?.secs ?? 0)
                || (b.focus_timestamp?.nanos ?? 0) - (a.focus_timestamp?.nanos ?? 0));
            if (list.length < 2) {
                if (list.length === 1) Compositor.action("focus-window", "--id", String(list[0].id));
                return;
            }
            current = dir > 0 ? 1 : list.length - 1;
            open = true;
        } else {
            current = (current + dir + list.length) % list.length;
        }
        commitTimer.restart();
    }

    function commit() {
        if (!open) return;
        const w = list[current];
        open = false;
        commitTimer.stop();
        if (w) Compositor.action("focus-window", "--id", String(w.id));
    }

    Timer {
        id: commitTimer
        interval: 1500
        onTriggered: root.commit()
    }

    screen: Panels.screen
    visible: open || progress > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nyri-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: root.open

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L)
                root.commit();
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.open = false; commitTimer.stop(); }
            else if (event.key === Qt.Key_Return) root.commit();
            else if (event.key === Qt.Key_Right) root.step(1);
            else if (event.key === Qt.Key_Left) root.step(-1);
            else return;
            event.accepted = true;
        }
    }

    Card {
        anchors.centerIn: parent
        width: row.implicitWidth + 24
        height: 176
        color: Colors.m3surfaceContainer
        elevation: 3
        opacity: Math.max(0, Math.min(1, root.progress * 1.5))
        scale: 0.9 + 0.1 * root.progress

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.list

                Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool selected: root.current === index
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData.app_id)

                    width: 136
                    height: 152

                    Rectangle {
                        anchors.fill: parent
                        radius: tile.selected ? Shape.extraLarge : Shape.largeIncreased
                        color: tile.selected ? Colors.m3primaryContainer : "transparent"

                        Behavior on radius { SpatialAnim { speed: "fast" } }
                        Behavior on color { ColorAnim {} }
                    }

                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 22
                        implicitSize: 64
                        scale: tile.selected ? 1.08 : 1
                        source: Apps.iconSourceFor(tile.modelData.app_id, tile.modelData.title)

                        Behavior on scale { SpatialAnim { speed: "fast" } }
                    }

                    MText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 100
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        textStyle: tile.selected ? Type.labelLargeEmph : Type.labelLarge
                        color: tile.selected ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                        text: tile.modelData.title || tile.entry?.name || tile.modelData.app_id
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.current = tile.index; root.commit(); }
                    }
                }
            }
        }
    }
}

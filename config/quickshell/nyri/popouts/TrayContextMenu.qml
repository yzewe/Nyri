import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

PopupWindow {
    id: root

    required property var hostWindow
    property var item: null
    property var submenu: null
    visible: false
    grabFocus: true
    color: "transparent"
    anchor.window: hostWindow
    anchor.edges: Panels.barBottom ? Edges.Top : Edges.Bottom
    anchor.gravity: Panels.barBottom ? Edges.Top : Edges.Bottom
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    implicitWidth: 244
    implicitHeight: Math.max(48, body.implicitHeight + 12)

    property bool expanded: false
    function hold(on) { if (hostWindow.holdMenu) { if (on) hostWindow.holdMenu(); else hostWindow.releaseMenu(); } }
    function dismiss() {
        expanded = false;
        hold(false);
    }

    function openFor(trayItem, from) {
        if (!trayItem?.hasMenu || !from) return;
        item = trayItem;
        submenu = null;
        anchor.item = from;
        expanded = true;
        pop.value = 0;
        pop.velocity = 0;
        pop.running = true;
        visible = true;
        hold(true);
    }

    SpringValue { id: pop; target: root.expanded ? 1 : 0; damping: 0.7; stiffness: 520; epsilon: 0.01 }
    Connections {
        target: pop
        function onValueChanged() { if (pop.value < 0.02 && !root.expanded) root.visible = false; }
    }
    onVisibleChanged: if (!visible) { root.expanded = false; root.hold(false); root.submenu = null; }

    QsMenuOpener {
        id: opener
        menu: root.submenu ?? root.item?.menu ?? null
    }

    Rectangle {
        anchors.fill: parent
        radius: Shape.large
        color: Colors.m3surfaceContainerHigh
        border.width: 1
        border.color: Colors.m3outlineVariant
        opacity: Math.min(1, pop.value)
        scale: 0.92 + 0.08 * pop.value
        transformOrigin: Panels.barBottom ? Item.Bottom : Item.Top

        Column {
            id: body
            x: 6
            y: 6
            width: parent.width - 12

            Item {
                width: parent.width
                height: 36
                visible: root.submenu !== null
                MIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; icon: "arrow_back"; size: 18; color: Colors.m3onSurface }
                MText { x: 38; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: "Назад" }
                StateLayer {
                    anchors.fill: parent
                    radius: Shape.medium
                    onClicked: root.submenu = null
                }
            }

            Repeater {
                model: ScriptModel { values: opener.children ? opener.children.values : [] }
                Item {
                    id: row
                    required property var modelData
                    width: body.width
                    height: modelData.isSeparator ? 9 : 38

                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: Colors.m3outlineVariant
                    }
                    Rectangle {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        radius: Shape.medium
                        color: ink.containsMouse ? Colors.m3surfaceContainerHighest : "transparent"

                        IconImage {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 18
                            visible: row.modelData.icon !== ""
                            source: row.modelData.icon
                        }
                        MIcon {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.icon === "" && row.modelData.checkState === Qt.Checked
                            icon: "check"
                            size: 18
                            color: Colors.m3onSurface
                        }
                        MText {
                            x: row.modelData.icon !== "" || row.modelData.checkState === Qt.Checked ? 38 : 14
                            width: parent.width - x - 28
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            textStyle: Type.labelLarge
                            color: row.modelData.enabled ? Colors.m3onSurface : Colors.m3outline
                            text: row.modelData.text
                        }
                        MIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.hasChildren
                            icon: "chevron_right"
                            size: 18
                            color: Colors.m3onSurfaceVariant
                        }
                        MouseArea {
                            id: ink
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: row.modelData.enabled && !row.modelData.isSeparator
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.modelData.hasChildren) root.submenu = row.modelData;
                                else { row.modelData.triggered(); root.dismiss(); }
                            }
                        }
                    }
                }
            }
        }
    }
}

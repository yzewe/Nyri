import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

PanelWindow {
    id: root

    required property string name
    default property alias content: stage.data
    property bool keyboard: true
    property real scrimOpacity: 0

    property bool open: Panels.current === name
    readonly property real progress: spring.value
    readonly property real fade: Math.max(0, Math.min(1, progress))

    SpringValue {
        id: spring
        target: root.open ? 1 : 0
        damping: root.open ? 0.68 : 1.0
        stiffness: root.open ? 380 : 420
    }

    screen: Panels.screen
    property bool hidden: false
    visible: (open || progress > 0.001) && !hidden
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "nyri-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Colors.m3scrim
        opacity: root.scrimOpacity * root.fade
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.open
        onActivated: Panels.close()
    }

    Item {
        id: stage
        anchors.fill: parent
    }
}

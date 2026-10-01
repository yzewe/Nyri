import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Island {
    id: root

    property real maxTextWidth: 360
    property real room: Infinity
    readonly property var win: Compositor.focusedWindow
    readonly property var entry: win ? DesktopEntries.heuristicLookup(win.app_id) : null

    widthSpeed: "fast"
    padding: 6
    spacing: 8
    opacity: win ? 1 : 0

    Behavior on opacity { EffectAnim {} }

    StateLayer {
        parent: root
        onClicked: Panels.toggleFrom("window", root)
    }

    AppIcon {
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        source: Apps.iconSourceFor(root.win?.app_id, root.win?.title)
    }

    FlowText {
        anchors.verticalCenter: parent.verticalCenter
        animate: false
        rightPadding: 8
        maxWidth: Math.max(0, Math.min(root.maxTextWidth, root.room - root.padding * 2 - 28 - root.spacing))
        width: implicitWidth
        elide: Text.ElideRight
        textStyle: Type.labelLarge
        color: Colors.m3onSurface
        text: root.win?.title || root.entry?.name || root.win?.app_id || ""
    }
}

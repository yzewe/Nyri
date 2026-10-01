pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property var workspaces: isHyprland ? Hypr.workspaces : Niri.workspaces
    readonly property var windows: isHyprland ? Hypr.windows : Niri.windows
    readonly property var focusedWindowId: isHyprland ? Hypr.focusedWindowId : Niri.focusedWindowId
    readonly property var focusedWindow: isHyprland ? Hypr.focusedWindow : Niri.focusedWindow
    readonly property string focusedOutput: isHyprland ? Hypr.focusedOutput : Niri.focusedOutput
    readonly property var layoutNames: isHyprland ? Hypr.layoutNames : Niri.layoutNames
    readonly property int layoutIndex: isHyprland ? Hypr.layoutIndex : Niri.layoutIndex
    readonly property string layoutShort: isHyprland ? Hypr.layoutShort : Niri.layoutShort
    readonly property bool overviewOpen: isHyprland ? false : Niri.overviewOpen
    readonly property var activeCasts: isHyprland ? [] : Niri.activeCasts

    function workspacesOn(output) { return isHyprland ? Hypr.workspacesOn(output) : Niri.workspacesOn(output); }
    function windowCount(id) { return isHyprland ? Hypr.windowCount(id) : Niri.windowCount(id); }
    function windowOfPid(pid) { return isHyprland ? Hypr.windowOfPid(pid) : Niri.windowOfPid(pid); }
    function action(...args) { if (isHyprland) Hypr.action(...args); else Niri.action(...args); }
}

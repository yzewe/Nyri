import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Variants {
    model: Quickshell.screens

    Scope {
    id: scope
    required property ShellScreen modelData

    PanelWindow {
        id: win

        readonly property ShellScreen modelData: scope.modelData

        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.namespace: "nyri-wallpaper"
        WlrLayershell.layer: WlrLayer.Background

        readonly property bool span: Config.o.wallpaper.span && Quickshell.screens.length > 1
        readonly property rect box: {
            let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
            for (const s of Quickshell.screens) {
                x0 = Math.min(x0, s.x); y0 = Math.min(y0, s.y);
                x1 = Math.max(x1, s.x + s.width); y1 = Math.max(y1, s.y + s.height);
            }
            return Qt.rect(x0, y0, x1 - x0, y1 - y0);
        }

        readonly property size texture: Qt.size(Math.min(stage.width, 2880), Math.min(stage.height, 1800))

        readonly property var myWorkspaces: Compositor.workspacesOn(modelData.name)
        readonly property var activeWs: myWorkspaces.find(w => w.is_active) ?? null
        readonly property real wsPos: Compositor.isHyprland || !(myWorkspaces.length > 1 && activeWs)
            ? 0.5 : myWorkspaces.indexOf(activeWs) / (myWorkspaces.length - 1)
        readonly property var columns: {
            if (Compositor.isHyprland || !activeWs) return { at: 0, count: 1 };
            let count = 1, at = 1;
            for (const id in Compositor.windows) {
                const w = Compositor.windows[id];
                const c = w.workspace_id === activeWs.id ? w.layout?.pos_in_scrolling_layout?.[0] ?? 0 : 0;
                count = Math.max(count, c);
                if (w.is_focused && c) at = c;
            }
            return { at, count };
        }
        readonly property real colPos: columns.count > 1 ? (columns.at - 1) / (columns.count - 1) : 0.5
        readonly property bool fullPalette: /\/(waves|bands)-/.test(win.shown)
        readonly property real zoom: fullPalette ? 1 : Compositor.overviewOpen ? 1.12 : 1.08
        readonly property real slackX: width * (zoom - 1) / 2
        readonly property real slackY: height * (zoom - 1) / 2

        SpringValue { id: px; target: (0.5 - win.colPos) * 2 * win.slackX * 0.8; damping: 0.85; stiffness: 90; epsilon: 0.05 }
        SpringValue { id: py; target: (0.5 - win.wsPos) * 2 * win.slackY * 0.8; damping: 0.85; stiffness: 90; epsilon: 0.05 }
        SpringValue { id: pz; target: win.zoom; damping: 0.9; stiffness: 120; epsilon: 0.0005 }
        Connections {
            target: Lock
            function onUnlocked() {
                pz.value = 1.0;
                pz.velocity = 0;
                pz.running = true;
            }
        }
        property string shown: ""
        property string incoming: ""

        readonly property bool animated: Config.o.wallpaper.animated ?? false
        readonly property bool seen: {
            if (Panels.deskEdit) return true;
            if (!activeWs) return false;
            if (Compositor.isHyprland)
                return !Object.values(Compositor.windows).some(w => w.workspace_id === activeWs.id && !w.is_floating);
            if (Compositor.overviewOpen) return true;
            const cols = {};
            for (const id in Compositor.windows) {
                const w = Compositor.windows[id];
                if (w.workspace_id !== activeWs.id || w.is_floating) continue;
                const c = w.layout?.pos_in_scrolling_layout?.[0] ?? 0, tw = w.layout?.tile_size?.[0] ?? width;
                cols[c] = Math.max(cols[c] ?? 0, tw);
            }
            let sum = 0;
            for (const c in cols) sum += cols[c];
            return sum < width * 0.9;
        }
        Process {
            id: sceneJob
            command: [Paths.bin + "/nyri-wall", "scene", win.shown]
            onExited: code => { if (code === 0) scene.reload(); }
        }

        Item {
            id: stage
            x: win.span ? win.box.x - win.modelData.x : 0
            y: win.span ? win.box.y - win.modelData.y : 0
            width: win.span ? win.box.width : win.width
            height: win.span ? win.box.height : win.height
            scale: pz.value
            transform: Translate { x: px.value; y: py.value }

        Image {
            id: base
            anchors.fill: parent
            source: win.shown && !scene.visible ? "file://" + win.shown : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: win.texture
        }

        Scene {
            id: scene
            anchors.fill: parent
            visible: win.animated && ready
            file: win.animated && win.shown.indexOf("/walls/") >= 0 && win.shown.endsWith(".png") ? win.shown.replace(/\.png$/, ".json") : ""
            running: win.seen && !Lock.locked && win.incoming === ""
            fps: Idle.battery ? 24 : 30
            onMissing: if (file !== "") sceneJob.running = true
        }

        ClippingRectangle {
            id: reveal

            property real size: 0
            readonly property real diagonal: Math.hypot(win.width, win.height)

            x: -stage.x + (win.width - size) / 2
            y: -stage.y + (win.height - size) / 2
            width: size
            height: size
            radius: size / 2
            color: "transparent"
            visible: win.incoming !== ""

            Image {
                id: next
                x: -reveal.x
                y: -reveal.y
                width: stage.width
                height: stage.height
                source: win.incoming ? "file://" + win.incoming : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: win.texture
                onStatusChanged: if (status === Image.Ready) grow.restart()
            }

            NumberAnimation {
                id: grow
                target: reveal
                property: "size"
                from: 0
                to: reveal.diagonal
                duration: 900
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasizedDecel.curve
                onFinished: {
                    win.shown = win.incoming;
                    win.incoming = "";
                    reveal.size = 0;
                }
            }
        }
        }

        Connections {
            target: Colors
            function onWallpaperChanged() {
                if (!win.shown) win.shown = Colors.wallpaper;
                else if (Colors.wallpaper !== win.shown) win.incoming = Colors.wallpaper;
            }
        }

        Component.onCompleted: if (Colors.wallpaper) shown = Colors.wallpaper
    }

    PanelWindow {
        screen: scope.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.namespace: "nyri-desktop"
        WlrLayershell.layer: Panels.deskEdit ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: Panels.deskEdit && scope.modelData.name === Compositor.focusedOutput ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        mask: widgets.mask

        Shortcut {
            sequence: "Escape"
            enabled: Panels.deskEdit
            onActivated: Panels.deskEdit = false
        }

        DesktopWidgets {
            id: widgets
            anchors.fill: parent
            output: scope.modelData.name
            wsIdx: win.activeWs?.idx ?? 0
            bare: Panels.deskEdit || (win.activeWs ? !Object.values(Compositor.windows).some(w => w.workspace_id === win.activeWs.id) : true)
        }
    }
    }
}

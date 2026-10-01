import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray as ST
import qs.theme
import qs.services
import qs.widgets

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData
        readonly property int gap: 12
        readonly property int islandHeight: 40
        readonly property bool strip: Config.o.bar.style === "strip"
        readonly property int top: strip ? 4 : gap
        readonly property int stripHeight: strip ? 48 : gap + islandHeight
        readonly property bool bottom: Panels.barBottom
        readonly property real islandY: bottom ? height - top - islandHeight : top
        readonly property real hideShift: (bottom ? 1 : -1) * (stripHeight + 12)

        readonly property bool autohide: Config.o.bar.autohide
        readonly property bool emptyDesk: {
            const ws = Compositor.workspaces.find(w => w.output === modelData.name && w.is_active);
            return !ws || Compositor.windowCount(ws.id) === 0;
        }
        property bool pointerIn: false
        property bool menuHeld: false
        readonly property bool revealed: !autohide || pointerIn || menuHeld || Panels.current !== ""
                                         || Compositor.overviewOpen || emptyDesk
        function holdMenu() { menuHeld = true; leave.stop(); pointerIn = true; }
        function releaseMenu() {
            menuHeld = false;
            if (!barHover.hovered) { leave.stop(); pointerIn = false; }
        }

        SpringValue {
            id: reveal
            target: bar.revealed ? 1 : 0
            damping: bar.revealed ? 0.62 : 1.0
            stiffness: bar.revealed ? 420 : 380
        }

        screen: modelData
        anchors { top: !bottom; bottom: bottom; left: true; right: true }
        implicitHeight: stripHeight + 16
        property bool settled: false
        Timer { running: true; interval: 600; onTriggered: bar.settled = true }
        exclusionMode: autohide && settled ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: autohide ? 0 : stripHeight
        color: "transparent"

        IdleInhibitor {
            window: bar
            enabled: Toggles.caffeine
        }

        WlrLayershell.namespace: "nyri-bar"
        WlrLayershell.layer: autohide ? WlrLayer.Overlay : WlrLayer.Top

        mask: Region {
            Region { item: Panels.current !== "" ? null : bar.autohide ? null : left }
            Region { item: Panels.current !== "" ? null : bar.autohide ? null : fixedClock }
            Region { item: Panels.current !== "" ? null : bar.autohide ? null : center }
            Region { item: Panels.current !== "" ? null : bar.autohide ? null : right }
            Region { item: Panels.current !== "" ? null : bar.autohide ? (reveal.value > 0.5 ? strip : edge) : null }
        }

        Item { id: strip; width: bar.width; height: bar.stripHeight + 4; y: bar.bottom ? bar.height - height : 0 }
        Item { id: edge; width: bar.width; height: 3; y: bar.bottom ? bar.height - height : 0 }

        HoverHandler {
            id: barHover
            onHoveredChanged: {
                if (hovered) {
                    leave.stop();
                    bar.pointerIn = true;
                } else {
                    leave.restart();
                }
            }
        }

        Timer {
            id: leave
            interval: 450
            onTriggered: bar.pointerIn = false
        }

        Rectangle {
            visible: Config.o.bar.style === "strip"
            width: bar.width
            height: bar.stripHeight
            y: (bar.bottom ? bar.height - height : 0) + (1 - reveal.value) * bar.hideShift
            color: Colors.m3surfaceContainer
            opacity: Math.min(1, reveal.value * 2)
            Rectangle { y: bar.bottom ? 0 : parent.height - 1; width: parent.width; height: 1; color: Colors.m3outlineVariant; opacity: 0.6 }
        }

        readonly property var leftIds: Config.list(Config.o.bar.left).filter(id => id !== "clock")
        readonly property var centerIds: Config.list(Config.o.bar.center).filter(id => id !== "clock")
        readonly property var rightIds: Config.list(Config.o.bar.right).filter(id => id !== "clock")

        readonly property var registry: ({
            launcher: launcherC, workspaces: workspacesC, title: titleC, clock: clockC, live: liveC,
            tray: trayC, status: statusC, control: controlC, weather: weatherC, media: mediaC
        })
        function wants(id) {
            if (id === "tray") return ST.SystemTray.items.values.length > 0;
            if (id === "weather") return Weather.ready;
            if (id === "media") return Media.player !== null;
            if (id === "title") return Compositor.focusedWindow !== null;
            return true;
        }
        Component { id: launcherC; LauncherButton {} }
        Component { id: workspacesC; Workspaces { output: bar.modelData.name } }
        Component { id: titleC; WindowTitle { maxTextWidth: 360 } }
        Component { id: clockC; Clock {} }
        Component { id: liveC; LiveIsland { media: bar.leftIds.concat(bar.centerIds, bar.rightIds).indexOf("media") < 0 } }
        Component { id: trayC; Tray { barWindow: bar } }
        Component { id: statusC; Status {} }
        Component { id: controlC; PanelButton {} }
        Component { id: weatherC; WeatherIsland {} }
        Component { id: mediaC; MediaIsland {} }

        component Section: Row {
            id: sec
            property var ids: []
            property int base: 0
            property real room: Infinity
            function taken(skip) {
                let w = 0;
                for (const c of children)
                    if (c !== skip && c.visible && c.item) w += c.width + spacing;
                return w;
            }
            spacing: 8
            Repeater {
                model: sec.ids
                Loader {
                    id: slot
                    required property string modelData
                    required property int index
                    anchors.verticalCenter: parent?.verticalCenter
                    sourceComponent: bar.registry[modelData] ?? null
                    visible: bar.wants(modelData) && (item?.present ?? true)
                    onLoaded: if (item.introIndex !== undefined) item.introIndex = sec.base + index
                    Binding {
                        when: slot.item?.room !== undefined
                        target: slot.item
                        property: "room"
                        value: sec.room - sec.taken(slot)
                    }
                }
            }
        }

        Item {
            id: content
            width: bar.width
            height: bar.height
            transform: Translate { y: (1 - reveal.value) * bar.hideShift }
            opacity: Math.min(1, reveal.value * 2)

            Section {
                id: left
                x: bar.gap
                y: bar.islandY
                ids: bar.leftIds
                base: 0
                room: fixedClock.x - 12 - x
            }

            Loader {
                id: fixedClock
                x: (bar.width - width) / 2
                y: bar.islandY
                sourceComponent: clockC
            }

            Section {
                id: center
                x: fixedClock.x + fixedClock.width + 8
                y: bar.islandY
                ids: bar.centerIds
                base: bar.leftIds.length
            }

            Section {
                id: right
                x: bar.width - width - bar.gap
                y: bar.islandY
                ids: bar.rightIds
                room: bar.width - bar.gap - (center.width > 1 ? center.x + center.width : fixedClock.x + fixedClock.width) - 12
                base: bar.leftIds.length + bar.centerIds.length
            }
        }
    }
}

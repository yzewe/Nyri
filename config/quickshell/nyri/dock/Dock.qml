import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Variants {
    model: Config.o.dock.enabled ? Quickshell.screens.map(sc => ({ screen: sc, hide: Config.o.dock.autohide })) : []

    PanelWindow {
        id: win

        required property var modelData
        readonly property ShellScreen out: modelData.screen
        readonly property var cfg: Config.o.dock
        readonly property real sz: cfg.size
        readonly property real pad: 10
        readonly property real dockH: sz + 2 * pad
        readonly property real lift: Panels.barBottom && cfg.autohide ? Panels.barReach + 8 : 0

        screen: out
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: cfg.autohide ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: cfg.autohide ? 0 : dockH + 12 + lift
        WlrLayershell.namespace: "nyri-dock"
        WlrLayershell.layer: cfg.autohide ? WlrLayer.Overlay : WlrLayer.Top

        function keyOf(appId, title) {
            const id = (appId ?? "").toLowerCase().replace(/\.desktop$/, "");
            let titleMatch = "";
            let titleLength = 0;
            for (const pinnedId of pinned) {
                const entry = DesktopEntries.byId(pinnedId) ?? DesktopEntries.heuristicLookup(pinnedId);
                if (!entry) continue;
                const entryId = (entry.id ?? "").toLowerCase().replace(/\.desktop$/, "");
                const name = (entry.name ?? "").toLowerCase();
                const heading = (title ?? "").toLowerCase();
                if (id === entryId || id === entryId.split(".").pop())
                    return pinnedId;
                if (id === "electron" && name.length > 3 && heading.includes(name) && name.length > titleLength) {
                    titleMatch = pinnedId;
                    titleLength = name.length;
                }
            }
            if (titleMatch) return titleMatch;
            if (id === "electron" && title) {
                const heading = title.toLowerCase();
                let found = null;
                for (const entry of Apps.all) {
                    const name = (entry.name ?? "").toLowerCase();
                    if (name.length > 3 && heading.includes(name) && (!found || name.length > found.name.length))
                        found = { id: entry.id, name };
                }
                if (found) return found.id;
            }
            return DesktopEntries.heuristicLookup(appId)?.id ?? appId;
        }
        readonly property var own: ({
            "nyri:settings": { name: "Настройки", icon: "file://" + Paths.root + "/assets/nyri-settings.svg", open: () => Panels.openSettings() },
            "nyri:studio": { name: "Студия обоев", icon: "file://" + Paths.root + "/assets/nyri-wallpaper.svg", open: () => Panels.open("wallpaper") }
        })
        function ownKey(w) { return /Обои/.test(w.title ?? "") ? "nyri:studio" : "nyri:settings"; }
        readonly property var pinned: Config.list(cfg.pinned)
        readonly property var items: {
            const byKey = {};
            const order = [];
            for (const id of pinned) {
                const o = own[id];
                const e = o ? null : (DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id));
                if (!e && !o) continue;
                byKey[id] = { key: id, entry: e, appId: id, windows: [], pinned: true, own: o ?? null };
                order.push(id);
            }
            if (cfg.running) {
                const ws = Object.values(Compositor.windows).sort((a, b) => (b.focus_timestamp?.secs ?? 0) - (a.focus_timestamp?.secs ?? 0));
                for (const w of ws) {
                    if (!w.app_id) continue;
                    const mine = w.app_id === "org.quickshell";
                    const k = mine ? ownKey(w) : keyOf(w.app_id, w.title);
                    if (!byKey[k]) {
                        byKey[k] = { key: k, entry: mine ? null : (DesktopEntries.byId(k) ?? DesktopEntries.heuristicLookup(w.app_id)), appId: w.app_id, windows: [], pinned: false, own: mine ? own[k] : null };
                        order.push(k);
                    }
                    byKey[k].windows.push(w);
                    byKey[k].appId = w.app_id;
                }
            }
            return order.map(k => byKey[k]);
        }
        readonly property string focusedKey: !Compositor.focusedWindow ? ""
            : Compositor.focusedWindow.app_id === "org.quickshell" ? ownKey(Compositor.focusedWindow) : keyOf(Compositor.focusedWindow.app_id, Compositor.focusedWindow.title)

        function activate(it) {
            if (!it.windows.length) {
                if (it.own) it.own.open();
                else if (it.entry) Apps.launch(it.entry);
                return true;
            }
            const focused = it.windows.findIndex(w => w.is_focused);
            const next = it.windows[focused >= 0 ? (focused + 1) % it.windows.length : 0];
            Compositor.action("focus-window", "--id", String(next.id));
            return false;
        }
        function setPinned(list) { Config.o.dock.pinned = list; }

        Timer {
            running: !win.cfg.seeded && Object.keys(Apps.counts).length > 0
            interval: 1500
            onTriggered: {
                if (win.cfg.seeded) return;
                win.setPinned(Apps.search("").slice(0, 5).map(e => e.id));
                Config.o.dock.seeded = true;
            }
        }
        function togglePin(it) {
            if (pinned.indexOf(it.key) >= 0) setPinned(pinned.filter(k => k !== it.key));
            else setPinned(pinned.concat([it.key]));
        }
        function unread(it) {
            const id = (it.entry?.id ?? "").replace(/\.desktop$/, "").toLowerCase();
            const name = (it.entry?.name ?? Apps.nameFor(it.appId) ?? "").toLowerCase();
            const app = (it.appId ?? "").toLowerCase();
            let n = 0;
            for (const x of Notifs.list) {
                const de = (x.desktopEntry ?? "").replace(/\.desktop$/, "").toLowerCase();
                const an = (x.appName ?? "").toLowerCase();
                if ((de && (de === id || de === app)) || (an && (an === name || an === app))) n++;
            }
            return n;
        }
        function wsName(w) {
            const ws = Compositor.workspaces.find(x => x.id === w.workspace_id);
            return ws ? "Стол " + ws.idx : "";
        }
        function closeAll(it) { for (const w of it.windows) Compositor.action("close-window", "--id", String(w.id)); }
        readonly property bool menuOpen: dockMenu.item !== null
        function openMenu(slot) { dockMenu.open(slot); }
        function closeMenu(immediate) { dockMenu.close(immediate); }

        readonly property bool emptyDesk: {
            const ws = Compositor.workspaces.find(w => w.output === win.out.name && w.is_active);
            return !ws || Compositor.windowCount(ws.id) === 0;
        }
        property bool pointerIn: false
        readonly property var active: ToplevelManager.activeToplevel
        readonly property bool fullscreenHere: (active?.fullscreen ?? false) && (active?.screens ?? []).some(sc => sc.name === win.screen?.name)
        readonly property bool revealed: !Panels.deskEdit && !fullscreenHere && items.length > 0 && (!cfg.autohide || pointerIn || emptyDesk || dockMenu.item !== null || hover.slot !== null || drag.key !== "")
        SpringValue { id: reveal; target: win.revealed ? 1 : 0; damping: win.revealed ? 0.62 : 1; stiffness: win.revealed ? 420 : 380 }

        QtObject {
            id: hover
            property Item slot: null
            property bool icon: false
            property bool gap: false
            property bool pad: false
            property int rows: 0
            property bool menu: false
            property bool menuIcon: false
            property bool menuGap: false
            property int menuRows: 0
            readonly property bool hot: icon || gap || pad || rows > 0 || menu || menuIcon || menuGap || menuRows > 0
            function poke() {
                if (hot) { hoverLeave.stop(); leave.stop(); win.pointerIn = true; }
                else hoverLeave.restart();
            }
            function bump(delta) { rows = Math.max(0, rows + delta); poke(); }
            function syncMenu() {
                if (!dockMenu.item) return;
                if (menu || menuIcon || menuGap || menuRows > 0) menuLeave.stop();
                else menuLeave.restart();
            }
            onSlotChanged: {
                rows = 0;
                pad = false;
                gap = false;
                if (!slot) return;
                floater.shown = slot;
                popSpring.value = 0;
                popSpring.velocity = 0;
                popSpring.running = true;
            }
        }
        Timer {
            id: hoverLeave
            interval: 90
            onTriggered: {
                if (hover.hot) return;
                hover.slot = null;
                if (!dockHover.hovered && !edgeHover.hovered) leave.restart();
            }
        }

        mask: Region {
            Region { item: Panels.current !== "" ? null : drag.key !== "" ? all : null }
            Region { item: Panels.current !== "" ? null : win.pointerIn || reveal.value > 0.12 ? hitDock : edge }
            Region { item: Panels.current !== "" ? null : dockMenu.item ? menuBridge : null }
            Region { item: Panels.current !== "" ? null : floater.shown && popSpring.value > 0.02 ? floaterBridge : null }
        }
        Item { id: all; anchors.fill: parent }
        Item {
            id: edge
            width: parent.width; height: 3; y: parent.height - 3 - win.lift
            HoverHandler { id: edgeHover; onHoveredChanged: { if (hovered) { leave.stop(); win.pointerIn = true; } else leave.restart(); } }
        }
        Item {
            id: hitDock
            x: dock.x - 16; y: dock.y - 56; width: dock.width + 32; height: win.height - y - win.lift
            HoverHandler { id: dockHover; onHoveredChanged: { if (hovered) { leave.stop(); win.pointerIn = true; } else leave.restart(); } }
        }
        Timer {
            id: leave
            interval: 420
            onTriggered: { if (!hover.hot) win.pointerIn = false; }
        }

        property real mouseX: -1e6
        function swell(cx) {
            if (!cfg.magnify || drag.key !== "") return 1;
            return Math.abs(cx - mouseX) < sz / 2 ? 1.16 : 1;
        }

        QtObject {
            id: drag
            property string key: ""
            property real x: 0
            property real y: 0
            property int to: -1
            readonly property bool away: key !== "" && y < -win.sz * 1.2
        }

        Item {
            id: dock
            HoverHandler {
                onPointChanged: win.mouseX = point.position.x
                onHoveredChanged: if (!hovered) win.mouseX = -1e6
            }
            readonly property var slots: {
                const out = {};
                let x = win.pad;
                let i = 0;
                for (const it of win.items) {
                    if (it.key === drag.key) continue;
                    if (drag.key !== "" && !drag.away && i === drag.to) x += win.sz + 8;
                    out[it.key] = x + win.sz / 2;
                    x += win.sz + 8;
                    i++;
                }
                return { at: out, width: Math.max(win.sz, x - 8 + win.pad + (drag.key !== "" && !drag.away && drag.to >= i ? win.sz + 8 : 0)) };
            }
            SpringValue { id: dockW; target: dock.slots.width; damping: 0.7; stiffness: 420; epsilon: 0.3 }
            width: dockW.value
            height: win.dockH
            x: (win.width - width) / 2
            y: win.height - height - 12 - win.lift + (1 - reveal.value) * (win.dockH + 24)
            opacity: Math.min(1, reveal.value * 2)

            RectangularShadow {
                anchors.fill: bg
                radius: bg.radius
                offset.y: 3
                blur: 14
                color: Qt.alpha(Colors.m3shadow, 0.4)
            }
            Rectangle {
                id: bg
                anchors.fill: parent
                radius: Math.min(height / 2, Shape.extraLarge)
                color: Colors.m3surfaceContainer
            }

            Repeater {
                model: ScriptModel { values: win.items; objectProp: "key" }

                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property var it: modelData
                    readonly property bool held: drag.key === it.key
                    readonly property real restX: dock.slots.at[it.key] ?? 0
                    readonly property real k: win.swell(cx.value)

                    SpringValue { id: cx; target: slot.held ? drag.x : slot.restX; damping: slot.held ? 0.9 : 0.66; stiffness: slot.held ? 1800 : 460; epsilon: 0.2 }
                    SpringValue { id: size; target: win.sz * (slot.held ? (drag.away ? 0.7 : 1.15) : slot.k); damping: 0.62; stiffness: 520; epsilon: 0.1 }
                    SpringValue { id: hop; target: 0; damping: 0.3; stiffness: 260; epsilon: 0.2 }
                    SpringValue { id: press; target: tapH.pressed ? 0.88 : 1; damping: 0.55; stiffness: 700; epsilon: 0.002 }
                    SpringValue { id: born; target: 1; damping: 0.6; stiffness: 420; Component.onCompleted: { value = 0; running = true; } }

                    z: held ? 10 : 0
                    width: size.value
                    height: size.value
                    x: cx.value - width / 2
                    y: (slot.held ? Math.min(win.pad, drag.y) : dock.height - win.pad - height) + hop.value
                    scale: Math.min(1, born.value) * press.value
                    opacity: slot.held && drag.away ? 0.5 : 1
                    rotation: Math.max(-1, Math.min(1, cx.velocity / 2500)) * 10

                    AppIcon {
                        anchors.fill: parent
                        source: slot.it.own ? slot.it.own.icon : Apps.iconSourceFor(slot.it.entry?.id ?? slot.it.appId, slot.it.windows[0]?.title)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 2
                        spacing: 3
                        visible: !slot.held
                        Repeater {
                            model: Math.min(3, slot.it.windows.length)
                            Rectangle {
                                required property int index
                                readonly property bool lit: win.focusedKey === slot.it.key && index === 0
                                SpringValue { id: dw; target: lit ? 14 : 5; damping: 0.6; stiffness: 600 }
                                width: dw.value
                                height: 5
                                radius: 2.5
                                color: lit ? Colors.m3primary : Colors.m3onSurfaceVariant
                            }
                        }
                    }

                    Rectangle {
                        readonly property int n: win.unread(slot.it)
                        SpringValue { id: badgeIn; target: parent.visible && badge.n > 0 ? 1 : 0; damping: 0.5; stiffness: 520 }
                        id: badge
                        visible: badgeIn.value > 0.02
                        scale: Math.max(0, badgeIn.value)
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -4
                        anchors.topMargin: -4
                        width: Math.max(height, badgeText.implicitWidth + 10)
                        height: 20
                        radius: 10
                        color: Colors.m3error
                        border.width: 2
                        border.color: Colors.m3surfaceContainer
                        MText { id: badgeText; anchors.centerIn: parent; textStyle: Type.labelSmall; font.features: { "tnum": 1 }; color: Colors.m3onError; text: badge.n > 9 ? "9+" : String(badge.n) }
                    }

                    HoverHandler {
                        id: tap
                        cursorShape: dragH.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered && drag.key === "" && !win.menuOpen) {
                                hover.slot = slot;
                                hover.icon = true;
                                hover.poke();
                            } else if (!hovered && hover.slot === slot) {
                                hover.icon = false;
                                hover.poke();
                            }
                            if (dockMenu.item === slot) {
                                hover.menuIcon = hovered;
                                hover.syncMenu();
                            }
                        }
                    }
                    TapHandler {
                        id: tapH
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onTapped: (ev, button) => {
                            hover.slot = null;
                            if (button === Qt.RightButton) { win.openMenu(slot); return; }
                            if (button === Qt.MiddleButton) { if (slot.it.entry) Apps.launch(slot.it.entry); }
                            else win.activate(slot.it);
                            hop.velocity = -700;
                            hop.running = true;
                        }
                    }
                    DragHandler {
                        id: dragH
                        target: null
                        onActiveChanged: {
                            if (active) {
                                hover.slot = null;
                                const p = slot.mapToItem(dock, centroid.position.x, centroid.position.y);
                                drag.x = p.x; drag.y = win.pad; drag.to = slot.index; drag.key = slot.it.key;
                                return;
                            }
                            const key = drag.key, to = drag.to, away = drag.away;
                            drag.key = "";
                            if (away) { if (slot.it.pinned) win.setPinned(win.pinned.filter(k => k !== key)); return; }
                            const keys = win.items.map(i => i.key).filter(k => k !== key);
                            keys.splice(Math.max(0, Math.min(to, keys.length)), 0, key);
                            win.setPinned(keys.filter(k => k === key ? true : win.pinned.indexOf(k) >= 0));
                        }
                        onCentroidChanged: {
                            if (!active) return;
                            const p = slot.mapToItem(dock, centroid.position.x, centroid.position.y);
                            drag.x = p.x;
                            drag.y = p.y - win.sz / 2;
                            let i = 0, x = win.pad;
                            for (const other of win.items) {
                                if (other.key === drag.key) continue;
                                if (p.x < x + win.sz / 2) break;
                                x += win.sz + 8;
                                i++;
                            }
                            drag.to = i;
                        }
                    }
                }
            }
        }

        Item {
            id: floaterBridge
            readonly property real iconTop: dock.y + (floater.shown?.y ?? 0)
            x: floater.x - 12
            y: floater.y - 12
            width: floater.width + 24
            height: Math.max(floater.height + 24, iconTop - y + 6)
            HoverHandler { onHoveredChanged: { hover.gap = hovered; hover.poke(); } }
        }
        Rectangle {
            id: floater
            property Item shown: null
            readonly property var it: shown?.it ?? null
            readonly property int wins: it?.windows?.length ?? 0
            readonly property bool listMode: wins > 1
            readonly property bool show: hover.slot !== null && drag.key === "" && !win.menuOpen
            readonly property string label: it?.own?.name ?? it?.entry?.name ?? Apps.nameFor(it?.appId)
            visible: popSpring.value > 0.02 && shown !== null
            width: listMode ? 300 : chipText.implicitWidth + 24
            height: listMode ? listCol.implicitHeight + 16 : 30
            radius: listMode ? Shape.large : 15
            color: listMode ? Colors.m3surfaceContainerHigh : Colors.m3inverseSurface
            x: shown ? Math.max(8, Math.min(win.width - width - 8, dock.x + shown.x + shown.width / 2 - width / 2)) : 0
            y: shown ? dock.y + shown.y - height - 10 : 0
            opacity: Math.min(1, popSpring.value)
            scale: 0.8 + 0.2 * popSpring.value
            transformOrigin: Item.Bottom
            SpringValue { id: popSpring; target: floater.show ? 1 : 0; damping: 0.7; stiffness: 520; epsilon: 0.01 }
            Connections {
                target: popSpring
                function onValueChanged() { if (popSpring.value < 0.02 && hover.slot === null) floater.shown = null; }
            }

            HoverHandler { onHoveredChanged: { hover.pad = hovered; hover.poke(); } }

            MText {
                id: chipText
                anchors.centerIn: parent
                visible: !floater.listMode
                textStyle: Type.labelLarge
                color: Colors.m3inverseOnSurface
                text: floater.label
            }

            Column {
                id: listCol
                visible: floater.listMode
                x: 8; y: 8
                width: parent.width - 16
                spacing: 2
                MText {
                    leftPadding: 12; topPadding: 4; bottomPadding: 6
                    textStyle: Type.labelLargeEmph
                    color: Colors.m3primary
                    text: floater.label + " · " + floater.wins
                }
                Repeater {
                    model: floater.listMode ? (floater.it?.windows ?? []) : []
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: modelData.is_focused
                        width: listCol.width
                        height: 52
                        radius: Shape.medium
                        color: on ? Colors.m3secondaryContainer : "transparent"
                        StateLayer {
                            radius: row.radius
                            onContainsMouseChanged: hover.bump(containsMouse ? 1 : -1)
                            onClicked: { Compositor.action("focus-window", "--id", String(row.modelData.id)); hover.slot = null; }
                        }
                        AppIcon {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24
                            source: floater.it?.own ? floater.it.own.icon : Apps.iconSourceFor(row.modelData.app_id, row.modelData.title)
                        }
                        Column {
                            x: 48
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 48 - 44
                            MText { width: parent.width; elide: Text.ElideRight; textStyle: Type.labelLarge; color: row.on ? Colors.m3onSecondaryContainer : Colors.m3onSurface; text: row.modelData.title || Apps.nameFor(row.modelData.app_id) }
                            MText { textStyle: Type.labelSmall; color: row.on ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant; text: win.wsName(row.modelData) }
                        }
                        IconButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            size: 36; iconSize: 18
                            icon: "close"
                            onHoveredChanged: hover.bump(hovered ? 1 : -1)
                            onClicked: Compositor.action("close-window", "--id", String(row.modelData.id))
                        }
                    }
                }
            }
        }

        QtObject {
            id: dockMenu
            property Item item: null
            property Item shown: null
            property real anchorX: 0
            property real anchorY: 0
            function open(slot) {
                anchorX = dock.x + slot.x + slot.width / 2;
                anchorY = dock.y + slot.y;
                hover.slot = null;
                hover.icon = false;
                hover.menuIcon = true;
                hover.menu = false;
                hover.menuGap = false;
                hover.menuRows = 0;
                shown = slot;
                item = slot;
                menuSpring.value = 0;
                menuSpring.velocity = 0;
                menuSpring.running = true;
                menuLeave.stop();
            }
            function close() {
                item = null;
                hover.menu = false;
                hover.menuIcon = false;
                hover.menuGap = false;
                hover.menuRows = 0;
                menuLeave.stop();
                if (!dockHover.hovered && !edgeHover.hovered) {
                    leave.stop();
                    win.pointerIn = false;
                }
            }
        }
        Timer {
            id: menuLeave
            interval: 140
            onTriggered: if (dockMenu.item && !hover.menu && !hover.menuIcon && !hover.menuGap && hover.menuRows === 0) dockMenu.close()
        }
        Item {
            id: menuBridge
            x: menuCard.x - 14
            y: menuCard.y - 12
            width: menuCard.width + 28
            height: Math.max(menuCard.height + 24, dock.y + (dockMenu.shown?.y ?? 0) + 8 - y)
            HoverHandler { onHoveredChanged: { hover.menuGap = hovered; hover.syncMenu(); } }
        }
        Rectangle {
            id: menuCard
            function perform(key) {
                const target = it;
                win.closeMenu();
                if (!target) return;
                if (key === "pin") win.togglePin(target);
                else if (key === "new" && target.entry) Apps.launch(target.entry);
                else if (key === "close") win.closeAll(target);
            }
            visible: menuSpring.value > 0.02 && dockMenu.shown !== null
            readonly property var it: dockMenu.shown?.it ?? null
            width: 220
            height: menuCol.implicitHeight + 16
            radius: Shape.large
            color: Colors.m3surfaceContainerHigh
            x: dockMenu.shown ? Math.max(8, Math.min(win.width - width - 8, dockMenu.anchorX - width / 2)) : 0
            y: dockMenu.anchorY - height - 10
            opacity: Math.min(1, menuSpring.value)
            scale: 0.8 + 0.2 * menuSpring.value
            transformOrigin: Item.Bottom
            SpringValue { id: menuSpring; target: dockMenu.item !== null ? 1 : 0; damping: 0.7; stiffness: 520; epsilon: 0.01 }
            Connections {
                target: menuSpring
                function onValueChanged() { if (menuSpring.value < 0.02 && dockMenu.item === null) dockMenu.shown = null; }
            }
            HoverHandler { onHoveredChanged: { hover.menu = hovered; hover.syncMenu(); } }

            Column {
                id: menuCol
                x: 8; y: 8
                width: parent.width - 16
                MText { width: parent.width - 12; elide: Text.ElideRight; leftPadding: 12; topPadding: 4; bottomPadding: 6; textStyle: Type.labelLargeEmph; color: Colors.m3primary; text: menuCard.it?.own?.name ?? menuCard.it?.entry?.name ?? Apps.nameFor(menuCard.it?.appId) }
                Repeater {
                    model: menuCard.it ? [
                        { key: "pin", icon: win.pinned.indexOf(menuCard.it.key) >= 0 ? "keep_off" : "keep", label: win.pinned.indexOf(menuCard.it.key) >= 0 ? "Открепить" : "Закрепить", show: !!menuCard.it.entry || !!menuCard.it.own },
                        { key: "new", icon: "add", label: "Новое окно", show: !!menuCard.it.entry },
                        { key: "close", icon: "close", label: menuCard.it.windows.length > 1 ? "Закрыть все окна" : "Закрыть", show: menuCard.it.windows.length > 0 }
                    ].filter(a => a.show !== false) : []
                    Item {
                        id: actionRow
                        required property var modelData
                        width: menuCol.width
                        height: 44
                        Rectangle {
                            anchors.fill: parent
                            radius: Shape.medium
                            color: actionMouse.containsMouse ? Colors.m3surfaceContainerHighest : "transparent"
                        }
                        MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: parent.modelData.icon; size: 20; color: Colors.m3onSurfaceVariant }
                        MText { x: 44; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: parent.modelData.label }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                hover.menuRows = Math.max(0, hover.menuRows + (containsMouse ? 1 : -1));
                                hover.syncMenu();
                            }
                            onClicked: menuCard.perform(actionRow.modelData.key)
                        }
                    }
                }
            }
        }
    }
}

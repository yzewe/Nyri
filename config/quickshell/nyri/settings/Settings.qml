import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Panels.settingsOpen

    readonly property var pages: [
        { id: "look",   icon: "palette",             label: "Оформление",            short: "Вид" },
        { id: "desk",   icon: "dashboard_customize", label: "Стол и обои",           short: "Стол" },
        { id: "windows", icon: "grid_view",          label: "Окна",                  short: "Окна" },
        { id: "bar",    icon: "toolbar",             label: "Панель",                short: "Панель" },
        { id: "dock",   icon: "dock_to_bottom",      label: "Док",                   short: "Док" },
        { id: "notif",  icon: "notifications",       label: "Уведомления",  short: "Уведомления" },
        { id: "lock",   icon: "lock",                label: "Блокировка",            short: "Блок." },
        { id: "power",  icon: "electric_bolt",        label: "Питание и сон",         short: "Питание" },
        { id: "usage",  icon: "hourglass",       label: "Экранное время",        short: "Время" },
        { id: "search", icon: "search",              label: "Поиск",                 short: "Поиск" },
        { id: "keys",   icon: "keyboard",            label: "Клавиши",               short: "Клавиши" },
        { id: "about",  icon: "info",                label: "Система",               short: "Система" }
    ]

    function toggle() {
        Panels.settingsOpen = !Panels.settingsOpen;
    }

    LazyLoader {
        active: root.open

        FloatingWindow {
            id: win

            title: "Nyri · Настройки"
            visible: true
            implicitWidth: 960
            implicitHeight: 680
            minimumSize: Qt.size(720, 480)
            color: Colors.m3surfaceContainerLow

            onVisibleChanged: if (!visible) Panels.settingsOpen = false

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (pageLoader.item && pageLoader.item.closeOverlay && pageLoader.item.closeOverlay())
                        return;
                    Panels.settingsOpen = false;
                }
            }

            function step(n) {
                const i = root.pages.findIndex(p => p.id === Panels.settingsPage);
                Panels.settingsPage = root.pages[(i + n + root.pages.length) % root.pages.length].id;
            }
            Shortcut { sequence: "PgDown"; onActivated: flick.flick(0, -2600) }
            Shortcut { sequence: "PgUp"; onActivated: flick.flick(0, 2600) }
            Shortcut { sequence: "Home"; onActivated: flick.contentY = -flick.topMargin }
            Shortcut { sequence: "End"; onActivated: flick.contentY = Math.max(-flick.topMargin, flick.contentHeight - flick.height + flick.bottomMargin) }
            Shortcut { sequence: "Ctrl+Tab"; onActivated: win.step(1) }
            Shortcut { sequence: "Ctrl+Backtab"; onActivated: win.step(-1) }
            Repeater {
                model: root.pages.length
                Item {
                    required property int index
                    Shortcut { sequence: "Alt+" + (index + 1); onActivated: Panels.settingsPage = root.pages[index].id }
                }
            }

            readonly property bool compact: width < 860

            property bool searchOpen: false
            property string query: ""
            property bool indexing: false
            property var index: []
            function collect(item, pageId, out) {
                if (!item) return;
                if (item.isRow && item.title) out.push({ page: pageId, title: item.title, subtitle: item.subtitle || "", icon: item.icon || "" });
                for (let i = 0; i < item.children.length; i++) collect(item.children[i], pageId, out);
            }
            readonly property var hits: {
                const q = query.trim().toLowerCase();
                if (!q) return [];
                const words = q.split(/\s+/);
                return index.filter(h => { const t = (h.title + " " + h.subtitle + " " + (root.pages.find(p => p.id === h.page)?.label ?? "")).toLowerCase(); return words.every(w => t.includes(w)); })
                            .sort((a, b) => (b.title.toLowerCase().startsWith(q) ? 1 : 0) - (a.title.toLowerCase().startsWith(q) ? 1 : 0))
                            .slice(0, 30);
            }
            property string pendingRow: ""
            function jump(h) {
                pendingRow = h.title;
                search.input.text = "";
                searchOpen = false;
                if (Panels.settingsPage === h.page) Qt.callLater(win.reveal);
                else Panels.settingsPage = h.page;
            }
            function findRow(item, title) {
                if (!item) return null;
                if (item.isRow && item.title === title) return item;
                for (let i = 0; i < item.children.length; i++) { const f = findRow(item.children[i], title); if (f) return f; }
                return null;
            }
            function reveal() {
                const row = findRow(pageLoader.item, pendingRow);
                pendingRow = "";
                if (!row) return;
                const y = row.mapToItem(pageLoader.item, 0, 0).y;
                flick.contentY = Math.max(-flick.topMargin, Math.min(flick.contentHeight - flick.height + flick.bottomMargin, y - 120));
                row.flash();
            }
            Item {
                visible: false
                Repeater {
                    model: win.indexing ? root.pages : []
                    Loader {
                        required property var modelData
                        width: 640
                        asynchronous: true
                        source: "Page" + modelData.id.charAt(0).toUpperCase() + modelData.id.slice(1) + ".qml"
                        onLoaded: {
                            const out = [];
                            win.collect(item, modelData.id, out);
                            win.index = win.index.filter(h => h.page !== modelData.id).concat(out);
                        }
                    }
                }
            }

            Item {
                id: nav
                width: win.compact ? 96 : 260
                height: parent.height
                z: win.searchOpen ? 10 : 0

                MText {
                    visible: !win.compact
                    x: 28
                    y: 28
                    textStyle: Type.headlineSmall
                    font.variableAxes: ({ "wght": 600 })
                    text: "Настройки"
                }

                SearchField {
                    id: search
                    visible: !win.compact || win.searchOpen
                    x: win.compact ? nav.width + 28 : 16
                    y: win.compact ? 20 : 76
                    width: win.compact ? Math.min(420, win.width - nav.width - 72) : nav.width - 32
                    z: 50
                    icon: "search"
                    placeholder: "Поиск"
                    input.onTextChanged: { win.query = input.text; if (input.text) win.indexing = true; }
                    input.Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { input.text = ""; win.searchOpen = false; event.accepted = true; }
                        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && win.hits.length) { win.jump(win.hits[0]); event.accepted = true; }
                    }
                }
                IconButton {
                    visible: win.compact
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    icon: "search"
                    style: win.searchOpen ? "filled" : "standard"
                    onClicked: { win.searchOpen = !win.searchOpen; if (win.searchOpen) search.input.forceActiveFocus(); else search.input.text = ""; }
                }

                Flickable {
                    id: navFlick
                    y: win.compact ? 68 : 140
                    width: nav.width
                    height: nav.height - y - 12
                    contentHeight: navList.height + 16
                    clip: true
                    Overscroll { flick: navFlick; step: 2.4; touchpad: 2.2; coast: 0.55; coastMax: 1600; glideStiff: 520 }

                Rectangle {
                    id: indicator
                    readonly property int index: root.pages.findIndex(p => p.id === Panels.settingsPage)
                    x: win.compact ? (nav.width - 56) / 2 : 12
                    width: win.compact ? 56 : nav.width - 24
                    height: win.compact ? 32 : 56
                    radius: height / 2
                    color: Colors.m3secondaryContainer
                    y: pill.value

                    SpringValue {
                        id: pill
                        target: indicator.index * (win.compact ? 72 : 60) + (win.compact ? 6 : 0)
                        damping: 0.62
                        stiffness: 520
                        epsilon: 0.1
                    }
                }

                Column {
                    id: navList
                    x: win.compact ? 0 : 12
                    y: 0
                    width: win.compact ? nav.width : nav.width - 24
                    spacing: 4

                    Repeater {
                        model: root.pages

                        Item {
                            id: navItem

                            required property var modelData
                            readonly property bool picked: Panels.settingsPage === modelData.id

                            width: navList.width
                            height: win.compact ? 68 : 56

                            StateLayer {
                                visible: !win.compact
                                onClicked: Panels.settingsPage = navItem.modelData.id
                            }

                            MouseArea {
                                visible: win.compact
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Panels.settingsPage = navItem.modelData.id
                            }

                            MIcon {
                                x: win.compact ? (parent.width - width) / 2 : 18
                                y: win.compact ? 10 : (parent.height - height) / 2
                                icon: navItem.modelData.icon
                                size: 24
                                fill: navItem.picked ? 1 : 0
                                color: navItem.picked ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                            }

                            MText {
                                x: win.compact ? (parent.width - width) / 2 : 56
                                y: win.compact ? 44 : (parent.height - height) / 2
                                width: win.compact ? parent.width - 4 : implicitWidth
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                textStyle: navItem.picked ? Type.labelLargeEmph : Type.labelLarge
                                font.pixelSize: win.compact ? 12 : 15
                                color: navItem.picked ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                                text: win.compact ? navItem.modelData.short : navItem.modelData.label
                            }
                        }
                    }
                }
            }
            }

            Rectangle {
                id: pageBox
                clip: true
                x: nav.width
                y: 12
                width: parent.width - nav.width - 12
                height: parent.height - 24
                radius: Shape.extraLarge
                color: Colors.m3surface

                readonly property real headH: 64
                readonly property real largeH: 104
                readonly property real collapse: Math.max(0, Math.min(1, (flick.contentY + flick.topMargin) / (largeH - headH)))

                Flickable {
                    id: flick
                    anchors.fill: parent
                    topMargin: pageBox.largeH
                    bottomMargin: 28
                    contentHeight: pageLoader.item?.implicitHeight ?? 0
                    Overscroll { flick: flick; step: 2.8; touchpad: 2.4; coast: 0.7; coastMax: 2400; glideStiff: 560 }

                    Loader {
                        id: pageLoader
                        x: 28
                        width: flick.width - 56
                        source: "Page" + Panels.settingsPage.charAt(0).toUpperCase() + Panels.settingsPage.slice(1) + ".qml"
                        onSourceChanged: flick.contentY = -flick.topMargin

                        property real enter: 1
                        opacity: Math.min(1, enter * 1.4)
                        onLoaded: { enter = 0; rise.restart(); if (!win.pendingRow) Qt.callLater(() => cascade.play(item)); else Qt.callLater(win.reveal); }
                        Cascade { id: cascade; rise: 44 }
                        SpatialAnim { id: rise; target: pageLoader; property: "enter"; from: 0; to: 1; speed: "default" }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: pageBox.headH
                    color: Colors.m3surfaceContainerLow
                    opacity: pageBox.collapse
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Colors.m3outlineVariant
                    }
                }

                FlowText {
                    x: 28
                    y: 40 + (18 - 40) * pageBox.collapse
                    textStyle: ({ size: Math.round(32 - 10 * pageBox.collapse), weight: 580, rond: 100 })
                    text: root.pages.find(p => p.id === Panels.settingsPage)?.label ?? ""
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colors.m3surface
                    SpringValue { id: resIn; target: win.query.trim() ? 1 : 0; damping: 0.8; stiffness: 420 }
                    visible: resIn.value > 0.01
                    opacity: Math.min(1, resIn.value * 1.4)

                    MText {
                        x: 28
                        y: win.compact ? 84 : 36
                        textStyle: Type.titleLarge
                        text: win.hits.length ? "Найдено: " + win.hits.length : win.index.length ? "Ничего не нашлось" : "Ищу…"
                    }
                    ListView {
                        id: results
                        x: 16
                        y: win.compact ? 132 : 84
                        width: parent.width - 32
                        height: parent.height - y - 16
                        clip: true
                        spacing: 4
                        model: win.hits
                        Overscroll { flick: results; step: 2.8; touchpad: 2.4; coast: 0.7; coastMax: 2400; glideStiff: 560 }
                        delegate: Rectangle {
                            id: hit
                            required property var modelData
                            required property int index
                            width: results.width
                            height: 64
                            radius: Shape.large
                            color: Colors.m3surfaceContainer
                            SpringValue { id: hitIn; target: 1; damping: 0.7; stiffness: 420; Component.onCompleted: { value = 0; running = true; } }
                            opacity: Math.min(1, hitIn.value * 1.4)
                            transform: Translate { y: (1 - Math.min(1, hitIn.value)) * (14 + Math.min(8, hit.index) * 4) }
                            StateLayer { radius: parent.radius; onClicked: win.jump(hit.modelData) }
                            MIcon { x: 18; anchors.verticalCenter: parent.verticalCenter; icon: hit.modelData.icon || "settings"; size: 22; color: Colors.m3onSurfaceVariant }
                            Column {
                                x: 56
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 56 - 16
                                MText { width: parent.width; elide: Text.ElideRight; textStyle: Type.bodyLarge; text: hit.modelData.title }
                                MText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    textStyle: Type.labelMedium
                                    color: Colors.m3onSurfaceVariant
                                    text: (root.pages.find(p => p.id === hit.modelData.page)?.label ?? "") + (hit.modelData.subtitle ? " · " + hit.modelData.subtitle : "")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

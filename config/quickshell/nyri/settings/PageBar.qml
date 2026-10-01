import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.widgets

Column {
    id: page
    spacing: 24

    readonly property var info: ({
        launcher: { icon: "apps", label: "Приложения" },
        workspaces: { icon: "view_week", label: "Столы" },
        title: { icon: "web_asset", label: "Окно" },
        clock: { icon: "schedule", label: "Часы" },
        live: { icon: "bubble_chart", label: "Живой остров" },
        tray: { icon: "more_horiz", label: "Трей" },
        status: { icon: "battery_full", label: "Статус" },
        control: { icon: "tune", label: "Шторка" },
        weather: { icon: "partly_cloudy_day", label: "Погода" },
        media: { icon: "music_note", label: "Музыка" }
    })
    readonly property var all: Object.keys(info).filter(i => i !== "clock")
    function ids(zone) {
        if (zone === "hidden") {
            const used = [].concat(ids("left"), ids("center"), ids("right"));
            return all.filter(i => used.indexOf(i) < 0);
        }
        const v = Config.o.bar[zone];
        return Config.list(v).filter(i => i !== "clock");
    }
    function move(id, zone, index) {
        if (id === "clock") return;
        const next = {};
        for (const z of ["left", "center", "right"]) next[z] = ids(z).filter(i => i !== id);
        if (zone !== "hidden") {
            const list = next[zone];
            list.splice(Math.max(0, Math.min(index, list.length)), 0, id);
        }
        Config.o.bar.left = next.left;
        Config.o.bar.center = next.center;
        Config.o.bar.right = next.right;
    }

    property string held: ""
    property real heldW: 0
    property point pointer: Qt.point(0, 0)
    property string overZone: ""
    property int overIndex: -1
    property point grab: Qt.point(0, 0)
    property string landing: ""
    property var zoneItems: ({})
    property string landZone: ""
    function drop(id, zone, index, moved) {
        overZone = "";
        landing = id;
        landZone = zone;
        held = "";
        if (moved) move(id, zone, index);
        Qt.callLater(() => ghostRef.land(slotIn(zone, id)));
    }
    property Item ghostRef: null

    property var labelW: ({})
    function chipWidth(id, zone) { return zone === "hidden" ? (labelW[id] ?? 60) + 16 + 20 + 8 + 16 : 40; }
    function gapOf(zone) { return zone === "hidden" ? 8 : 6; }
    function chipY(zone) { return zone === "hidden" ? 2 : 10; }
    function rowTotal(zone, list, extra) {
        let t = extra;
        for (const i of list) t += chipWidth(i, zone);
        const n = list.length + (extra > 0 ? 1 : 0);
        return t + Math.max(0, n - 1) * gapOf(zone);
    }
    function rowStart(zone, total, width) { return zone === "right" ? width - total : 0; }
    function slotIn(zone, id) {
        const box = zoneItems[zone];
        if (!box) return Qt.point(0, 0);
        const list = ids(zone);
        let x = rowStart(zone, rowTotal(zone, list, 0), box.width);
        for (const i of list) { if (i === id) break; x += chipWidth(i, zone) + gapOf(zone); }
        return box.mapToItem(editor, x, chipY(zone));
    }
    Item {
        width: 0
        height: 0
        visible: false
        Repeater {
            model: page.all
            MText {
                required property string modelData
                textStyle: Type.labelLargeEmph
                text: page.info[modelData].label
                Component.onCompleted: { const m = Object.assign({}, page.labelW); m[modelData] = Math.ceil(implicitWidth); page.labelW = m; }
            }
        }
    }

    Item {
        id: editor
        width: parent.width
        height: tray.y + tray.height

        Rectangle {
            id: bar
            width: parent.width
            height: 60
            radius: height / 2
            color: Colors.m3surfaceContainerHigh
            readonly property real third: (width - 20) / 3
        }

        Rectangle {
            x: (bar.width - width) / 2
            y: 10
            width: 40
            height: 40
            radius: 20
            color: Colors.m3primaryContainer
            MIcon { anchors.centerIn: parent; icon: "schedule"; size: 22; color: Colors.m3onPrimaryContainer }
        }

        Repeater {
            model: [{ zone: "left", label: "Слева" }, { zone: "center", label: "В центре" }, { zone: "right", label: "Справа" }]
            MText {
                required property var modelData
                required property int index
                readonly property bool hot: page.held !== "" && page.overZone === modelData.zone
                x: bar.x + 10 + bar.third * index + (index === 0 ? 14 : index === 1 ? (bar.third - implicitWidth) / 2 : bar.third - implicitWidth - 14)
                y: bar.y + bar.height + 8
                textStyle: Type.labelMedium
                color: hot ? Colors.m3primary : Colors.m3onSurfaceVariant
                Behavior on color { ColorAnim {} }
                text: modelData.label
            }
        }

        MText {
            id: trayLabel
            y: bar.y + bar.height + 44
            textStyle: Type.labelLargeEmph
            color: page.overZone === "hidden" && page.held !== "" ? Colors.m3primary : Colors.m3onSurfaceVariant
            Behavior on color { ColorAnim {} }
            text: "Спрятано"
        }
        Item {
            id: tray
            y: trayLabel.y + trayLabel.height + 10
            width: parent.width
            height: 44
        }

        Repeater {
            model: ["left", "center", "right", "hidden"]

            Item {
                id: zoneBox
                required property string modelData
                required property int index
                readonly property string zone: modelData
                readonly property bool inBar: zone !== "hidden"
                readonly property var list: page.ids(zone)
                readonly property var vis: list.filter(i => i !== page.held)
                readonly property bool hot: page.held !== "" && page.overZone === zone
                x: inBar ? (zone === "center" ? bar.width / 2 + 24 : bar.x + 10 + bar.third * index) : tray.x
                y: inBar ? bar.y : tray.y
                width: inBar ? (zone === "center" ? bar.third / 2 - 24 : bar.third) : tray.width
                height: inBar ? bar.height : tray.height
                Component.onCompleted: { const m = Object.assign({}, page.zoneItems); m[zone] = zoneBox; page.zoneItems = m; }

                SpringValue { id: swell; target: zoneBox.hot ? 1 : 0; damping: 0.6; stiffness: 520 }
                Rectangle {
                    visible: zoneBox.inBar && swell.value > 0.01
                    anchors.centerIn: parent
                    width: parent.width * (0.9 + 0.1 * swell.value)
                    height: 48
                    radius: 24
                    color: Colors.m3secondaryContainer
                    opacity: Math.max(0, Math.min(1, swell.value)) * 0.7
                }

                readonly property real extra: hot ? page.chipWidth(page.held, zone) : 0
                readonly property real start: page.rowStart(zone, page.rowTotal(zone, vis, extra), width)
                function indexAt(px) {
                    let x = page.rowStart(zone, page.rowTotal(zone, vis, 0), width);
                    for (let k = 0; k < vis.length; k++) {
                        const w = page.chipWidth(vis[k], zone);
                        if (px < x + w / 2) return k;
                        x += w + page.gapOf(zone);
                    }
                    return vis.length;
                }
                readonly property point local: mapFromItem(editor, page.pointer.x, page.pointer.y)
                readonly property bool under: page.held !== "" && local.y >= -20 && local.y < height + (inBar ? 12 : 30) && local.x >= 0 && local.x < width
                onUnderChanged: if (under) page.overZone = zone; else if (page.overZone === zone) page.overZone = "";
                onLocalChanged: if (under) page.overIndex = indexAt(local.x)

                Repeater {
                    model: zoneBox.list
                    BarChip {
                        required property string modelData
                        chipId: modelData
                        zone: zoneBox.zone
                        readonly property int visIndex: zoneBox.vis.indexOf(modelData)
                        readonly property real slotX: {
                            let x = zoneBox.start;
                            for (let k = 0; k < visIndex; k++) x += page.chipWidth(zoneBox.vis[k], zoneBox.zone) + page.gapOf(zoneBox.zone);
                            return x;
                        }
                        readonly property bool pushed: zoneBox.hot && visIndex >= page.overIndex
                        homeX: slotX + (pushed ? zoneBox.extra + page.gapOf(zoneBox.zone) : 0)
                        homeY: page.chipY(zoneBox.zone)
                    }
                }
            }
        }

        Item {
            id: ghost
            z: 100
            readonly property string id_: page.held || page.landing
            visible: id_ !== ""
            SpringValue { id: gw; target: ghost.flying ? page.chipWidth(ghost.id_, page.landZone) : page.chipWidth(ghost.id_, "hidden"); damping: 0.7; stiffness: 700; epsilon: 0.2 }
            width: gw.value
            height: 40
            property bool flying: false
            property point dest: Qt.point(0, 0)
            function snap(x, y, w) { gx.value = x; gy.value = y; gx.velocity = 0; gy.velocity = 0; gw.value = w; gw.velocity = 0; flying = false; }
            function land(p) { dest = p; flying = true; }
            SpringValue {
                id: gx
                target: ghost.flying ? ghost.dest.x : page.pointer.x - page.grab.x
                damping: ghost.flying ? 0.62 : 0.85; stiffness: ghost.flying ? 520 : 1800; epsilon: 0.3
                onRunningChanged: if (!running && ghost.flying) ghost.done()
            }
            SpringValue {
                id: gy
                target: ghost.flying ? ghost.dest.y : page.pointer.y - page.grab.y
                damping: ghost.flying ? 0.62 : 0.85; stiffness: ghost.flying ? 520 : 1800; epsilon: 0.3
            }
            function done() { flying = false; page.landing = ""; }
            Component.onCompleted: page.ghostRef = ghost
            Timer { running: page.landing !== "" && !ghost.flying; interval: 400; onTriggered: ghost.done() }
            Timer { running: ghost.flying; interval: 700; onTriggered: ghost.done() }
            x: gx.value
            y: gy.value

            SpringValue { id: gLift; target: page.held !== "" ? 1 : 0; damping: 0.5; stiffness: 600 }
            readonly property real lean: Math.max(-1, Math.min(1, gx.velocity / 2200))
            readonly property real fall: Math.max(-1, Math.min(1, gy.velocity / 2200))
            rotation: lean * 10
            transform: Scale {
                origin.x: ghost.width / 2
                origin.y: ghost.height / 2
                xScale: 1 + gLift.value * 0.1 + Math.abs(ghost.lean) * 0.1 - Math.abs(ghost.fall) * 0.05
                yScale: 1 + gLift.value * 0.1 - Math.abs(ghost.lean) * 0.07 + Math.abs(ghost.fall) * 0.08
            }

            RectangularShadow {
                anchors.fill: face
                radius: height / 2
                offset.y: 4 + 6 * gLift.value
                blur: 8 + 14 * gLift.value
                color: Qt.alpha(Colors.m3shadow, 0.45 * Math.max(0, gLift.value))
            }
            PieceFace { id: face; anchors.fill: parent; chipId: ghost.id_; lifted: page.held !== "" }
        }
    }

    component BarChip: Item {
        id: chip
        property string chipId
        property string zone
        property real homeX: 0
        property real homeY: 0
        readonly property bool dragging: drag.active

        width: page.chipWidth(chipId, zone)
        height: 40
        opacity: dragging || page.landing === chipId ? 0 : 1

        SpringValue { id: sx; target: chip.homeX; damping: 0.62; stiffness: 420; epsilon: 0.1 }
        SpringValue { id: sy; target: chip.homeY; damping: 0.62; stiffness: 420; epsilon: 0.1 }
        Component.onCompleted: { sx.value = homeX; sy.value = homeY; }
        x: sx.value
        y: sy.value

        rotation: Math.max(-1, Math.min(1, sx.velocity / 3000)) * 4

        PieceFace { anchors.fill: parent; chipId: chip.chipId; lifted: false; dim: chip.zone === "hidden" }

        HoverHandler { id: hov; cursorShape: chip.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
        Rectangle {
            visible: tipIn.value > 0.02 && chip.zone !== "hidden"
            SpringValue { id: tipIn; target: hov.hovered && !chip.dragging ? 1 : 0; damping: 0.7; stiffness: 600 }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - 8 + (1 - tipIn.value) * 6
            opacity: Math.max(0, Math.min(1, tipIn.value))
            z: 50
            width: tipText.implicitWidth + 16
            height: 24
            radius: 6
            color: Colors.m3inverseSurface
            MText { id: tipText; anchors.centerIn: parent; textStyle: Type.labelMedium; color: Colors.m3inverseOnSurface; text: page.info[chip.chipId]?.label ?? "" }
        }
        DragHandler {
            id: drag
            target: null
            onCentroidChanged: if (active) page.pointer = chip.mapToItem(editor, centroid.position.x, centroid.position.y)
            onActiveChanged: {
                if (active) {
                    page.grab = Qt.point(Math.min(centroid.pressPosition.x, 20), centroid.pressPosition.y);
                    page.pointer = chip.mapToItem(editor, centroid.position.x, centroid.position.y);
                    const at = chip.mapToItem(editor, 0, 0);
                    ghost.snap(at.x, at.y, chip.width);
                    page.heldW = chip.width;
                    page.held = chip.chipId;
                } else {
                    page.drop(page.held, page.overZone || chip.zone, page.overIndex, page.overZone !== "");
                }
            }
        }
    }

    component PieceFace: Rectangle {
        id: pf
        property string chipId
        property bool lifted: false
        property bool dim: false
        readonly property real open: Math.max(0, Math.min(1, (width - 48) / 40))
        radius: height / 2
        color: lifted ? Colors.m3primary : dim ? Colors.m3surfaceContainerHighest : Colors.m3secondaryContainer
        Behavior on color { ColorAnim {} }
        clip: true
        Row {
            x: pf.open > 0 ? 16 * pf.open + (pf.width - 20) / 2 * (1 - pf.open) : (pf.width - 20) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: page.info[pf.chipId]?.icon ?? ""; size: 20; fill: 1; color: pf.lifted ? Colors.m3onPrimary : Colors.m3onSecondaryContainer }
            MText { anchors.verticalCenter: parent.verticalCenter; opacity: pf.open; textStyle: Type.labelLargeEmph; color: pf.lifted ? Colors.m3onPrimary : Colors.m3onSecondaryContainer; text: page.info[pf.chipId]?.label ?? pf.chipId }
        }
    }

    ListGroup {
        width: parent.width
        title: "Вид"

        SettingRow {
            icon: "style"
            title: "Стиль"
            choice: Config.o.bar.style
            choices: [{ value: "islands", label: "Островки" }, { value: "strip", label: "Полоса" }, { value: "chips", label: "Чипы" }]
            onChosen: v => Config.o.bar.style = v
        }

        SettingRow {
            icon: "vertical_split"
            title: "Где"
            choice: Config.o.bar.position
            choices: [{ value: "top", label: "Сверху", icon: "vertical_align_top" }, { value: "bottom", label: "Снизу", icon: "vertical_align_bottom" }]
            onChosen: v => Config.o.bar.position = v
        }

        SettingRow {
            icon: "view_week"
            title: "Рабочие столы"
            choice: Config.o.bar.workspaces
            choices: [{ value: "pills", label: "Пилюли" }, { value: "numbers", label: "Цифры" }, { value: "dots", label: "Точки" }]
            onChosen: v => Config.o.bar.workspaces = v
        }

        SettingRow {
            icon: "vertical_align_top"
            title: "Прятать панель"
            subtitle: "Выезжает, когда ведёшь мышь к краю, открываешь меню или стол пуст"
            MSwitch { checked: Config.o.bar.autohide; onToggled: c => Config.o.bar.autohide = c }
        }

        SettingRow {
            icon: "rounded_corner"
            title: "Скруглённые углы экрана"
            subtitle: "Как у телефона, даже в полноэкранных приложениях"
            MSwitch { checked: Config.o.bar.corners; onToggled: c => Config.o.bar.corners = c }
        }
    }

    ListGroup {
        width: parent.width
        title: "Детали"

        SettingRow {
            icon: "calendar_today"
            title: "Дата у часов"
            MSwitch { checked: Config.o.bar.date; onToggled: c => Config.o.bar.date = c }
        }
        SettingRow {
            icon: "timer"
            title: "Секунды"
            subtitle: "Часы тикают каждую секунду"
            MSwitch { checked: Config.o.bar.seconds; onToggled: c => Config.o.bar.seconds = c }
        }
        SettingRow {
            icon: "keyboard"
            title: "Раскладка"
            subtitle: "EN / RU в статусе"
            MSwitch { checked: Config.o.bar.layout; onToggled: c => Config.o.bar.layout = c }
        }
        SettingRow {
            icon: "volume_up"
            title: "Громкость"
            subtitle: "Колёсиком меняется, кликом выключается"
            MSwitch { checked: Config.o.bar.volume; onToggled: c => Config.o.bar.volume = c }
        }
        SettingRow {
            icon: "percent"
            title: "Проценты батареи"
            MSwitch { checked: Config.o.bar.percent; onToggled: c => Config.o.bar.percent = c }
        }
        SettingRow {
            icon: "music_note"
            title: "Название трека"
            subtitle: "На острове музыки"
            MSwitch { checked: Config.o.bar.mediaTitle; onToggled: c => Config.o.bar.mediaTitle = c }
        }
    }
}

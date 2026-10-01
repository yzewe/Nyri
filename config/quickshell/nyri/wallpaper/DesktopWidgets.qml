import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets
import qs.control

Item {
    id: root

    property real shiftX: 0
    property real shiftY: 0
    property bool bare: true
    property string output: ""
    property int wsIdx: 0
    readonly property bool editing: Panels.deskEdit

    readonly property var cfg: Config.o.desktop

    property bool shown: false
    SpringValue { id: introSpring; target: root.shown ? 1 : 0; damping: 0.7; stiffness: 200 }
    function playIntro() {
        introSpring.value = 0;
        introSpring.velocity = 0;
        if (shown) introSpring.running = true;
        else shown = true;
    }
    function holdIntro() {
        shown = false;
        introSpring.value = 0;
        introSpring.velocity = 0;
        introSpring.running = false;
    }
    Component.onCompleted: if (!Lock.locked) shown = true
    Connections {
        target: Lock
        function onLockedChanged() { if (Lock.locked) root.holdIntro(); else root.playIntro(); }
    }
    function stage(i) { return Math.max(0, Math.min(1.2, introSpring.value * 1.5 - i * 0.12)); }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property bool watchingSys: cfg.enabled && cfg.system && bare
    onWatchingSysChanged: SysStats.watchers += watchingSys ? 1 : -1
    Component.onDestruction: if (watchingSys) SysStats.watchers--

    readonly property var battery: UPower.displayDevice
    readonly property real level: {
        const p = battery?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
                                  || battery?.state === UPowerDeviceState.PendingCharge
                                  || battery?.state === UPowerDeviceState.FullyCharged
    readonly property string batteryNote: charging
        ? (battery?.timeToFull > 0 ? "до полной " + duration(battery.timeToFull) : "заряжается")
        : (battery?.timeToEmpty > 0 ? "ещё " + duration(battery.timeToEmpty) : Power.label)

    readonly property string dateLine: {
        const s = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    readonly property var now: Weather.ready ? Weather.describe(Weather.current.code, Weather.current.day) : null
    function duration(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }

    readonly property var desks: [dClock, dGlance, dBattery, dMedia, dForecast, dCalendar, dSystem, dUsage]
    readonly property DeskItem held: desks.find(d => d.dragging) ?? null

    function freeSpot(it, x, y) {
        return freeSpotAmong(it, x, y, desks.filter(d => d !== it && d.on && d.width > 0 && d.height > 0)
                                           .map(d => ({ x: d.homeX, y: d.homeY, w: d.width, h: d.height })));
    }
    function overlaps(a, b) {
        const m = 12;
        return !(a.x + a.w + m <= b.x || b.x + b.w + m <= a.x || a.y + a.h + m <= b.y || b.y + b.h + m <= a.y);
    }
    function freeSpotAmong(it, x, y, others) {
        const g = cfg.grid && cfg.gridSize > 0 ? cfg.gridSize : 8;
        const w = it.width, h = it.height;
        const ok = (px, py) => others.every(o => !overlaps({ x: px, y: py, w, h }, o));
        if (ok(x, y)) return Qt.point(x, y);
        for (let r = 1; r < 80; r++) {
            let best = null, bestD = Infinity;
            for (let i = -r; i <= r; i++)
                for (const [dx, dy] of [[i, -r], [i, r], [-r, i], [r, i]]) {
                    const px = it.clampX(x + dx * g), py = it.clampY(y + dy * g);
                    const d = (px - x) * (px - x) + (py - y) * (py - y);
                    if (d < bestD && ok(px, py)) { best = Qt.point(px, py); bestD = d; }
                }
            if (best) return best;
        }
        return Qt.point(x, y);
    }
    readonly property var displaced: {
        const h = held;
        if (!h) return ({});
        const out = {};
        const others = desks.filter(d => d !== h && d.on && d.width > 0 && d.height > 0);
        const cur = {};
        for (const d of others) cur[d.key] = { x: d.homeX, y: d.homeY, w: d.width, h: d.height };
        const landing = { x: h.dropX, y: h.dropY, w: h.width, h: h.height };
        const placed = [landing];
        for (const d of others) {
            const r = cur[d.key];
            if (placed.some(p => overlaps(r, p))) {
                const rest = placed.concat(others.filter(o => o !== d && placed.indexOf(cur[o.key]) < 0).map(o => cur[o.key]));
                const p = freeSpotAmong(d, r.x, r.y, rest);
                cur[d.key] = { x: p.x, y: p.y, w: r.w, h: r.h };
                out[d.key] = p;
            }
            placed.push(cur[d.key]);
        }
        return out;
    }

    function tidy() {
        if (held || editing && sheet.dragging) return;
        const pos = Object.assign({}, cfg.positions ?? {});
        let moved = false;
        for (const d of desks) {
            if (!d.on || d.width <= 0) continue;
            const p = freeSpot(d, d.homeX, d.homeY);
            if (Math.abs(p.x - d.homeX) > 0.5 || Math.abs(p.y - d.homeY) > 0.5) {
                pos[d.placeKey] = { x: p.x, y: p.y };
                cfg.positions = Object.assign({}, pos);
                moved = true;
            }
        }
    }
    readonly property string shapeKey: desks.map(d => d.on ? Math.round(d.width) + "x" + Math.round(d.height) : "-").join(",") + "|" + JSON.stringify(cfg.positions ?? {}).length
    onShapeKeyChanged: tidyLater.restart()
    Timer { id: tidyLater; interval: 700; onTriggered: root.tidy() }
    SpringValue { id: gridIn; target: (root.held || root.editing) && root.cfg.grid ? 1 : 0; damping: 0.9; stiffness: 400 }

    readonly property real zoomTarget: editing ? Math.max(0.6, (height - 236 - 24 - 32) / height) : 1
    SpringValue { id: zoomS; target: root.zoomTarget; damping: 0.78; stiffness: 300; epsilon: 0.0005 }
    readonly property real zoom: zoomS.value
    Scale { id: deskScale; origin.x: root.width / 2; origin.y: 16; xScale: root.zoom; yScale: root.zoom }

    Rectangle {
        anchors.fill: parent
        transform: deskScale
        visible: zoomS.value < 0.995
        opacity: Math.min(1, (1 - zoomS.value) * 8)
        radius: 36
        color: "transparent"
        border.width: 2 / Math.max(0.5, root.zoom)
        border.color: Qt.alpha(Colors.m3primary, 0.5)
    }

    Canvas {
        id: grid
        transform: deskScale
        anchors.fill: parent
        opacity: gridIn.value
        visible: opacity > 0.01
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const g = root.cfg.gridSize;
            if (g <= 0) return;
            ctx.fillStyle = Qt.alpha(Colors.m3onSurface, 0.35);
            for (let x = 0; x <= width; x += g)
                for (let y = 0; y <= height; y += g)
                    ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
        }
    }

    Item {
        anchors.fill: parent
        transform: deskScale
    Rectangle {
        visible: root.held !== null
        SpringValue { id: slotX; target: root.held ? root.held.dropX : 0; damping: 0.7; stiffness: 700 }
        SpringValue { id: slotY; target: root.held ? root.held.dropY : 0; damping: 0.7; stiffness: 700 }
        x: slotX.value + root.shiftX
        y: slotY.value + root.shiftY
        width: root.held?.width ?? 0
        height: root.held?.height ?? 0
        radius: Math.min(height / 2, Shape.extraLarge)
        color: Qt.alpha(Colors.m3primaryContainer, 0.35)
        border.width: 2
        border.color: Qt.alpha(Colors.m3primary, 0.6)
    }
    }

    readonly property Region mask: Region {
        Region { item: dClock }
        Region { item: dGlance }
        Region { item: dBattery }
        Region { item: dMedia }
        Region { item: dForecast }
        Region { item: dCalendar }
        Region { item: dSystem }
        Region { item: dUsage }
        Region { item: catcher }
        Region { item: deskMenu.visible ? deskMenu : null }
        Region { item: menu.visible ? menu : null }
    }

    MouseArea {
        id: catcher
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (menu.open) { menu.close(); return; }
            if (deskMenu.shown) { deskMenu.shown = false; return; }
            if (m.button === Qt.RightButton && !root.editing) deskMenu.openAt(m.x, m.y);
        }
    }

    Item {
        anchors.fill: parent
        z: -1
        visible: editS.value > 0.01
        opacity: Math.min(1, editS.value)
        SpringValue { id: editS; target: root.editing ? 1 : 0; damping: 0.9; stiffness: 300 }
        Rectangle { anchors.fill: parent; color: Colors.m3surface }
        Image {
            anchors.fill: parent
            source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
            asynchronous: true
            scale: 1.04 - 0.04 * Math.min(1, editS.value)
        }
        Rectangle { anchors.fill: parent; color: Colors.m3scrim; opacity: 0.3 }
    }

    Connections {
        target: Demo
        function find(key) { return root.desks.find(d => d.key === key) ?? null; }
        function onMenuRequested(key) { const d = find(key); if (d) menu.openFor(d); }
        function onMenuClose() { menu.close(); }
        function onLookRequested(key, index) { const d = find(key); if (d) d.setVariant(index); }
        function onDragRequested(key, x, y) { const d = find(key); if (d) d.demoDrag(x, y); }
    }

    readonly property int dayMinutes: clock.date.getHours() * 60 + clock.date.getMinutes()
    readonly property real minuteAngle: dayMinutes * 6
    readonly property real hourAngle: dayMinutes * 0.5

    Item {
        id: col
        anchors.fill: parent
        transform: deskScale
        visible: root.cfg.enabled
        opacity: 1
        z: root.held ? 250 : 0

        DeskItem {
            id: dClock
            shown: root.cfg.clock
            key: "clock"
            desk: root
            defaultY: 112
            title: "Часы"
            variantNames: ["Печенька", "Строка", "Стрелки", "Две фигуры"]
            onMenuRequested: menu.openFor(dClock)
            looks: [clockCookie, clockPill, clockAnalog, clockDuo]

            Item {
                readonly property Item cur: loaderClock.item
                Loader { id: loaderClock; sourceComponent: dClock.looks[dClock.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(0))
                scale: 0.6 + 0.4 * Math.min(1, root.stage(0))
                transformOrigin: Item.TopLeft

                Component {
                    id: clockCookie
                    Item {
                        width: 276
                        height: 276

                        SpringValue {
                            id: turn
                            target: (clock.date.getHours() * 60 + clock.date.getMinutes()) * 4
                            damping: 0.55
                            stiffness: 120
                            epsilon: 0.01
                        }
                        MaterialShape {
                            id: cookie
                            anchors.centerIn: parent
                            width: 260
                            height: 260
                            shape: "cookie12Sided"
                            color: Colors.m3primaryContainer
                            rotation: turn.value % 360
                        }
                        Column {
                            anchors.centerIn: cookie
                            spacing: -34
                            RollingText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                pixelSize: 104
                                weight: 680
                                color: Colors.m3onPrimaryContainer
                                speed: "slow"
                                text: Qt.formatTime(clock.date, "HH")
                            }
                            RollingText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                pixelSize: 104
                                weight: 680
                                color: Colors.m3primary
                                speed: "slow"
                                text: Qt.formatTime(clock.date, "mm")
                            }
                        }
                    }
                }

                Component {
                    id: clockPill
                    Rectangle {
                        width: pillCol.implicitWidth + 64
                        height: 150
                        radius: height / 2
                        color: Colors.m3primaryContainer

                        Column {
                            id: pillCol
                            anchors.centerIn: parent
                            spacing: -6
                            RollingText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                pixelSize: 88
                                weight: 680
                                color: Colors.m3onPrimaryContainer
                                speed: "slow"
                                text: Qt.formatTime(clock.date, "HH:mm")
                            }
                            MText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                textStyle: Type.titleMediumEmph
                                color: Colors.m3onPrimaryContainer
                                opacity: 0.8
                                text: root.dateLine
                            }
                        }
                    }
                }

                Component {
                    id: clockAnalog
                    Item {
                        width: 240
                        height: 240

                        SpringValue { id: hourS; target: root.hourAngle; damping: 0.55; stiffness: 140; epsilon: 0.01 }
                        SpringValue { id: minS; target: root.minuteAngle; damping: 0.55; stiffness: 140; epsilon: 0.01 }

                        MaterialShape {
                            anchors.fill: parent
                            shape: "cookie9Sided"
                            color: Colors.m3primaryContainer
                        }
                        Repeater {
                            model: 12
                            Rectangle {
                                required property int index
                                readonly property real a: index * Math.PI / 6
                                x: 120 + Math.sin(a) * 88 - width / 2
                                y: 120 - Math.cos(a) * 88 - height / 2
                                width: index % 3 === 0 ? 10 : 6
                                height: width
                                radius: width / 2
                                color: Colors.m3onPrimaryContainer
                                opacity: index % 3 === 0 ? 0.9 : 0.45
                            }
                        }
                        Rectangle {
                            x: 120 - width / 2
                            y: 120 - height + 10
                            width: 18
                            height: 70
                            radius: 9
                            color: Colors.m3onPrimaryContainer
                            transform: Rotation { origin.x: 9; origin.y: 60; angle: hourS.value }
                        }
                        Rectangle {
                            x: 120 - width / 2
                            y: 120 - height + 8
                            width: 10
                            height: 96
                            radius: 5
                            color: Colors.m3primary
                            transform: Rotation { origin.x: 5; origin.y: 88; angle: minS.value }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            radius: 11
                            color: Colors.m3primary
                            border.width: 5
                            border.color: Colors.m3primaryContainer
                        }
                    }
                }

                Component {
                    id: clockDuo
                    Row {
                        spacing: -18
                        MaterialShape {
                            width: 168
                            height: 168
                            shape: "cookie9Sided"
                            color: Colors.m3primaryContainer
                            RollingText { anchors.centerIn: parent; pixelSize: 78; weight: 700; color: Colors.m3onPrimaryContainer; speed: "slow"; text: Qt.formatTime(clock.date, "HH") }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 150
                            height: 150
                            radius: Shape.extraLarge * 1.6
                            color: Colors.m3secondaryContainer
                            RollingText { anchors.centerIn: parent; pixelSize: 70; weight: 700; color: Colors.m3onSecondaryContainer; speed: "slow"; text: Qt.formatTime(clock.date, "mm") }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.open("dashboard")
                }
            }
        }

        DeskItem {
            id: dGlance
            shown: root.cfg.glance
            key: "glance"
            desk: root
            defaultY: 412
            title: "Дата и погода"
            variantNames: ["Строка", "Карточка", "Только дата"]
            onMenuRequested: menu.openFor(dGlance)
            looks: [glancePill, glanceCard, glanceDate]

            Item {
                readonly property Item cur: loaderGlance.item
                Loader { id: loaderGlance; sourceComponent: dGlance.looks[dGlance.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(1))
                transform: Translate { y: (1 - Math.min(1, root.stage(1))) * 24 }

                Component {
                    id: glancePill
                    Rectangle {
                        width: glanceRow.implicitWidth + 40
                        height: 56
                        radius: height / 2
                        color: Colors.m3surfaceContainer

                        Row {
                            id: glanceRow
                            anchors.centerIn: parent
                            spacing: 12
                            MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.titleMediumEmph; text: root.dateLine }
                            Rectangle { visible: Weather.ready; anchors.verticalCenter: parent.verticalCenter; width: 4; height: 4; radius: 2; color: Colors.m3outline }
                            Row {
                                visible: Weather.ready
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.now?.icon ?? ""; size: 24; fill: 1; color: Colors.m3primary }
                                RollingText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.titleMediumEmph; text: Weather.ready ? Weather.current.temp + "°" : "" }
                            }
                        }
                    }
                }

                Component {
                    id: glanceDate
                    Rectangle {
                        width: dateOnly.implicitWidth + 48
                        height: 64
                        radius: height / 2
                        color: Colors.m3surfaceContainer
                        MText { id: dateOnly; anchors.centerIn: parent; textStyle: ({ size: 22, weight: 650, rond: 100 }); text: root.dateLine }
                    }
                }

                Component {
                    id: glanceCard
                    Rectangle {
                        width: 300
                        height: 132
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        MText {
                            id: dayNum
                            x: 24
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 72
                            font.variableAxes: ({ "wght": 650 })
                            color: Colors.m3primary
                            text: clock.date.getDate()
                        }
                        Column {
                            anchors.left: dayNum.right
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            MText {
                                textStyle: Type.titleMediumEmph
                                text: { const s = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd"); return s.charAt(0).toUpperCase() + s.slice(1); }
                            }
                            MText { textStyle: Type.bodyMedium; color: Colors.m3onSurfaceVariant; text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "MMMM yyyy") }
                            Row {
                                visible: Weather.ready
                                spacing: 6
                                topPadding: 4
                                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.now?.icon ?? ""; size: 20; fill: 1; color: Colors.m3primary }
                                MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLargeEmph; text: Weather.ready ? Weather.current.temp + "° · " + root.now.text : "" }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.open("dashboard")
                }
            }
        }

        DeskItem {
            id: dBattery
            shown: root.cfg.battery && (root.battery?.isLaptopBattery ?? false)
            key: "battery"
            desk: root
            defaultY: 484
            title: "Батарея"
            variantNames: ["Кольцо и время", "Большое кольцо", "Батарейка"]
            onMenuRequested: menu.openFor(dBattery)
            looks: [battPill, battRing, battBar]

            Item {
                readonly property Item cur: loaderBattery.item
                Loader { id: loaderBattery; sourceComponent: dBattery.looks[dBattery.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(2))
                transform: Translate { y: (1 - Math.min(1, root.stage(2))) * 24 }

                Component {
                    id: battPill
                    Rectangle {
                        width: battRow.implicitWidth + 24
                        height: 72
                        radius: height / 2
                        color: Colors.m3surfaceContainer

                        Row {
                            id: battRow
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Item {
                                width: 56
                                height: 56
                                CircularProgress {
                                    anchors.fill: parent
                                    stroke: 6
                                    value: root.level
                                    activeColor: root.level <= 0.15 && !root.charging ? Colors.m3error : Colors.m3primary
                                }
                                MIcon {
                                    anchors.centerIn: parent
                                    icon: root.charging ? "bolt" : root.level <= 0.15 ? "battery_alert" : "battery_full"
                                    size: 22
                                    fill: 1
                                    color: root.charging ? Colors.m3primary : Colors.m3onSurfaceVariant
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                RollingText { textStyle: Type.titleMediumEmph; text: Math.round(root.level * 100) + "%" }
                                FlowText { textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: root.batteryNote }
                            }
                            Item { width: 4; height: 1 }
                        }
                    }
                }

                Component {
                    id: battBar
                    Rectangle {
                        height: 76
                        radius: height / 2
                        color: Colors.m3surfaceContainer
                        width: bigBatt.implicitWidth + 48
                        BatteryPill {
                            id: bigBatt
                            anchors.centerIn: parent
                            size: 32
                            level: root.level
                            charging: root.charging
                            textSize: 30
                            textWeight: 700
                        }
                    }
                }

                Component {
                    id: battRing
                    Rectangle {
                        width: 150
                        height: 150
                        radius: width / 2
                        color: Colors.m3surfaceContainer

                        CircularProgress {
                            anchors.fill: parent
                            anchors.margins: 12
                            stroke: 10
                            value: root.level
                            activeColor: root.level <= 0.15 && !root.charging ? Colors.m3error : Colors.m3primary
                        }
                        Column {
                            anchors.centerIn: parent
                            MIcon { anchors.horizontalCenter: parent.horizontalCenter; visible: root.charging; icon: "bolt"; size: 20; fill: 1; color: Colors.m3primary }
                            RollingText { anchors.horizontalCenter: parent.horizontalCenter; pixelSize: 34; weight: 650; text: Math.round(root.level * 100) + "%" }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.open("power")
                }
            }
        }

        DeskItem {
            id: dMedia
            shown: root.cfg.media && (mediaBox.wanted || mediaBox.p > 0.01)
            key: "media"
            desk: root
            defaultY: 572
            title: "Плеер"
            variantNames: []
            onMenuRequested: menu.openFor(dMedia)

            Item {
                id: mediaBox
                width: 380
                readonly property bool wanted: root.cfg.media && (Media.player !== null || root.editing)
                SpringValue { id: mediaIn; target: mediaBox.wanted ? 1 : 0; damping: 0.72; stiffness: 260 }
                readonly property real p: Math.max(0, mediaIn.value)
                height: card.implicitHeight * Math.min(1, p)
                visible: p > 0.01
                opacity: Math.min(1, p) * Math.min(1, root.stage(3))

                MediaCard {
                    id: card
                    width: parent.width
                    active: root.bare
                    color: Colors.m3surfaceContainer
                    scale: 0.85 + 0.15 * mediaBox.p
                    transformOrigin: Item.Top
                }
            }
        }

        DeskItem {
            id: dForecast
            shown: root.cfg.forecast && Weather.daily.length > 0
            key: "forecast"
            desk: root
            defaultX: root.width - 56 - width
            defaultY: 112
            title: "Погода"
            variantNames: ["Пять дней", "Сейчас"]
            onMenuRequested: menu.openFor(dForecast)
            looks: [fcDays, fcNow]

            Item {
                readonly property Item cur: loaderForecast.item
                Loader { id: loaderForecast; sourceComponent: dForecast.looks[dForecast.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(1))

                Component {
                    id: fcDays
                    Rectangle {
                        width: 360
                        height: 150
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        Row {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            Repeater {
                                model: Weather.daily.slice(0, 5)
                                Column {
                                    required property var modelData
                                    required property int index
                                    width: parent.width / 5
                                    spacing: 6
                                    MText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        textStyle: index === 0 ? Type.labelLargeEmph : Type.labelMedium
                                        color: index === 0 ? Colors.m3primary : Colors.m3onSurfaceVariant
                                        text: index === 0 ? "Сегодня" : Qt.locale("ru_RU").toString(modelData.date, "ddd")
                                    }
                                    MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Weather.describe(modelData.code, true).icon; size: 30; fill: 1; color: Colors.m3primary }
                                    MText { anchors.horizontalCenter: parent.horizontalCenter; textStyle: Type.titleMediumEmph; text: modelData.max + "°" }
                                    MText { anchors.horizontalCenter: parent.horizontalCenter; textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: modelData.min + "°" }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: fcNow
                    Rectangle {
                        width: 300
                        height: 150
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        MIcon {
                            id: nowIcon
                            x: 22
                            anchors.verticalCenter: parent.verticalCenter
                            icon: root.now?.icon ?? "cloud"
                            size: 72
                            fill: 1
                            color: Colors.m3primary
                        }
                        Column {
                            anchors.left: nowIcon.right
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            RollingText { pixelSize: 52; weight: 650; text: Weather.ready ? Weather.current.temp + "°" : "—" }
                            MText { textStyle: Type.labelLargeEmph; text: root.now?.text ?? "" }
                            MText { textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: Weather.ready ? ["ощущается " + Weather.current.feels + "°", Weather.city].filter(Boolean).join(" · ") : "" }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.open("dashboard")
                }
            }
        }

        DeskItem {
            id: dCalendar
            shown: root.cfg.calendar
            key: "calendar"
            desk: root
            defaultX: root.width - 56 - width
            defaultY: 112 + 150 + 16
            title: "Календарь"
            variantNames: ["Месяц", "Неделя"]
            onMenuRequested: menu.openFor(dCalendar)
            looks: [calMonth, calWeek]

            Item {
                readonly property Item cur: loaderCalendar.item
                Loader { id: loaderCalendar; sourceComponent: dCalendar.looks[dCalendar.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(2))

                Component {
                    id: calMonth
                    Rectangle {
                        width: 360
                        height: cal.implicitHeight + 32
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        CalendarView {
                            id: cal
                            x: 16
                            y: 16
                            width: parent.width - 32
                            today: clock.date
                        }
                    }
                }

                Component {
                    id: calWeek
                    Rectangle {
                        id: week
                        width: 360
                        height: 104
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        readonly property date monday: {
                            const d = clock.date;
                            return new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7);
                        }

                        Row {
                            anchors.centerIn: parent
                            Repeater {
                                model: 7
                                Item {
                                    required property int index
                                    readonly property date day: new Date(week.monday.getFullYear(), week.monday.getMonth(), week.monday.getDate() + index)
                                    readonly property bool isToday: day.toDateString() === clock.date.toDateString()
                                    width: (week.width - 24) / 7
                                    height: 80
                                    MText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 4
                                        textStyle: Type.labelMedium
                                        color: parent.isToday ? Colors.m3primary : Colors.m3onSurfaceVariant
                                        text: Qt.locale("ru_RU").toString(parent.day, "ddd")
                                    }
                                    MaterialShape {
                                        visible: parent.isToday
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 30
                                        width: 42
                                        height: 42
                                        shape: "cookie9Sided"
                                        color: Colors.m3primary
                                    }
                                    MText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 30 + (42 - height) / 2
                                        textStyle: Type.titleMediumEmph
                                        color: parent.isToday ? Colors.m3onPrimary : Colors.m3onSurface
                                        text: parent.day.getDate()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        DeskItem {
            id: dSystem
            shown: root.cfg.system
            key: "system"
            desk: root
            defaultX: root.width - 56 - width
            defaultY: 112 + 150 + 16 + dCalendar.height + 16
            title: "Система"
            variantNames: ["Кольца", "Полосы", "Строка"]
            onMenuRequested: menu.openFor(dSystem)
            looks: [sysRings, sysBars, sysLine]

            Item {
                id: sysBox
                readonly property var stats: [
                    { label: "ЦП", value: SysStats.cpu },
                    { label: "ОЗУ", value: SysStats.mem },
                    { label: "Диск", value: SysStats.disk }
                ]
                readonly property Item cur: loaderSystem.item
                Loader { id: loaderSystem; sourceComponent: dSystem.looks[dSystem.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(3))

                Component {
                    id: sysRings
                    Rectangle {
                        width: 3 * 60 + 2 * 20 + 40
                        height: 112
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        Row {
                            id: sysRow
                            anchors.centerIn: parent
                            spacing: 20
                            Repeater {
                                model: sysBox.stats
                                Column {
                                    required property var modelData
                                    width: 60
                                    spacing: 4
                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 60
                                        height: 60
                                        SpringValue { id: ring; target: modelData.value; damping: 1.0; stiffness: 12; epsilon: 0.001 }
                                        CircularProgress { anchors.fill: parent; stroke: 6; value: ring.value; animated: false }
                                        MText { anchors.centerIn: parent; textStyle: Type.labelLargeEmph; font.features: { "tnum": 1 }; text: Math.round(ring.value * 100) }
                                    }
                                    MText { anchors.horizontalCenter: parent.horizontalCenter; textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: modelData.label }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: sysLine
                    Rectangle {
                        width: 300
                        height: 56
                        radius: height / 2
                        color: Colors.m3surfaceContainer
                        Row {
                            anchors.centerIn: parent
                            spacing: 18
                            Repeater {
                                model: sysBox.stats
                                Row {
                                    required property var modelData
                                    spacing: 6
                                    SpringValue { id: lineV; target: modelData.value; damping: 1.0; stiffness: 12; epsilon: 0.001 }
                                    MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: modelData.label }
                                    MText { anchors.verticalCenter: parent.verticalCenter; width: 40; textStyle: Type.titleMediumEmph; font.features: { "tnum": 1 }; text: Math.round(lineV.value * 100) + "%" }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: sysBars
                    Rectangle {
                        width: 300
                        height: 128
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            spacing: 12
                            Repeater {
                                model: sysBox.stats
                                Item {
                                    required property var modelData
                                    width: parent.width
                                    height: 22
                                    MText { anchors.verticalCenter: parent.verticalCenter; width: 44; textStyle: Type.labelLargeEmph; text: modelData.label }
                                    Rectangle {
                                        x: 48
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 48 - 44
                                        height: 12
                                        radius: 6
                                        color: Colors.m3secondaryContainer
                                        Rectangle {
                                            SpringValue { id: bar; target: modelData.value; damping: 1.0; stiffness: 12; epsilon: 0.001 }
                                            width: Math.max(12, parent.width * bar.value)
                                            height: parent.height
                                            radius: 6
                                            color: Colors.m3primary
                                        }
                                    }
                                    Item {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 40
                                        height: 20
                                        MText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; font.features: { "tnum": 1 }; text: Math.round(bar.value * 100) + "%" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        DeskItem {
            id: dUsage
            shown: root.cfg.usage
            key: "usage"
            desk: root
            defaultX: root.width - 56 - width
            defaultY: 112 + 150 + 16 + dCalendar.height + 16 + (dSystem.shown ? dSystem.height + 16 : 0)
            title: "Экранное время"
            variantNames: ["Список", "Итог"]
            onMenuRequested: menu.openFor(dUsage)
            looks: [usageList, usageTotal]

            Item {
                id: usage
                readonly property var today: { clock.date; return ScreenTime.dayTotals(new Date()); }
                readonly property var topApps: Object.entries(today).sort((a, b) => b[1] - a[1]).slice(0, 3)
                readonly property string totalText: ScreenTime.fmt(ScreenTime.total(today))
                readonly property Item cur: loaderUsage.item
                Loader { id: loaderUsage; sourceComponent: dUsage.looks[dUsage.variant] ?? null }
                width: cur?.width ?? 0
                height: cur?.height ?? 0
                opacity: Math.min(1, root.stage(4))

                Component {
                    id: usageList
                    Rectangle {
                        width: 360
                        height: usageCol.implicitHeight + 32
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainer

                        Column {
                            id: usageCol
                            x: 20
                            y: 16
                            width: parent.width - 40
                            spacing: 10

                            Row {
                                spacing: 8
                                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "hourglass_top"; size: 20; fill: 1; color: Colors.m3primary }
                                FlowText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.titleMediumEmph; text: "Сегодня · " + usage.totalText }
                            }
                            Repeater {
                                model: usage.topApps
                                Item {
                                    required property var modelData
                                    width: usageCol.width
                                    height: 28
                                    readonly property real share: modelData[1] / Math.max(1, usage.topApps[0][1])
                                    AppIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: 22
                                        source: Apps.iconSourceFor(modelData[0])
                                    }
                                    Rectangle {
                                        x: 32
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (parent.width - 32 - 64) * share
                                        height: 10
                                        radius: 5
                                        color: Colors.m3primary
                                        Behavior on width { SpatialAnim {} }
                                    }
                                    MText {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        textStyle: Type.labelMedium
                                        color: Colors.m3onSurfaceVariant
                                        text: ScreenTime.fmt(modelData[1])
                                    }
                                }
                            }
                            MText {
                                visible: usage.topApps.length === 0
                                textStyle: Type.labelMedium
                                color: Colors.m3onSurfaceVariant
                                text: Config.o.screenTime.enabled ? "Пока пусто" : "Учёт выключен в настройках"
                            }
                        }
                    }
                }

                Component {
                    id: usageTotal
                    Rectangle {
                        width: totalRow.implicitWidth + 48
                        height: 96
                        radius: height / 2
                        color: Colors.m3surfaceContainer

                        Row {
                            id: totalRow
                            anchors.centerIn: parent
                            spacing: 14
                            MaterialShape {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 56
                                height: 56
                                shape: "cookie9Sided"
                                color: Colors.m3primaryContainer
                                MIcon { anchors.centerIn: parent; icon: "hourglass_top"; size: 26; fill: 1; color: Colors.m3onPrimaryContainer }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                FlowText { textStyle: ({ size: 30, weight: 650, rond: 100 }); text: usage.totalText }
                                MText { textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: "за экраном сегодня" }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: menu

        property DeskItem target: null
        readonly property bool open: target !== null && (openS.target > 0 || openDelay.running)
        function openFor(d) { target = d; openS.target = 0; openDelay.restart(); }
        Timer { id: openDelay; interval: 60; onTriggered: openS.target = 1 }
        function close() { openDelay.stop(); openS.target = 0; }

        SpringValue { id: openS; target: 0; damping: 0.7; stiffness: 520; onRunningChanged: if (!running && target === 0 && !openDelay.running) menu.target = null }
        readonly property real p: Math.max(0, openS.value)

        z: 100
        visible: target !== null && p > 0.01
        width: Math.max(320, previews.width + 16)
        height: menuCol.implicitHeight + 16
        readonly property bool below: target ? target.y - height - 8 < 8 : false
        x: target ? Math.max(8, Math.min(root.width - width - 8, target.x + target.width / 2 - width / 2)) : 0
        y: target ? (below ? target.y + target.height + 8 : target.y - height - 8) : 0
        opacity: Math.min(1, p * 1.4)
        scale: 0.85 + 0.15 * p
        transformOrigin: below ? Item.Top : Item.Bottom

        Rectangle {
            anchors.fill: parent
            radius: Shape.large
            color: Colors.m3surfaceContainerHigh
        }

        Column {
            id: menuCol
            x: 8
            y: 8
            width: parent.width - 16

            MText {
                leftPadding: 12
                topPadding: 6
                bottomPadding: 6
                textStyle: Type.labelLargeEmph
                color: Colors.m3primary
                text: menu.target?.title ?? ""
            }

            Grid {
                id: previews
                columns: Math.min(2, menu.target?.looks.length ?? 1)
                spacing: 8
                bottomPadding: 8

                Repeater {
                    model: menu.target?.looks ?? []

                    Item {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool picked: menu.target?.variant === index
                        width: 176
                        height: 138
                        opacity: Math.max(0, Math.min(1, menu.p * 2 - index * 0.2))
                        scale: 0.9 + 0.1 * Math.min(1, Math.max(0, menu.p * 1.5 - index * 0.1))

                        Rectangle {
                            id: box
                            width: parent.width
                            height: 110
                            radius: Shape.large
                            color: tile.picked ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHighest
                            border.width: tile.picked ? 3 : 0
                            border.color: Colors.m3primary
                            clip: true

                            Loader {
                                id: mini
                                sourceComponent: tile.modelData
                                readonly property real k: item ? Math.min(1, (box.width - 20) / item.width, (box.height - 20) / item.height) : 1
                                x: (box.width - (item?.width ?? 0) * k) / 2
                                y: (box.height - (item?.height ?? 0) * k) / 2
                                scale: k
                                transformOrigin: Item.TopLeft
                                enabled: false
                            }
                        }
                        MText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            textStyle: tile.picked ? Type.labelLargeEmph : Type.labelLarge
                            color: tile.picked ? Colors.m3primary : Colors.m3onSurfaceVariant
                            text: menu.target?.variantNames[tile.index] ?? ""
                        }
                        StateLayer {
                            anchors.fill: box
                            radius: Shape.large
                            onClicked: { menu.target.setVariant(tile.index); menu.close(); }
                        }
                    }
                }
            }

            Rectangle {
                visible: (menu.target?.looks.length ?? 0) > 0
                width: parent.width
                height: 1
                color: Colors.m3outlineVariant
            }

            Repeater {
                model: [
                    { what: "ws", icon: "view_day", label: "Только на этом столе" },
                    { what: "output", icon: "monitor", label: "Только на этом экране" }
                ]
                Item {
                    id: pinRow
                    required property var modelData
                    readonly property bool on: pinRow.modelData.what === "ws" ? !!menu.target?.only?.ws : !!menu.target?.only?.output
                    width: menuCol.width
                    height: 44
                    visible: pinRow.modelData.what === "ws" || Quickshell.screens.length > 1
                    StateLayer { radius: Shape.medium; onClicked: menu.target.pinHere(pinRow.modelData.what) }
                    MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: pinRow.modelData.icon; size: 20; color: Colors.m3onSurfaceVariant }
                    MText { x: 44; width: pinSwitch.x - 44 - 8; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: pinRow.modelData.label }
                    MSwitch { id: pinSwitch; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; scale: 0.8; checked: pinRow.on; onToggled: menu.target.pinHere(pinRow.modelData.what) }
                }
            }

            Item {
                width: menuCol.width
                height: 44
                StateLayer { radius: Shape.medium; onClicked: { menu.close(); Panels.deskEdit = true; } }
                MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: "edit"; size: 20; color: Colors.m3onSurfaceVariant }
                MText { x: 44; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: "Изменить стол" }
            }

            Item {
                width: menuCol.width
                height: 44
                StateLayer {
                    radius: Shape.medium
                    onClicked: {
                        const k = menu.target.key;
                        menu.close();
                        Config.o.desktop[k] = false;
                    }
                }
                MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: "visibility_off"; size: 20; color: Colors.m3onSurfaceVariant }
                MText { x: 44; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: "Убрать со стола" }
            }
        }
    }

    Timer {
        id: arrive
        property string key: ""
        interval: 480
        onTriggered: root.cfg[key] = true
    }

    Item {
        id: sheet
        readonly property var entries: root.desks
        z: 200
        visible: sheetIn.value > 0.01
        SpringValue { id: sheetIn; target: root.editing ? 1 : 0; damping: 0.72; stiffness: 340 }
        width: Math.min(root.width - 48, sheetRow.implicitWidth + 32)
        height: 236
        x: (root.width - width) / 2
        y: root.height - height - 24 + (1 - sheetIn.value) * (height + 40)

        property var dragging: null
        property point ghost: Qt.point(0, 0)

        Rectangle {
            anchors.fill: parent
            radius: Shape.extraLarge
            color: Colors.m3surfaceContainer
        }

        Item {
            x: 20
            y: 12
            width: parent.width - 40
            height: 44
            MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.titleMediumEmph; text: "Виджеты" }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                FilterChip { text: "Сетка"; picked: root.cfg.grid; onClicked: root.cfg.grid = !root.cfg.grid }
                Repeater {
                    model: [16, 24, 32, 48]
                    FilterChip {
                        required property int modelData
                        visible: root.cfg.grid
                        text: String(modelData)
                        picked: root.cfg.gridSize === modelData
                        onClicked: { root.cfg.gridSize = modelData; grid.requestPaint(); }
                    }
                }
                Rectangle {
                    width: doneRow.implicitWidth + 32
                    height: 40
                    radius: doneLayer.pressed ? Shape.medium : 20
                    color: Colors.m3primary
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    Row {
                        id: doneRow
                        anchors.centerIn: parent
                        spacing: 6
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "check"; size: 20; color: Colors.m3onPrimary }
                        MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLargeEmph; color: Colors.m3onPrimary; text: "Готово" }
                    }
                    StateLayer { id: doneLayer; radius: parent.radius; color: Colors.m3onPrimary; onClicked: Panels.deskEdit = false }
                }
            }
        }

        Flickable {
            x: 16
            y: 64
            width: parent.width - 32
            height: 160
            contentWidth: sheetRow.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: sheetRow
                spacing: 10
                Repeater {
                    model: sheet.entries
                    Item {
                        id: tileItem
                        required property var modelData
                        readonly property var d: modelData
                        readonly property bool placed: root.cfg[d.key] === true
                        width: 168
                        height: 160
                        SpringValue { id: tileIn; target: sheetIn.value > 0.5 ? 1 : 0; damping: 0.62; stiffness: 420 }
                        scale: 0.8 + 0.2 * tileIn.value * (tileDrag.active ? 0.9 : 1)
                        opacity: tileDrag.active ? 0.4 : 1

                        Rectangle {
                            id: tileBox
                            width: parent.width
                            height: 124
                            radius: Shape.large
                            color: tileItem.placed ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHighest
                            border.width: tileItem.placed ? 2 : 0
                            border.color: Colors.m3primary
                            clip: true
                            Loader {
                                active: sheet.visible
                                sourceComponent: tileItem.d.looks[tileItem.d.variant] ?? null
                                readonly property real k: item ? Math.min(1, (tileBox.width - 20) / item.width, (tileBox.height - 20) / item.height) : 1
                                x: (tileBox.width - (item?.width ?? 0) * k) / 2
                                y: (tileBox.height - (item?.height ?? 0) * k) / 2
                                scale: k
                                transformOrigin: Item.TopLeft
                                enabled: false
                            }
                            MIcon {
                                visible: tileItem.d.looks.length === 0
                                anchors.centerIn: parent
                                icon: "music_note"; size: 40; fill: 1
                                color: Colors.m3primary
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                width: 28; height: 28; radius: 14
                                color: tileItem.placed ? Colors.m3primary : Colors.m3surfaceContainer
                                MIcon { anchors.centerIn: parent; icon: tileItem.placed ? "check" : "add"; size: 18; color: tileItem.placed ? Colors.m3onPrimary : Colors.m3onSurface }
                            }
                        }
                        MText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            textStyle: tileItem.placed ? Type.labelLargeEmph : Type.labelLarge
                            color: tileItem.placed ? Colors.m3primary : Colors.m3onSurfaceVariant
                            text: tileItem.d.title
                        }
                        TapHandler { onTapped: root.cfg[tileItem.d.key] = !tileItem.placed }
                        DragHandler {
                            id: tileDrag
                            target: null
                            onCentroidChanged: if (active) sheet.ghost = tileItem.mapToItem(root, centroid.position.x, centroid.position.y)
                            onActiveChanged: {
                                if (active) { sheet.dragging = tileItem.d; return; }
                                const g = sheet.ghost;
                                const d = sheet.dragging;
                                sheet.dragging = null;
                                if (g.y > sheet.y - 20) return;
                                const p = col.mapFromItem(root, g.x, g.y);
                                const pos = Object.assign({}, root.cfg.positions ?? {});
                                const w = (d.child?.width ?? 200) * d.kk, h = (d.child?.height ?? 120) * d.kk;
                                const at = { x: d.clampX(d.snap(p.x - w / 2 - root.shiftX)), y: d.clampY(d.snap(p.y - h / 2 - root.shiftY)) };
                                pos[d.placeKey] = at;
                                root.cfg.positions = pos;
                                incoming.lastD = d;
                                const c = root.mapFromItem(col, at.x + root.shiftX, at.y + root.shiftY);
                                incoming.settle(Qt.point(c.x, c.y));
                                arrive.restart();
                                arrive.key = d.key;
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: incoming
        z: 300
        visible: sheet.dragging !== null || settling
        property bool settling: false
        property point dest: Qt.point(0, 0)
        readonly property var d: sheet.dragging ?? lastD
        property var lastD: null
        readonly property real w: (d?.child?.width ?? 200) * (d?.kk ?? 1)
        readonly property real h: (d?.child?.height ?? 120) * (d?.kk ?? 1)
        SpringValue { id: ix; target: incoming.settling ? incoming.dest.x : sheet.ghost.x - incoming.w * root.zoom / 2; damping: incoming.settling ? 0.65 : 0.85; stiffness: incoming.settling ? 420 : 1600; epsilon: 0.3 }
        SpringValue { id: iy; target: incoming.settling ? incoming.dest.y : sheet.ghost.y - incoming.h * root.zoom / 2; damping: incoming.settling ? 0.65 : 0.85; stiffness: incoming.settling ? 420 : 1600; epsilon: 0.3 }
        SpringValue { id: iS; target: sheet.dragging ? 1 : 0; damping: 0.6; stiffness: 420 }
        x: ix.value
        y: iy.value
        width: w
        height: h
        rotation: Math.max(-1, Math.min(1, ix.velocity / 2500)) * 9
        transformOrigin: Item.TopLeft
        scale: (incoming.settling ? 1 : 0.55 + 0.45 * Math.min(1, iS.value)) * root.zoom
        opacity: incoming.settling ? 1 : Math.min(1, iS.value * 1.5)
        function settle(pt) { dest = pt; settling = true; settleEnd.restart(); }
        Timer { id: settleEnd; interval: 520; onTriggered: { incoming.settling = false; incoming.lastD = null; } }
        onDChanged: if (sheet.dragging) { lastD = sheet.dragging; ix.value = sheet.ghost.x - w / 2; iy.value = sheet.ghost.y - h / 2; }

        Loader {
            sourceComponent: incoming.d?.looks[incoming.d.variant] ?? null
            scale: incoming.d?.kk ?? 1
            transformOrigin: Item.TopLeft
            enabled: false
        }
        MaterialShape {
            visible: (incoming.d?.looks.length ?? 1) === 0
            anchors.centerIn: parent
            width: 96; height: 96
            shape: "cookie9Sided"
            color: Colors.m3primaryContainer
            MIcon { anchors.centerIn: parent; icon: "music_note"; size: 40; fill: 1; color: Colors.m3onPrimaryContainer }
        }
    }

    Rectangle {
        id: deskMenu
        property bool shown: false
        function openAt(px, py) {
            x = Math.max(8, Math.min(root.width - width - 8, px));
            y = Math.max(8, Math.min(root.height - height - 8, py));
            shown = true;
        }
        SpringValue { id: dmIn; target: deskMenu.shown ? 1 : 0; damping: 0.68; stiffness: 560 }
        z: 400
        visible: dmIn.value > 0.01
        width: 248
        height: dmCol.implicitHeight + 16
        radius: Shape.large
        color: Colors.m3surfaceContainerHigh
        opacity: Math.min(1, dmIn.value * 1.4)
        scale: 0.8 + 0.2 * dmIn.value
        transformOrigin: Item.TopLeft

        Column {
            id: dmCol
            x: 8; y: 8
            width: parent.width - 16
            Repeater {
                model: [
                    { icon: "dashboard_customize", label: "Изменить стол", act: () => { root.cfg.enabled = true; Panels.deskEdit = true; } },
                    { icon: root.cfg.enabled ? "visibility_off" : "visibility", label: root.cfg.enabled ? "Спрятать виджеты" : "Показать виджеты", act: () => root.cfg.enabled = !root.cfg.enabled },
                    { icon: "wallpaper", label: "Обои", act: () => Panels.open("wallpaper") },
                    { icon: "palette", label: "Оформление", act: () => Panels.openSettings("look") }
                ]
                Item {
                    id: dmRow
                    required property var modelData
                    required property int index
                    width: dmCol.width
                    height: 44
                    opacity: Math.max(0, Math.min(1, dmIn.value * 2 - index * 0.15))
                    transform: Translate { y: (1 - Math.min(1, dmIn.value)) * (8 + dmRow.index * 4) }
                    StateLayer { radius: Shape.medium; onClicked: { deskMenu.shown = false; dmRow.modelData.act(); } }
                    MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: dmRow.modelData.icon; size: 20; color: Colors.m3onSurfaceVariant }
                    MText { x: 44; anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: dmRow.modelData.label }
                }
            }
        }
    }
}

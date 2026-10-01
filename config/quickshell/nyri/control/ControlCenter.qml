import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets
import qs.notifications

Surface {
    id: root

    name: "control"
    keyboard: false

    readonly property var battery: UPower.displayDevice

    property string page: "main"
    property string shownPage: ""
    onPageChanged: { if (page !== "main") shownPage = page; flick.contentY = 0; }
    onOpenChanged: if (open) { origin = null; page = Panels.tab || "main"; }
    SpringValue { id: slide; target: root.page === "main" ? 0 : 1; damping: 0.78; stiffness: 360; epsilon: 0.001 }

    property var origin: null
    function openFrom(tile, pageId) {
        const pt = tile.mapToItem(flick.contentItem, 0, 0);
        origin = { x: pt.x, y: pt.y, w: tile.width, h: tile.height, radius: tile.checked || !tile.label ? tile.height / 2 : Shape.largeIncreased,
                   color: tile.checked ? Colors.m3primary : tile.label ? Colors.m3surfaceContainerHighest : Colors.m3secondaryContainer,
                   ink: tile.checked ? Colors.m3onPrimary : Colors.m3onSurface, icon: tile.icon, label: tile.label };
        page = pageId;
    }

    function tileOn(id) { return Config.list(Config.o.control.hidden).indexOf(id) < 0; }
    function cardOn(id) { return Config.list(Config.o.control.hiddenCards).indexOf(id) < 0; }

    readonly property var carousel: {
        const out = [];
        const playing = Media.player?.isPlaying ?? false;
        if (playing && cardOn("media")) out.push({ id: "media", kind: "media", active: true });
        const live = Activities.list.filter(a => ["media", "phone", "timer", "stopwatch"].indexOf(a.kind) < 0 && cardOn(a.kind));
        for (const a of live) out.push({ id: "live:" + a.id, kind: "live", a, active: true });
        if (!playing && cardOn("media")) out.push({ id: "media", kind: "media", active: false });
        if (Phone.daemon && cardOn("phone")) out.push({ id: "phone", kind: "phone", active: false });
        const timers = Activities.list.filter(a => a.kind === "timer");
        if (!timers.length && cardOn("timer")) out.push({ id: "timer", kind: "live", a: { id: "idle:timer", kind: "timer-idle", actions: [] }, active: false });
        if (cardOn("timer")) timers.forEach((a, i) => out.push({ id: i ? "live:" + a.id : "timer", kind: "live", a, active: true }));
        const sw = Activities.list.find(a => a.kind === "stopwatch");
        if (cardOn("stopwatch")) out.push({ id: "stopwatch", kind: "live", a: sw ?? { id: "idle:stopwatch", kind: "stopwatch-idle", actions: [] }, active: !!sw });
        return out;
    }
    function slideOf(id) { return carousel.find(c => c.id === id) ?? null; }

    function duration(sec) {
        const total = Math.round(sec / 60), h = Math.floor(total / 60), m = total % 60;
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }

    Popout {
        id: card

        progress: root.progress
        toX: parent.width - toW - 12
        toW: 420
        toH: Math.min((root.page === "main" ? content.implicitHeight : sub.implicitHeight) + 32, room)

        Behavior on toH { SpatialAnim {} }
        defaultFromX: parent.width - 12 - 200
        defaultFromW: 200

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            Overscroll { flick: flick; step: 3.2; touchpad: 2.4; coast: 0.5; coastMax: 1800; glideStiff: 780 }

            contentHeight: root.page === "main" ? content.implicitHeight : sub.implicitHeight

            Item {
                id: frame
                readonly property var o: root.origin
                readonly property real t: Math.max(0, Math.min(1, slide.value))
                readonly property real tt: Math.max(0, slide.value)
                visible: sub.active && slide.value > 0.005
                x: o ? o.x * (1 - t) : 0
                y: o ? o.y * (1 - t) : 0
                width: o ? o.w + (flick.width - o.w) * tt : flick.width
                height: o ? o.h + (sub.implicitHeight - o.h) * tt : sub.implicitHeight
                clip: o !== null && slide.value < 0.995

                Rectangle {
                    anchors.fill: parent
                    visible: frame.o !== null
                    radius: frame.o ? frame.o.radius + (Shape.large - frame.o.radius) * frame.t : 0
                    color: frame.o ? Qt.tint(frame.o.color, Qt.alpha(Colors.m3surfaceContainer, Math.min(1, frame.t * 1.3))) : "transparent"
                    opacity: 1 - Math.max(0, (slide.value - 0.75) / 0.25)
                }

            Loader {
                id: sub
                width: flick.width
                active: root.page !== "main" || slide.value > 0.01
                x: frame.o ? -frame.x : (1 - slide.value) * 48
                y: frame.o ? -frame.y : 0
                opacity: frame.o ? Math.max(0, Math.min(1, (slide.value - 0.35) / 0.45)) : slide.value
                visible: opacity > 0.01
                source: ({ audio: "AudioPage.qml", wifi: "WifiPage.qml", bt: "BtPage.qml", privacy: "PrivacyPage.qml", phone: "PhonePage.qml" })[root.shownPage] ?? ""
                onLoaded: { item.width = Qt.binding(() => sub.width); cascade.play(item); }
                Cascade { id: cascade; rise: 36 }

                Connections {
                    target: sub.item
                    function onBack() { root.page = "main" }
                }
            }
            }

            Column {
                id: content
                width: parent.width
                spacing: 12
                x: root.origin ? 0 : -slide.value * 48
                opacity: root.origin ? Math.max(0, 1 - slide.value * 1.4) : 1 - slide.value
                scale: root.origin ? 1 - 0.04 * slide.value : 1
                visible: opacity > 0.01

                Item {
                    width: parent.width
                    height: 48

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        MText {
                            textStyle: Type.titleLarge
                            text: "Привет, " + Quickshell.env("USER")
                        }

                        MText {
                            visible: root.battery?.isLaptopBattery ?? false
                            textStyle: Type.labelMedium
                            color: Colors.m3onSurfaceVariant
                            text: {
                                const b = root.battery;
                                if (!b) return "";
                                const pct = Math.round((b.percentage > 1 ? b.percentage : b.percentage * 100));
                                if (b.state === UPowerDeviceState.Charging && b.timeToFull > 0)
                                    return pct + "% · до полной " + root.duration(b.timeToFull);
                                if (b.timeToEmpty > 0)
                                    return pct + "% · осталось " + root.duration(b.timeToEmpty);
                                return pct + "%";
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        IconButton {
                            icon: "settings"
                            style: "tonal"
                            onClicked: Panels.openSettings()
                        }

                        IconButton {
                            icon: "lock"
                            style: "tonal"
                            onClicked: { Panels.close(); Lock.lock(); }
                        }

                        IconButton {
                            icon: "power_settings_new"
                            style: "filled"
                            onClicked: Panels.open("session")
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: sliders.implicitHeight + 24
                    radius: Shape.largeIncreased
                    color: Colors.m3surfaceContainerHigh

                    Column {
                        id: sliders
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 4

                        Row {
                            width: parent.width
                            spacing: 4

                            MSlider {
                                width: parent.width - 48
                                trackHeight: 40
                                icon: Audio.icon
                                value: Audio.muted ? 0 : Audio.volume
                                onMoved: v => Audio.setVolume(v)
                            }

                            IconButton {
                                id: soundBtn
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "tune"
                                onClicked: root.openFrom(soundBtn, "audio")
                            }
                        }

                        MSlider {
                            width: parent.width
                            visible: Brightness.available
                            trackHeight: 40
                            icon: "brightness_6"
                            value: Brightness.level
                            onMoved: v => Brightness.set(v)
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 8

                    readonly property real cell: (width - spacing) / 2

                    Tile {
                        id: wifiTile
                        width: parent.cell
                        icon: Net.icon
                        label: "Wi-Fi"
                        visible: root.tileOn("wifi")
                        sublabel: Net.label
                        checked: Net.enabled
                        details: true
                        onDetailsClicked: root.openFrom(wifiTile, "wifi")
                        onClicked: Net.toggle()
                        onSecondaryClicked: root.openFrom(wifiTile, "wifi")
                    }

                    Tile {
                        id: btTile
                        width: parent.cell
                        icon: Bt.enabled ? "bluetooth" : "bluetooth_disabled"
                        label: "Bluetooth"
                        visible: root.tileOn("bt")
                        sublabel: Bt.label
                        checked: Bt.enabled
                        details: true
                        onDetailsClicked: root.openFrom(btTile, "bt")
                        onClicked: Bt.toggle()
                        onSecondaryClicked: root.openFrom(btTile, "bt")
                    }

                    Tile {
                        width: parent.cell
                        icon: "do_not_disturb_on"
                        label: "Не беспокоить"
                        visible: root.tileOn("dnd")
                        sublabel: Notifs.dnd ? "Включено" : "Выключено"
                        checked: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }

                    Tile {
                        width: parent.cell
                        icon: Power.icon
                        label: "Питание"
                        visible: root.tileOn("power")
                        sublabel: Power.label
                        checked: Power.profile !== PowerProfile.Balanced
                        onClicked: Power.cycle()
                    }

                    Tile {
                        width: parent.cell
                        icon: "coffee"
                        label: "Не засыпать"
                        visible: root.tileOn("caffeine")
                        sublabel: Toggles.caffeine ? "Экран не гаснет" : "Выключено"
                        checked: Toggles.caffeine
                        onClicked: Toggles.caffeine = !Toggles.caffeine
                    }

                    Tile {
                        width: parent.cell
                        icon: "nightlight"
                        label: "Ночной свет"
                        visible: root.tileOn("night")
                        sublabel: Toggles.nightLight ? "Тёплый экран" : "Выключен"
                        checked: Toggles.nightLight
                        onClicked: Toggles.setNightLight(!Toggles.nightLight)
                    }

                    Tile {
                        width: parent.cell
                        icon: Audio.micMuted ? "mic_off" : "mic"
                        label: "Микрофон"
                        visible: root.tileOn("mic")
                        sublabel: Audio.micMuted ? "Выключен" : "Включён"
                        checked: !Audio.micMuted
                        onClicked: Audio.toggleMic()
                    }

                    Tile {
                        id: privacyTile
                        width: parent.cell
                        icon: Privacy.active ? "shield_lock" : "shield_person"
                        label: "Приватность"
                        visible: root.tileOn("privacy")
                        sublabel: Privacy.active ? "Включено" : "Выключено"
                        checked: Privacy.active
                        details: true
                        onDetailsClicked: root.openFrom(privacyTile, "privacy")
                        onClicked: Config.o.privacy.mode = !Config.o.privacy.mode
                        onSecondaryClicked: root.openFrom(privacyTile, "privacy")
                    }

                    Tile {
                        width: parent.cell
                        icon: Toggles.dark ? "dark_mode" : "light_mode"
                        label: "Тёмная тема"
                        visible: root.tileOn("dark")
                        sublabel: Toggles.dark ? "Включена" : "Выключена"
                        checked: Toggles.dark
                        onClicked: Toggles.toggleDark()
                    }

                    Tile {
                        width: parent.cell
                        icon: "screenshot_region"
                        label: "Захват экрана"
                        visible: root.tileOn("capture")
                        sublabel: Toggles.recording ? "Идёт запись" : "Снимок · видео"
                        checked: Toggles.recording
                        onClicked: Quickshell.execDetached([Paths.bin + "/nyri", "region", "menu"])
                    }
                }

                Collapse {
                    width: parent.width
                    shown: root.carousel.length > 0

                    Item {
                        width: parent.width
                        readonly property real slideH: 212
                        height: slideH + (root.carousel.length > 1 ? 26 : 0)

                        ListView {
                            id: carList
                            property string held: ""
                            function hold() { held = root.carousel[currentIndex]?.id ?? ""; }
                            function show(i) {
                                currentIndex = Math.max(0, Math.min(count - 1, i));
                                hold();
                            }
                            Connections {
                                target: root
                                function onCarouselChanged() { Qt.callLater(carList.keep); }
                            }
                            function keep() {
                                const i = root.carousel.findIndex(c => c.id === held);
                                if (i < 0) { hold(); return; }
                                if (i !== currentIndex) { currentIndex = i; jump(); }
                            }
                            function jump() { glide.value = currentIndex * step; glide.velocity = 0; glide.running = false; contentX = glide.value; }

                            width: parent.width
                            height: parent.slideH
                            orientation: ListView.Horizontal
                            spacing: 10
                            clip: true
                            interactive: false
                            highlightFollowsCurrentItem: false
                            model: ScriptModel { values: root.carousel; objectProp: "id" }
                            readonly property real step: width + spacing

                            SpringValue {
                                id: glide
                                target: carList.currentIndex * carList.step
                                damping: 0.86
                                stiffness: 560
                                epsilon: 0.3
                                onValueChanged: if (!swipe.active) carList.contentX = value
                            }

                            DragHandler {
                                id: swipe
                                target: null
                                yAxis.enabled: false
                                property real from: 0
                                onActiveChanged: {
                                    if (active) {
                                        glide.running = false;
                                        from = carList.contentX;
                                        return;
                                    }
                                    const moved = -translation.x, v = -centroid.velocity.x;
                                    let i = Math.round(from / carList.step);
                                    if (moved > carList.step * 0.18 || v > 350) i++;
                                    else if (moved < -carList.step * 0.18 || v < -350) i--;
                                    glide.value = carList.contentX;
                                    glide.velocity = v;
                                    carList.show(i);
                                    glide.running = true;
                                }
                                onTranslationChanged: {
                                    if (!active) return;
                                    const max = Math.max(0, (carList.count - 1) * carList.step);
                                    let x = from - translation.x;
                                    if (x < 0) x = -48 * (1 - Math.exp(x / 160));
                                    else if (x > max) x = max + 48 * (1 - Math.exp(-(x - max) / 160));
                                    carList.contentX = x;
                                }
                            }

                            Connections {
                                target: root
                                function onOpenChanged() {
                                    if (!root.open) return;
                                    carList.show(root.carousel.findIndex(c => c.active));
                                    carList.jump();
                                }
                            }

                            delegate: Item {
                                id: slide
                                required property var modelData
                                required property int index
                                width: carList.width
                                height: carList.height
                                readonly property real d: Math.min(1, Math.abs(x - carList.contentX) / width)
                                scale: 1 - 0.07 * d
                                opacity: 1 - 0.45 * d
                                transformOrigin: x < carList.contentX ? Item.Right : Item.Left

                                Loader {
                                    id: body
                                    width: parent.width
                                    height: parent.height
                                    readonly property var cur: root.slideOf(slide.modelData.id) ?? slide.modelData
                                    sourceComponent: cur.kind === "media" ? mediaC : cur.kind === "phone" ? phoneC : liveC
                                    property var a: cur.a
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: carList
                            acceptedButtons: Qt.NoButton
                            property real acc: 0
                            property real last: 0
                            property int axis: 0
                            property bool flipped: false
                            function flip(dir) {
                                carList.show(carList.currentIndex + dir);
                            }
                            onWheel: w => {
                                const now = Date.now();
                                const gap = now - last;
                                last = now;
                                const pad = w.pixelDelta.x !== 0 || w.pixelDelta.y !== 0;
                                if (!pad) {
                                    if (gap > 300) acc = 0;
                                    acc += Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) ? w.angleDelta.x : w.angleDelta.y;
                                    if (Math.abs(acc) >= 120) { flip(acc < 0 ? 1 : -1); acc = 0; }
                                    return;
                                }
                                if (w.phase === Qt.ScrollBegin || gap > 180) { axis = 0; acc = 0; flipped = false; }
                                if (axis === 0) {
                                    const dx = Math.abs(w.pixelDelta.x), dy = Math.abs(w.pixelDelta.y);
                                    if (dx + dy >= 3) axis = dx > dy ? 1 : 2;
                                }
                                if (axis !== 1) { w.accepted = false; return; }
                                if (w.phase === Qt.ScrollEnd) return;
                                acc += w.pixelDelta.x;
                                if (!flipped && Math.abs(acc) >= 60) { flip(acc < 0 ? 1 : -1); flipped = true; }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.slideH + 12
                            spacing: 6
                            visible: root.carousel.length > 1
                            Repeater {
                                model: root.carousel.length
                                Rectangle {
                                    required property int index
                                    readonly property bool cur: index === carList.currentIndex
                                    SpringValue { id: dotW; target: parent.parent ? (cur ? 22 : 8) : 8; damping: 0.6; stiffness: 600 }
                                    width: dotW.value
                                    height: 8
                                    radius: 4
                                    color: cur ? Colors.m3primary : Colors.m3outlineVariant
                                    Behavior on color { ColorAnim {} }
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: carList.show(parent.index) }
                                }
                            }
                        }
                    }
                }

                Component { id: mediaC; MediaCard { active: root.open } }
                Component { id: phoneC; PhoneCard { onOpened: root.page = "phone" } }
                Component { id: liveC; LiveSlide { activity: parent.a } }

                Item {
                    width: parent.width
                    height: 40

                    FlowText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 4
                        textStyle: Type.titleMediumEmph
                        text: Notifs.count > 0 ? "Уведомления · " + Notifs.count : "Уведомления"
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Notifs.count > 0
                        width: clearLabel.implicitWidth + 28
                        height: 36
                        radius: clearLayer.pressed ? Shape.medium : height / 2
                        color: Colors.m3secondaryContainer

                        Behavior on radius { SpatialAnim { speed: "fast" } }

                        MText {
                            id: clearLabel
                            anchors.centerIn: parent
                            textStyle: Type.labelLarge
                            color: Colors.m3onSecondaryContainer
                            text: "Очистить"
                        }

                        StateLayer {
                            id: clearLayer
                            radius: parent.radius
                            color: Colors.m3onSecondaryContainer
                            onClicked: Notifs.clearAll()
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: Notifs.count > 0

                    Repeater {
                        model: Notifs.list

                        Swipeable {
                            id: sw
                            required property var modelData
                            width: parent.width
                            onDismissed: sw.modelData.dismiss()
                            NotificationCard {
                                width: sw.width
                                height: implicitHeight
                                notif: sw.modelData
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: Notifs.count === 0
                    spacing: 8
                    topPadding: 8
                    bottomPadding: 8

                    MaterialShape {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72
                        height: 72
                        shape: "cookie7Sided"
                        color: Colors.m3secondaryContainer

                        MIcon {
                            anchors.centerIn: parent
                            icon: "notifications_off"
                            size: 30
                            color: Colors.m3onSecondaryContainer
                        }
                    }

                    MText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textStyle: Type.bodyMedium
                        color: Colors.m3onSurfaceVariant
                        text: "Всё прочитано"
                    }
                }
            }
        }
    }
}

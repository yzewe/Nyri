import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets
import qs.wallpaper

Scope {
    id: root

    property string buffer: ""
    property bool checking: false
    property bool failed: false
    property bool unlocking: false
    property bool awake: false
    function type(text) {
        root.failed = false;
        root.buffer = text;
        if (text.length) wake();
    }

    function submit() {
        if (checking || buffer === "")
            return;
        checking = true;
        if (Panels.nested) fakeCheck.restart();
        else pam.start();
    }

    Timer {
        id: fakeCheck
        interval: 1600
        onTriggered: {
            root.checking = false;
            root.type("");
            root.failed = true;
            root.wake();
        }
    }

    function wake() {
        awake = true;
        doze.restart();
    }

    function power(cmd) {
        if (Panels.nested) console.log("nested: skipped", cmd.join(" "));
        else Quickshell.execDetached(cmd);
    }

    Connections {
        target: Lock
        function onUnlockRequested() { if (Panels.nested && Lock.locked) root.unlocking = true; }
        function onLockedChanged() {
            if (Lock.locked) {
                root.awake = false;
                root.unlocking = false;
                root.failed = false;
            }
        }
    }

    Timer {
        id: doze
        interval: 20000
        onTriggered: if (!root.checking && root.buffer === "") root.awake = false
    }

    Timer {
        running: root.unlocking
        interval: 1500
        onTriggered: { root.unlocking = false; Lock.locked = false; }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: { if (responseRequired) respond(root.buffer) }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.unlocking = true;
                root.buffer = "";
            } else {
                root.type("");
                root.failed = true;
                root.wake();
            }
        }
    }

    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface
            color: Colors.m3surface

            property bool ready: false
            Timer { running: true; interval: 16; onTriggered: surface.ready = true }
            Component.onCompleted: input.forceActiveFocus()

            SpringValue {
                id: enter
                target: surface.ready && !root.unlocking ? 1 : 0
                damping: root.unlocking ? 1.0 : 0.78
                stiffness: root.unlocking ? 260 : 170
                epsilon: 0.002
                onRunningChanged: if (!running && root.unlocking && value < 0.01) { root.unlocking = false; Lock.locked = false; }
            }
            SpringValue { id: wakeS; target: root.awake && !root.unlocking ? 1 : 0; damping: 0.74; stiffness: 260 }

            readonly property real e: Math.max(0, Math.min(1, enter.value))
            readonly property real w: wakeS.value
            readonly property real wc: Math.max(0, Math.min(1, w))
            readonly property bool wide: width > height

            SpringValue { id: checkS; target: root.checking ? 1 : 0; damping: 0.72; stiffness: 420 }
            readonly property real dim: 1 - 0.75 * Math.max(0, Math.min(1, checkS.value))

            Image {
                id: wall
                anchors.fill: parent
                source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(surface.width, surface.height)
            }

            readonly property string sceneFile: (Config.o.wallpaper.animated ?? false) && Colors.wallpaper.indexOf("/walls/") >= 0 && Colors.wallpaper.endsWith(".png")
                                                ? Colors.wallpaper.replace(/\.png$/, ".json") : ""
            readonly property bool live: sceneFile !== "" && liveScene.ready
            Scene {
                id: liveScene
                anchors.fill: parent
                file: surface.sceneFile
                pace: 0.5
                running: Lock.locked && !root.awake && !root.checking && !root.unlocking && !Config.o.lock.blur
                visible: surface.live && !Config.o.lock.blur
                opacity: surface.e
                scale: 1 + 0.06 * surface.e
            }

            MultiEffect {
                anchors.fill: parent
                visible: !surface.live || Config.o.lock.blur
                source: surface.live && !Config.o.lock.blur ? liveScene : wall
                blurEnabled: Config.o.lock.blur
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
                opacity: surface.e
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.mode === "light" ? Colors.m3surface : Colors.m3scrim
                opacity: ((Colors.mode === "light" ? 0.62 : 0.35) + 0.14 * surface.wc) * surface.e
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                property point first: Qt.point(-1, -1)
                onPositionChanged: m => {
                    if (first.x < 0) { first = Qt.point(m.x, m.y); return; }
                    if (Math.abs(m.x - first.x) + Math.abs(m.y - first.y) > 12) root.wake();
                }
                onClicked: { root.wake(); input.forceActiveFocus(); }
            }

            SystemClock { id: clock; precision: SystemClock.Minutes }

            Item {
                id: clockBox

                readonly property real hw: hours.width
                readonly property real mw: minutes.width
                readonly property real lh: hours.height
                readonly property real overlap: 64
                readonly property real gapH: 70
                readonly property real stackW: Math.max(hw, mw)
                readonly property real rowW: hw + gapH + mw
                readonly property bool row: Config.o.lock.clock === "row"
                readonly property real t: row ? 1 : surface.w
                readonly property real awakeScale: 0.5
                readonly property real restScale: row ? 0.72 : 1

                readonly property real layoutScale: restScale + (awakeScale - restScale) * surface.w
                readonly property real groupH: height * layoutScale + 12 + glance.height + (40 + auth.height) * surface.wc

                anchors.horizontalCenter: parent.horizontalCenter
                width: stackW + (rowW - stackW) * t
                height: (2 * lh - overlap) + (lh - (2 * lh - overlap)) * t
                y: (surface.height - groupH) / 2 + (1 - surface.e) * 28
                scale: layoutScale
                transformOrigin: Item.Top
                opacity: surface.e * surface.dim

                RollingText {
                    id: hours
                    x: (clockBox.stackW - width) / 2 * (1 - clockBox.t)
                    pixelSize: 210
                    weight: 700
                    color: Colors.m3primary
                    speed: "slow"
                    text: Qt.formatTime(clock.date, "HH")
                }

                MText {
                    x: clockBox.hw + (clockBox.gapH - width) / 2
                    y: (clockBox.lh - height) / 2 - 12
                    opacity: Math.max(0, Math.min(1, clockBox.t * 2 - 1))
                    font.pixelSize: 180
                    font.variableAxes: ({ "wght": 700 })
                    color: Colors.m3onSurfaceVariant
                    text: ":"
                }

                RollingText {
                    id: minutes
                    x: (clockBox.stackW - width) / 2 * (1 - clockBox.t) + (clockBox.hw + clockBox.gapH) * clockBox.t
                    y: (clockBox.lh - clockBox.overlap) * (1 - clockBox.t)
                    pixelSize: 210
                    weight: 700
                    color: Colors.m3primaryContainer
                    speed: "slow"
                    text: Qt.formatTime(clock.date, "mm")
                }
            }

            Row {
                id: glance
                anchors.horizontalCenter: parent.horizontalCenter
                y: clockBox.y + clockBox.height * clockBox.scale + 12
                spacing: 12
                opacity: surface.e * surface.dim

                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    textStyle: Type.titleLarge
                    font.variableAxes: ({ "wght": 550 })
                    color: Colors.m3onSurface
                    text: {
                        const s = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM");
                        return s.charAt(0).toUpperCase() + s.slice(1);
                    }
                }
                Rectangle {
                    visible: Weather.ready && Config.o.lock.weather
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: Colors.m3outline
                }
                MIcon {
                    visible: Weather.ready && Config.o.lock.weather
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Weather.ready ? Weather.describe(Weather.current.code, Weather.current.day).icon : ""
                    size: 26
                    fill: 1
                    color: Colors.m3primary
                }
                MText {
                    visible: Weather.ready && Config.o.lock.weather
                    anchors.verticalCenter: parent.verticalCenter
                    textStyle: Type.titleLarge
                    font.variableAxes: ({ "wght": 550 })
                    color: Colors.m3onSurface
                    text: Weather.ready ? Weather.current.temp + "° · " + Weather.describe(Weather.current.code, Weather.current.day).text : ""
                }
            }

            Row {
                id: liveRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24 - (1 - surface.e) * 40
                spacing: 8
                opacity: surface.e
                visible: Config.o.lock.live

                property real now: Date.now()
                Timer {
                    running: Lock.locked && liveRow.visible
                    interval: 1000
                    repeat: true
                    onTriggered: liveRow.now = Date.now()
                }
                function clock(ms) {
                    const s = Math.max(0, Math.round(ms / 1000)), m = Math.floor(s / 60), r = s % 60;
                    return m + ":" + String(r).padStart(2, "0");
                }

                Repeater {
                    model: ScriptModel { values: Activities.list.filter(a => !a.ambient || a.kind === "bt").slice(0, 3); objectProp: "id" }
                    Rectangle {
                        id: pill
                        required property var modelData
                        required property int index
                        readonly property bool loud: modelData.tone === "error"
                        height: 40
                        width: pillRow.implicitWidth + 24
                        radius: 20
                        color: loud ? Colors.m3errorContainer : Colors.m3surfaceContainerHigh
                        SpringValue { id: pillIn; target: 1; damping: 0.6; stiffness: 420; Component.onCompleted: { value = 0; running = true; } }
                        scale: 0.6 + 0.4 * pillIn.value
                        opacity: Math.min(1, pillIn.value)
                        Row {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: 8
                            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: pill.modelData.icon; size: 20; fill: 1; color: pill.loud ? Colors.m3error : Colors.m3primary }
                            MText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 220)
                                elide: Text.ElideRight
                                textStyle: Type.labelLargeEmph
                                color: pill.loud ? Colors.m3onErrorContainer : Colors.m3onSurface
                                text: pill.modelData.title
                            }
                            MText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: text !== ""
                                textStyle: Type.labelLargeEmph
                                font.features: { "tnum": 1 }
                                color: pill.loud ? Colors.m3error : Colors.m3primary
                                text: (pill.modelData.frozen ?? -1) >= 0 ? liveRow.clock(pill.modelData.frozen)
                                    : pill.modelData.until > 0 ? liveRow.clock(pill.modelData.until - liveRow.now)
                                    : pill.modelData.since > 0 ? liveRow.clock(liveRow.now - pill.modelData.since) : ""
                            }
                        }
                    }
                }
            }

            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 24
                spacing: 12
                opacity: surface.e

                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    textStyle: Type.labelLargeEmph
                    color: Colors.m3onSurfaceVariant
                    text: Compositor.layoutShort
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: UPower.displayDevice?.isLaptopBattery ?? false
                    spacing: 6
                    readonly property real level: {
                        const p = UPower.displayDevice?.percentage ?? 0;
                        return p > 1 ? p / 100 : p;
                    }
                    readonly property bool charging: UPower.displayDevice?.state === UPowerDeviceState.Charging
                    BatteryPill {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 14
                        textSize: 14
                        level: parent.level
                        charging: parent.charging
                    }
                }
            }

            Item {
                id: auth
                anchors.horizontalCenter: parent.horizontalCenter
                y: glance.y + glance.height + 40 + (1 - surface.w) * 60
                width: field.width
                height: field.height
                opacity: surface.wc * surface.dim
                visible: opacity > 0.01
                enabled: root.awake

                Rectangle {
                    id: field

                    property real shake: shakeS.value

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360
                    height: 64
                    radius: height / 2
                    color: root.failed ? Colors.m3errorContainer : Colors.m3surfaceContainerHigh
                    transform: Translate { x: field.shake }

                    Behavior on color { ColorAnim {} }

                    SpringValue { id: shakeS; target: 0; damping: 0.22; stiffness: 900; epsilon: 0.05 }
                    Connections {
                        target: root
                        function onFailedChanged() {
                            if (root.failed) { shakeS.velocity = 900; shakeS.running = true; }
                        }
                    }

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 22
                        icon: root.failed ? "error" : "lock"
                        fill: 1
                        color: root.failed ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                    }

                    PasswordDots {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 56
                        width: go.x - x - 10
                        height: size
                        length: root.buffer.length
                        size: 14
                    }

                    FlowText {
                        anchors.centerIn: parent
                        visible: root.buffer === ""
                        textStyle: Type.bodyLarge
                        color: root.failed ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                        text: root.checking ? "Проверяю…" : root.failed ? "Неверный пароль" : "Пароль"
                    }

                    Rectangle {
                        id: go
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        width: 48
                        height: 48
                        radius: goLayer.pressed ? Shape.medium : height / 2
                        color: root.buffer !== "" ? Colors.m3primary : "transparent"
                        Behavior on radius { SpatialAnim { speed: "fast" } }
                        Behavior on color { ColorAnim {} }

                        MIcon {
                            anchors.centerIn: parent
                            icon: "arrow_forward"
                            color: root.buffer !== "" ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                        }
                        StateLayer {
                            id: goLayer
                            radius: go.radius
                            color: Colors.m3onPrimary
                            onClicked: root.submit()
                        }
                    }
                }

                Rectangle {
                    id: capsChip
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property bool on: Toggles.capsLock
                    y: field.height + 16 - 10 * (1 - capsIn.value)
                    width: capsRow.implicitWidth + 28
                    height: 36
                    radius: 18
                    color: Colors.m3secondaryContainer
                    opacity: Math.max(0, Math.min(1, capsIn.value))
                    scale: 0.7 + 0.3 * capsIn.value
                    visible: opacity > 0.01
                    SpringValue { id: capsIn; target: capsChip.on ? 1 : 0; damping: 0.7; stiffness: 400 }

                    Row {
                        id: capsRow
                        anchors.centerIn: parent
                        spacing: 6
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "keyboard_capslock"; size: 18; fill: 1; color: Colors.m3onSecondaryContainer }
                        MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLargeEmph; color: Colors.m3onSecondaryContainer; text: "Caps Lock включён" }
                    }
                }
            }

            LoadingIndicator {
                anchors.centerIn: parent
                width: 120
                height: 120
                running: root.checking
                visible: checkS.value > 0.01
                opacity: Math.min(1, checkS.value)
                scale: 0.6 + 0.4 * checkS.value
            }

            MText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                textStyle: Type.labelLarge
                color: Colors.m3onSurfaceVariant
                opacity: (1 - surface.wc) * surface.e * 0.9
                text: "Начните печатать, чтобы разблокировать"
            }

            Row {
                x: 32
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32 + (1 - surface.e) * -40
                spacing: 14
                opacity: surface.e
                visible: Config.o.lock.user

                Item {
                    id: avatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    height: 64

                    MaterialShape {
                        anchors.fill: parent
                        shape: root.failed ? "softBurst" : "cookie9Sided"
                        color: root.failed ? Colors.m3errorContainer : Colors.m3primaryContainer
                    }

                    MText {
                        anchors.centerIn: parent
                        visible: !face.visible
                        textStyle: Type.headlineMedium
                        font.variableAxes: ({ "wght": 700 })
                        color: root.failed ? Colors.m3onErrorContainer : Colors.m3onPrimaryContainer
                        text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                    }

                    FileView {
                        id: faceFile
                        path: Quickshell.env("HOME") + "/.face"
                        printErrors: false
                    }
                    Image {
                        id: face
                        anchors.centerIn: parent
                        width: 48; height: 48
                        source: faceFile.loaded ? "file://" + faceFile.path : ""
                        visible: status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(96, 96)
                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: faceMask
                        }
                    }
                    Rectangle { id: faceMask; width: 48; height: 48; radius: 24; visible: false; layer.enabled: true }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    MText {
                        textStyle: Type.titleMediumEmph
                        color: Colors.m3onSurface
                        text: Quickshell.env("USER") ?? ""
                    }
                    MText {
                        readonly property bool say: root.failed
                        textStyle: Type.labelMedium
                        color: root.failed ? Colors.m3error : Colors.m3onSurfaceVariant
                        text: root.failed ? "Неверный пароль" : ""
                        height: say ? implicitHeight : 0
                        opacity: say ? 1 : 0
                        Behavior on height { SpatialAnim { speed: "fast" } }
                        Behavior on opacity { EffectAnim {} }
                    }
                }
            }

            Row {
                id: powerRow
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 32
                spacing: 10
                opacity: surface.wc
                visible: opacity > 0.01
                enabled: root.awake
                layoutDirection: Qt.RightToLeft

                property string arming: ""
                Timer { id: disarm; interval: 3500; onTriggered: powerRow.arming = "" }

                Repeater {
                    model: [
                        { id: "poweroff", icon: "power_settings_new", ask: "Выключить?", cmd: ["systemctl", "poweroff"] },
                        { id: "reboot", icon: "restart_alt", ask: "Перезагрузить?", cmd: ["systemctl", "reboot"] },
                        { id: "suspend", icon: "bedtime", ask: "", cmd: ["systemctl", "suspend"] }
                    ]

                    Rectangle {
                        id: pb
                        required property var modelData
                        required property int index
                        readonly property bool armed: powerRow.arming === modelData.id
                        SpringValue { id: pbGrow; target: pb.armed ? 1 : 0; damping: 0.62; stiffness: 600 }

                        width: 56 + (askText.implicitWidth + 12) * Math.max(0, pbGrow.value)
                        height: 56
                        radius: pbLayer.pressed ? Shape.medium : height / 2
                        color: pb.armed ? Colors.m3errorContainer : Colors.m3surfaceContainerHigh
                        clip: true
                        transform: Translate { y: (1 - surface.wc) * (30 + pb.index * 12) }

                        Behavior on radius { SpatialAnim { speed: "fast" } }
                        Behavior on color { ColorAnim {} }

                        MIcon {
                            x: (56 - size) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            size: 24
                            icon: pb.modelData.icon
                            fill: pb.armed ? 1 : 0
                            color: pb.armed ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                        }
                        MText {
                            id: askText
                            x: 50
                            anchors.verticalCenter: parent.verticalCenter
                            textStyle: Type.labelLargeEmph
                            color: Colors.m3onErrorContainer
                            opacity: Math.max(0, Math.min(1, pbGrow.value * 1.6 - 0.5))
                            text: pb.modelData.ask
                        }
                        StateLayer {
                            id: pbLayer
                            radius: pb.radius
                            color: pb.armed ? Colors.m3onErrorContainer : Colors.m3onSurface
                            onClicked: {
                                root.wake();
                                if (pb.modelData.ask && !pb.armed) {
                                    powerRow.arming = pb.modelData.id;
                                    disarm.restart();
                                    return;
                                }
                                powerRow.arming = "";
                                root.power(pb.modelData.cmd);
                            }
                        }
                    }
                }
            }

            TextInput {
                id: input
                width: 0
                height: 0
                opacity: 0
                focus: true
                echoMode: TextInput.Password
                enabled: !root.checking && !root.unlocking
                onTextChanged: root.type(text)
                onAccepted: root.submit()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (root.buffer !== "") text = "";
                        else root.awake = false;
                        event.accepted = true;
                        return;
                    }
                    root.wake();
                }
                Connections {
                    target: root
                    function onBufferChanged() { if (root.buffer === "") input.text = "" }
                }
            }
        }
    }
}

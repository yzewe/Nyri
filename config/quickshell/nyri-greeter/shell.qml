import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool preview: Quickshell.env("NYRI_GREETER_PREVIEW") === "1"
    property string helper: Quickshell.env("NYRI_GREETD") || "/usr/local/bin/nyri-greetd"
    property string session: "niri"
    property string username: ""
    property bool niriOk: true
    property bool hyprOk: true
    property bool busy: false
    property bool accepted: false
    property string message: ""
    property bool failed: false
    property bool focusPassword: false
    property string now: Qt.formatTime(new Date(), "HH:mm")
    property var palette: ({})
    property string wallpaper: ""
    property bool ready: false

    function ink(name, fallback) {
        const value = palette ? palette[name] : "";
        return typeof value === "string" && value.charAt(0) === "#" ? value : fallback;
    }
    property color bg: ink("background", "#121413")
    property color fg: ink("on_surface", "#e4e3e0")
    property color muted: ink("on_surface_variant", "#c4c7c4")
    property color card: ink("surface_container", "#1e201f")
    property color field: ink("surface_container_high", "#282a29")
    property color accent: ink("primary", "#c4c7c4")
    property color onAccent: ink("on_primary", "#1a1c1b")
    property color chip: ink("primary_container", "#3a3d3b")
    property color onChip: ink("on_primary_container", "#e4e3e0")
    property color danger: ink("error", "#ffb4ab")

    function applyState(data) {
        if (!data) return;
        niriOk = data.niri !== false;
        hyprOk = data.hyprOk !== false && data.hyprland !== false;
        if (data.session === "niri" || data.session === "hyprland") session = data.session;
        if (session === "niri" && !niriOk && hyprOk) session = "hyprland";
        if (session === "hyprland" && !hyprOk && niriOk) session = "niri";
        const theme = data.theme;
        if (theme) {
            palette = theme.colors ?? {};
            wallpaper = theme.wallpaper ?? "";
        }
        if (data.user) username = data.user;
        focusPassword = username !== "";
        reveal.restart();
    }

    function remember() {
        saver.queue(JSON.stringify({ user: username, session: session }) + "\n");
    }

    function pick(next) {
        if (next === "niri" && !niriOk) return;
        if (next === "hyprland" && !hyprOk) return;
        session = next;
        failed = false;
        message = "";
        remember();
    }

    function submit(password) {
        if (busy || accepted) return;
        failed = false;
        if (!username.trim() || !password) {
            failed = true;
            message = "Введи имя и пароль";
            return;
        }
        remember();
        if (preview) {
            accepted = true;
            message = "Имя и сессия запомнены. Это проверка, вход не выполняется.";
            return;
        }
        busy = true;
        message = "";
        loginProc.password = password;
        loginProc.running = true;
    }

    onUsernameChanged: if (username) nameSave.restart()
    Timer { id: nameSave; interval: 280; onTriggered: root.remember() }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Qt.formatTime(new Date(), "HH:mm")
    }

    Process {
        id: loader
        command: [root.helper, "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applyState(JSON.parse(text)); } catch (e) { reveal.restart(); }
            }
        }
    }

    Timer {
        id: reveal
        interval: 32
        onTriggered: root.ready = true
    }

    Process {
        id: saver
        stdinEnabled: true
        property string pending: ""
        command: [root.helper, "save"]
        function queue(line) {
            pending = line;
            if (!running) running = true;
        }
        onStarted: {
            const line = pending;
            pending = "";
            write(line);
        }
        onExited: if (pending) running = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data.error) { root.failed = true; root.message = data.error; }
                } catch (e) {}
            }
        }
    }

    Process {
        id: loginProc
        stdinEnabled: true
        property string password: ""
        command: [root.helper, "login"]
        onStarted: write(JSON.stringify({ user: root.username.trim(), password: password, session: root.session }) + "\n")
        onExited: if (!root.accepted) root.busy = false
        stdout: SplitParser {
            onRead: line => {
                let data = null;
                try { data = JSON.parse(line); } catch (e) { return; }
                if (data.ok && data.authed) {
                    root.accepted = true;
                    root.busy = true;
                    return;
                }
                if (root.accepted) return;
                if (data.ok === false || data.error) {
                    root.busy = false;
                    root.failed = true;
                    root.message = data.error || "Вход не выполнен";
                }
            }
        }
    }

    Window {
            id: win
            visible: root.ready
            title: "Nyri"
            color: "#000000"
            flags: Qt.FramelessWindowHint
            visibility: Window.FullScreen
            width: Screen.width
            height: Screen.height

            SpringValue { id: enter; target: 0; damping: 0.7; stiffness: 240 }
            SpringValue { id: shake; target: 0; damping: 0.35; stiffness: 520 }
            onVisibleChanged: if (visible) { enter.value = 0; enter.velocity = 0; enter.target = 1; }
            Connections {
                target: root
                function onFocusPasswordChanged() {
                    if (root.focusPassword)
                        pass.field.forceActiveFocus();
                }
                function onFailedChanged() {
                    if (!root.failed) return;
                    shake.value = 16;
                    shake.velocity = 0;
                    shake.running = true;
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: root.preview ? Qt.quit() : pass.field.text = ""
            }
            Shortcut {
                sequence: "Return"
                context: Qt.ApplicationShortcut
                onActivated: root.submit(pass.field.text)
            }

            Image {
                anchors.fill: parent
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 320 } }
                source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
            Rectangle {
                anchors.fill: parent
                color: root.bg
                opacity: root.wallpaper !== "" ? 0.62 : 1
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: (1 - enter.value) * 36
                opacity: root.accepted ? 0 : enter.value
                Behavior on opacity { NumberAnimation { duration: 220 } }
                width: 420
                spacing: 22

                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.now
                        color: root.fg
                        font.family: "Rubik"
                        font.pixelSize: 72
                        font.weight: 650
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.preview ? "Nyri · проверка входа" : "Nyri"
                        color: root.muted
                        font.family: "Rubik"
                        font.pixelSize: 18
                    }
                }

                Rectangle {
                    width: parent.width
                    height: card.implicitHeight + 36
                    radius: 28
                    color: root.card
                    x: shake.value

                    Column {
                        id: card
                        x: 18
                        y: 18
                        width: parent.width - 36
                        spacing: 14

                        Item {
                            id: sessions
                            width: parent.width
                            height: 74
                            property bool placed: false
                            function arm() {
                                if (placed || width < 2 || !root.ready) return;
                                pillX.value = pillX.target;
                                pillX.velocity = 0;
                                pillX.running = false;
                                placed = true;
                            }
                            onWidthChanged: arm()
                            Connections {
                                target: root
                                function onReadyChanged() { sessions.arm(); }
                            }
                            SpringValue {
                                id: pillX
                                spring: sessions.placed
                                target: root.session === "hyprland" ? pill.width + 10 : 0
                                damping: 0.72
                                stiffness: 340
                            }
                            Rectangle {
                                id: pill
                                width: (sessions.width - 10) / 2
                                height: sessions.height
                                radius: 18
                                x: pillX.value
                                color: root.chip
                            }
                            Row {
                                width: parent.width
                                spacing: 10
                                SessionChoice {
                                    title: "Niri"
                                    caption: "Прокрутка"
                                    selected: root.session === "niri"
                                    available: root.niriOk
                                    onChosen: root.pick("niri")
                                }
                                SessionChoice {
                                    title: "Hyprland"
                                    caption: "Тайлинг"
                                    selected: root.session === "hyprland"
                                    available: root.hyprOk
                                    onChosen: root.pick("hyprland")
                                }
                            }
                        }

                        Field {
                            id: name
                            width: parent.width
                            placeholder: "Имя"
                            echo: false
                            text: root.username
                            onTextChanged: if (!field.activeFocus && field.text !== text) field.text = text
                            onEdited: text => root.username = text
                        }
                        Field {
                            id: pass
                            width: parent.width
                            placeholder: "Пароль"
                            echo: true
                        }

                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: 18
                            color: root.busy ? root.field : root.accent
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.busy ? "Вхожу…" : "Войти"
                                color: root.onAccent
                                font.family: "Rubik"
                                font.pixelSize: 16
                                font.weight: 650
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submit(pass.field.text)
                            }
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: root.message !== "" && !root.accepted
                            text: root.message
                            color: root.failed ? root.danger : root.muted
                            font.family: "Rubik"
                            font.pixelSize: 14
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 18
                opacity: root.accepted ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 280 } }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.accepted
                    }
                    Canvas {
                        anchors.fill: parent
                        property color ink: root.accent
                        onInkChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 4;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = root.accent;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2 - 4, 0, Math.PI * 1.35);
                            ctx.stroke();
                        }
                        onWidthChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Вхожу"
                    color: root.fg
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: 500
                }
            }

        }

    component SessionChoice: Item {
        id: choice
        property string title
        property string caption
        property bool selected
        property bool available: true
        signal chosen
        width: (parent.width - 10) / 2
        height: 74
        opacity: available ? 1 : 0.35
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: choice.title
                color: choice.selected ? root.onChip : root.fg
                font.family: "Rubik"
                font.pixelSize: 18
                font.weight: 650
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: choice.available ? choice.caption : "Не установлен"
                color: choice.selected ? root.onChip : root.muted
                font.family: "Rubik"
                font.pixelSize: 13
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: choice.available
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.chosen()
        }
    }

    component Field: Rectangle {
        id: box
        property string placeholder
        property bool echo: false
        property string text: ""
        property alias field: input
        signal edited(string text)
        height: 52
        radius: 16
        color: root.field
        clip: true
        border.width: input.activeFocus ? 2 : 0
        border.color: root.accent
        Behavior on border.width { NumberAnimation { duration: 140 } }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            color: root.fg
            font.family: "Rubik"
            font.pixelSize: box.echo ? 22 : 16
            font.weight: box.echo ? 400 : 450
            passwordCharacter: "•"
            echoMode: box.echo ? TextInput.Password : TextInput.Normal
            onTextChanged: box.edited(text)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 16
            visible: !input.text
            text: box.placeholder
            color: root.muted
            font.family: "Rubik"
            font.pixelSize: 16
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            propagateComposedEvents: true
            onPressed: mouse => { input.forceActiveFocus(); mouse.accepted = false; }
        }
    }
}

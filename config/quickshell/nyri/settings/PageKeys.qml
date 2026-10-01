import QtQuick
import QtQuick.Window
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

Column {
    id: page
    width: parent.width
    spacing: 16
    property var binds: []
    property string editing: ""
    property string leaving: ""
    property bool dropSent: false
    property string pending: ""
    property string message: ""
    property bool error: false
    property string mode: ""
    property var chosen: null
    readonly property string helper: Paths.bin + (Compositor.isHyprland ? "/nyri-hypr-binds" : "/nyri-binds")

    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1);
        const names = {};
        names[Qt.Key_Return] = "Return"; names[Qt.Key_Enter] = "Return";
        names[Qt.Key_Space] = "Space"; names[Qt.Key_Tab] = "Tab";
        names[Qt.Key_Backspace] = "BackSpace"; names[Qt.Key_Delete] = "Delete";
        names[Qt.Key_Escape] = "Escape"; names[Qt.Key_Print] = "Print";
        names[Qt.Key_Left] = "Left"; names[Qt.Key_Right] = "Right";
        names[Qt.Key_Up] = "Up"; names[Qt.Key_Down] = "Down";
        names[Qt.Key_Home] = "Home"; names[Qt.Key_End] = "End";
        names[Qt.Key_PageUp] = "Page_Up"; names[Qt.Key_PageDown] = "Page_Down";
        names[Qt.Key_Minus] = "Minus"; names[Qt.Key_Equal] = "Equal";
        names[Qt.Key_BracketLeft] = "BracketLeft"; names[Qt.Key_BracketRight] = "BracketRight";
        names[Qt.Key_Slash] = "Slash"; names[Qt.Key_Backslash] = "BackSlash";
        names[Qt.Key_QuoteLeft] = "Grave"; names[Qt.Key_Semicolon] = "Semicolon";
        names[Qt.Key_Apostrophe] = "Apostrophe"; names[Qt.Key_Comma] = "Comma";
        names[Qt.Key_Period] = "Period";
        return names[key] || "";
    }
    function chord(event) {
        if (event.key === Qt.Key_Escape && !(event.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier)))
            return "";
        const key = keyName(event.key);
        if (!key) return null;
        const modifiers = [];
        if (event.modifiers & Qt.MetaModifier) modifiers.push("Super");
        if (event.modifiers & Qt.ControlModifier) modifiers.push("Ctrl");
        if (event.modifiers & Qt.AltModifier) modifiers.push("Alt");
        if (event.modifiers & Qt.ShiftModifier) modifiers.push("Shift");
        if (!modifiers.length && key !== "Print" && key !== "Escape") {
            message = "Добавь Super, Ctrl, Alt или Shift";
            return null;
        }
        message = "";
        return modifiers.concat([key]).join("+");
    }
    function entryFor(bind) {
        const desktop = String(bind.desktop || "").toLowerCase().replace(/\.desktop$/, "");
        if (desktop) {
            const hit = Apps.all.find(e => String(e.id || "").toLowerCase().replace(/\.desktop$/, "") === desktop);
            if (hit) return hit;
        }
        const skip = { env: 1, nohup: 1, nice: 1, sh: 1, bash: 1, "gtk-launch": 1, gamescope: 1, "steam-run": 1, "appimage-run": 1 };
        const tokens = String(bind.command || bind.bin || "").split(/[\s;&|]+/).map(t => t.split("/").pop().toLowerCase());
        for (const bin of tokens) {
            if (!bin || skip[bin] || bin.includes("=")) continue;
            const hit = Apps.all.find(e => String((e.command && e.command[0]) || "").split("/").pop().toLowerCase() === bin);
            if (hit) return hit;
        }
        const title = String(bind.title || "").toLowerCase();
        if (bind.kind === "app" && title)
            return Apps.all.find(e => String(e.name || "").toLowerCase() === title) || null;
        return null;
    }
    property var deskFocus: []
    property var deskMove: []
    property var nudge: []
    function nudgeOf(bind) {
        const order = { "Окно влево": 0, "Окно вправо": 1, "Окно вверх": 2, "Окно вниз": 3 };
        const arrows = ["←", "→", "↑", "↓"];
        const at = order[String(bind.title || "")];
        if (at === undefined) return null;
        return { n: arrows[at], order: at };
    }
    function deskOf(bind) {
        const title = String(bind.title || "");
        const match = title.match(/рабочий стол\s+(\d+)\s*$/i);
        if (!match) return null;
        return { n: Number(match[1]), move: /перенест|перемест/i.test(title) };
    }
    function sectionOf(bind) {
        if (bind.kind === "shell" || bind.kind === "window" || bind.kind === "cmd" || bind.kind === "system")
            return bind.kind;
        return "app";
    }
    function glyphFor(bind) {
        const blob = [bind.command, bind.bin, bind.title].join(" ").toLowerCase();
        if (blob.includes("micmute") || blob.includes("микрофон")) return "mic_off";
        if (blob.includes("volumeup") || blob.includes("громче")) return "volume_up";
        if (blob.includes("volumedown") || blob.includes("тише")) return "volume_down";
        if (blob.includes("audio mute") || blob.includes("звук вкл") || (blob.includes("wpctl") && !blob.includes("source"))) return "volume_off";
        if (blob.includes("brightness") || blob.includes("ярче") || blob.includes("темнее"))
            return (blob.includes("decrement") || blob.includes("%-") || blob.includes("темнее")) ? "brightness_low" : "brightness_high";
        if (blob.includes("mpris next") || blob.includes("playerctl next") || blob.includes("следующий трек")) return "skip_next";
        if (blob.includes("mpris previous") || blob.includes("playerctl prev") || blob.includes("предыдущий трек")) return "skip_previous";
        if (blob.includes("playpause") || blob.includes("play-pause") || blob.includes("пауза")) return "play_pause";
        if (blob.includes("record")) return "videocam";
        if (blob.includes("ocr") || blob.includes("текст с экрана")) return "text_fields";
        if (blob.includes("region search") || blob.includes("поиск по области")) return "search";
        if (blob.includes("region edit") || blob.includes("swappy") || blob.includes("редактирован")) return "brush";
        if (blob.includes("region") || blob.includes("hyprshot") || blob.includes("снимок") || blob.includes("screenshot")) return "screenshot_region";
        if (blob.includes("crosshair") || blob.includes("прицел")) return "my_location";
        if (blob.includes("switcher") || blob.includes("переключить окно")) return "tab";
        if (blob.includes("launcher") || blob.includes("лаунчер")) return "apps";
        if (blob.includes("clipboard") || blob.includes("буфер")) return "content_paste";
        if (/(^|[\s/])lock([\s/]|$)/.test(blob) || blob.includes("блокиров")) return "lock";
        if (blob.includes("wallpaper") || blob.includes("обои")) return "wallpaper";
        if (blob.includes("settings") || blob.includes("настройк")) return "settings";
        if (blob.includes("panels") || blob.includes("автоскрытие")) return "toolbar";
        if (blob.includes("sidebar") || blob.includes("правая панель") || blob.includes("боковая панель")) return "dock_to_left";
        if (blob.includes("cheatsheet") || blob.includes("шпаргал")) return "help";
        if (blob.includes("picker") || blob.includes("пипет")) return "colorize";
        if (blob.includes("session") || blob.includes("питани") || blob.includes("завершить сеанс")) return "power_settings_new";
        if (blob.includes("browser") || blob.includes("браузер")) return "public";
        const title = String(bind.title || "");
        if (title.includes("Перетаскивать")) return "open_with";
        if (title.includes("размер")) return "crop";
        if (title.startsWith("Окно в")) return "open_with";
        if (title.startsWith("Закрыть")) return "close";
        if (title.includes("Плава")) return "layers";
        if (title.includes("Полный экран")) return "fullscreen";
        if (title.includes("Обзор")) return "grid_view";
        if (title.includes("Выключить экран")) return "bedtime";
        if (title.startsWith("Рабочий стол") || title.includes("рабочий стол")) return "desktop_windows";
        if (title.includes("онитор")) return "monitor";
        if (title.includes("колонк") || title.includes("ширин") || title.includes("высот")) return "view_column";
        if (title.includes("Переместить") || title.includes("Перенести")) return "open_with";
        if (title.includes("фокус") || title.startsWith("Окно ") || title.startsWith("К ") || title.startsWith("Колонка")) return "center_focus_strong";
        if (title.includes("расклад") || title.includes("Псевдо")) return "dashboard";
        if (title.includes("Перехват")) return "keyboard";
        if (title.includes("Выход")) return "logout";
        const section = sectionOf(bind);
        return { app: "apps", cmd: "terminal", shell: "dashboard_customize", window: "grid_view", system: "tune" }[section] || "apps";
    }
    function face(bind) {
        const entry = entryFor(bind);
        const section = sectionOf(bind);
        const source = (section === "app" || section === "cmd") && entry ? Apps.iconSourceFor(entry.id) : "";
        return {
            entry,
            source,
            glyph: glyphFor(bind),
            title: entry?.name || bind.title,
            subtitle: entry ? (entry.genericName || "") : (section === "app" || section === "cmd" ? (bind.command || bind.desktop || "") : "")
        };
    }
    ListModel { id: appModel }
    ListModel { id: cmdModel }
    ListModel { id: shellModel }
    ListModel { id: systemModel }
    ListModel { id: windowModel }
    ListModel {
        id: sectionModel
        ListElement { sid: "app"; label: "Приложения" }
        ListElement { sid: "cmd"; label: "Команды" }
        ListElement { sid: "shell"; label: "Nyri" }
        ListElement { sid: "system"; label: "Система" }
        ListElement { sid: "window"; label: "Окна" }
    }
    function modelFor(id) {
        return ({ app: appModel, cmd: cmdModel, shell: shellModel, system: systemModel, window: windowModel })[id];
    }
    function syncLists() {
        if (page.leaving) return;
        const q = search.text.trim().toLowerCase();
        const buckets = { app: [], cmd: [], shell: [], system: [], window: [] };
        const focuses = [];
        const moves = [];
        const nudges = [];
        for (let i = 0; i < page.binds.length; i++) {
            const b = page.binds[i];
            const section = page.sectionOf(b);
            if (!buckets[section]) continue;
            if (q) {
                const look = (b.key + " " + b.displayKey + " " + b.title + " " + (b.command || "") + " " + (b.desktop || "")).toLowerCase();
                if (!look.includes(q)) continue;
            }
            const desk = section === "window" ? page.deskOf(b) : null;
            const nudge = section === "window" ? page.nudgeOf(b) : null;
            const row = {
                bid: String(b.id ?? b.key ?? ""),
                key: String(b.key ?? ""),
                title: String(b.title ?? ""),
                displayKey: String(b.displayKey ?? ""),
                command: String(b.command || ""),
                desktop: String(b.desktop || ""),
                bin: String(b.bin || ""),
                kind: String(b.kind || section),
                removable: !!b.removable
            };
            if (desk) {
                row.n = desk.n;
                (desk.move ? moves : focuses).push(row);
                continue;
            }
            if (nudge) {
                row.n = nudge.n;
                row.order = nudge.order;
                nudges.push(row);
                continue;
            }
            buckets[section].push(row);
        }
        focuses.sort((a, b) => a.n - b.n);
        moves.sort((a, b) => a.n - b.n);
        nudges.sort((a, b) => a.order - b.order);
        page.deskFocus = focuses;
        page.deskMove = moves;
        page.nudge = nudges;
        const models = { app: appModel, cmd: cmdModel, shell: shellModel, system: systemModel, window: windowModel };
        for (const id in models) {
            models[id].clear();
            for (let i = 0; i < buckets[id].length; i++) models[id].append(buckets[id][i]);
        }
    }

    ShortcutInhibitor {
        window: page.Window.window
        enabled: page.mode === "edit" || newCapture.activeFocus || cmdCapture.activeFocus || editCapture.activeFocus
        onCancelled: { page.editing = ""; page.pending = ""; }
    }

    Process {
        id: load
        command: [page.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.binds = JSON.parse(text); page.syncLists(); }
                catch (e) { page.message = "Не удалось прочитать бинды"; page.error = true; }
            }
        }
    }
    Process {
        id: save
        property string response: ""
        command: []
        stdout: StdioCollector { onStreamFinished: save.response = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) save.response = text.trim() }
        onExited: code => {
            page.error = code !== 0;
            page.message = save.response || (code === 0 ? "Сохранено" : "Не удалось сохранить");
            const removed = save.command[1] === "remove" && code === 0;
            page.leaving = "";
            page.dropSent = false;
            if (code === 0) {
                page.editing = ""; page.pending = ""; page.chosen = null;
                page.mode = "";
                nameField.text = "";
                runField.text = "";
            }
            if (!removed) load.running = true;
        }
    }
    function commitNew() {
        if (!page.pending) { page.message = "Сначала нажми сочетание"; page.error = true; return; }
        save.response = "";
        if (page.mode === "cmd") {
            if (!nameField.text.trim() || !runField.text.trim()) {
                page.message = "Нужны название и команда";
                page.error = true;
                return;
            }
            save.command = [page.helper, "add-cmd", nameField.text.trim(), runField.text.trim(), page.pending];
        } else if (page.chosen) {
            save.command = [page.helper, "add", page.chosen.id, page.chosen.name, page.pending];
        } else return;
        save.running = true;
    }
    function openEdit(bind) {
        page.editing = bind.id ?? bind.key;
        page.pending = "";
        page.message = "";
        page.mode = "edit";
        page.mountSheet();
        Qt.callLater(() => editCapture.forceActiveFocus());
    }
    function dropLeave(id) {
        if (page.dropSent) return;
        page.dropSent = true;
        for (const model of [appModel, cmdModel, shellModel, systemModel, windowModel]) {
            for (let i = model.count - 1; i >= 0; i--) {
                const row = model.get(i);
                if ((row.bid || row.key) === id) model.remove(i);
            }
        }
        page.binds = page.binds.filter(b => String(b.id ?? b.key) !== id);
        save.response = "";
        save.command = [page.helper, "remove", id];
        save.running = true;
    }
    function withShift(chord) {
        const parts = String(chord || "").split("+").filter(part => part);
        if (parts.length < 2) return parts.join("+");
        if (parts.slice(0, -1).some(part => part.toLowerCase() === "shift")) return parts.join("+");
        parts.splice(parts.length - 1, 0, "Shift");
        return parts.join("+");
    }
    function editingBind() {
        return page.binds.find(item => (item.id ?? item.key) === page.editing) || null;
    }
    function commitEdit() {
        if (!page.pending || !page.editing) { page.message = "Сначала нажми сочетание"; page.error = true; return; }
        save.response = "";
        save.command = [page.helper, "set", page.editing, page.pending];
        save.running = true;
    }
    function closeOverlay() {
        if (!page.mode) return false;
        page.mode = "";
        page.editing = "";
        page.chosen = null;
        page.pending = "";
        return true;
    }
    function mountSheet() {
        const win = page.Window.window;
        if (win && sheet.parent !== win.contentItem)
            sheet.parent = win.contentItem;
    }
    Component.onCompleted: { load.running = true; Qt.callLater(mountSheet); }

    MText {
        width: parent.width
        wrapMode: Text.Wrap
        textStyle: Type.bodyMedium
        color: Colors.m3onSurfaceVariant
        text: "Приложение запускается по своему значку. Своя команда — это любое, что можно набрать в терминале. Новые сочетания остаются только на этом компьютере, занятая клавиша не заменяется."
    }
    SearchField {
        id: search
        width: parent.width
        icon: "search"
        placeholder: "Найти приложение, команду или клавишу"
        onTextChanged: page.syncLists()
    }
    Rectangle {
        width: parent.width
        height: 48
        radius: Shape.medium
        color: page.mode !== "" && page.mode !== "edit" ? Colors.m3secondaryContainer : Colors.m3surfaceContainer
        Behavior on color { ColorAnim {} }
        Rectangle {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 14
            color: Colors.m3primary
            MIcon { anchors.centerIn: parent; icon: "add"; size: 18; color: Colors.m3onPrimary }
        }
        MText {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            text: "Добавить сочетание"
            textStyle: Type.bodyLarge
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                page.mountSheet();
                page.editing = "";
                if (page.mode && page.mode !== "edit") { page.mode = ""; page.chosen = null; page.pending = ""; }
                else { page.mode = "pick"; page.chosen = null; page.pending = ""; }
            }
        }
    }
    MText {
        visible: !!page.message
        width: parent.width
        wrapMode: Text.Wrap
        textStyle: Type.bodyMedium
        color: page.error ? Colors.m3error : Colors.m3primary
        text: page.message
    }

    Item {
        id: sheet
        parent: page.Window.window ? page.Window.window.contentItem : null
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: page.mode !== "" || rise.value > 0.02
        z: 40

        SpringValue { id: rise; target: page.mode !== "" ? 1 : 0; damping: 0.62; stiffness: 380; epsilon: 0.01 }
        SpringValue { id: formIn; target: page.mode === "app" || page.mode === "cmd" ? 1 : 0; damping: 0.7; stiffness: 340 }
        SpringValue { id: swap; target: page.mode === "cmd" ? 1 : 0; damping: 0.74; stiffness: 260 }

        Rectangle {
            anchors.fill: parent
            color: Colors.m3scrim
            opacity: 0.5 * rise.value
            MouseArea { anchors.fill: parent; onClicked: { page.mode = ""; page.editing = ""; page.chosen = null; page.pending = ""; } }
        }

        Rectangle {
            id: card
            width: Math.min(480, parent.width - 64)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: (1 - rise.value) * 36
            height: Math.min(parent.height - 72, sheetBody.implicitHeight + 32)
            radius: Shape.extraLarge
            color: Colors.m3surfaceContainerHigh
            border.width: 1
            border.color: Colors.m3outlineVariant
            scale: 0.9 + 0.1 * rise.value
            opacity: Math.min(1, rise.value * 1.4)
            clip: true

            Column {
                id: sheetBody
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 8
                Item {
                    width: parent.width
                    height: 40
                    MText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.mode === "edit" ? "Изменить сочетание" : "Новое сочетание"
                        textStyle: Type.titleMedium
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        onClicked: { page.mode = ""; page.editing = ""; page.chosen = null; page.pending = ""; }
                    }
                }

                Column {
                    visible: page.mode === "edit"
                    width: parent.width
                    spacing: 8
                    MText {
                        width: parent.width
                        elide: Text.ElideRight
                        textStyle: Type.titleSmall
                        text: {
                            const bind = page.binds.find(item => (item.id ?? item.key) === page.editing);
                            return bind ? page.face(bind).title : "";
                        }
                    }
                    MText {
                        color: Colors.m3onSurfaceVariant
                        textStyle: Type.bodyMedium
                        text: {
                            const bind = page.binds.find(item => (item.id ?? item.key) === page.editing);
                            return bind ? ("Сейчас " + bind.displayKey) : "";
                        }
                    }
                    Item {
                        id: editCapture
                        width: parent.width
                        height: 48
                        focus: page.mode === "edit"
                        Keys.onPressed: event => {
                            event.accepted = true;
                            const next = page.chord(event);
                            if (next === "") { page.closeOverlay(); return; }
                            if (next) page.pending = next;
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.rightMargin: 132
                            radius: Shape.small
                            color: Colors.m3surfaceContainerHighest
                            MText { anchors.centerIn: parent; text: page.pending || "Нажми новое сочетание…"; textStyle: Type.bodyMedium }
                        }
                        FilterChip {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Сохранить"
                            onClicked: page.commitEdit()
                        }
                    }
                }

                Rectangle {
                    visible: page.mode !== "edit"
                    width: parent.width
                    height: 48
                    radius: Shape.medium
                    color: page.mode === "app" ? Colors.m3secondaryContainer : Colors.m3surfaceContainer
                    Behavior on color { ColorAnim {} }
                    MIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "apps"; size: 22; color: page.mode === "app" ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant }
                    MText { x: 48; anchors.verticalCenter: parent.verticalCenter; text: "Приложение"; textStyle: Type.bodyLarge }
                    MIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "expand_more"
                        size: 22
                        rotation: appOpen.value * 180
                        color: Colors.m3primary
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.mode = page.mode === "app" ? "pick" : "app"; page.chosen = null; page.pending = ""; } }
                }
                Item {
                    visible: page.mode !== "edit"
                    width: parent.width
                    clip: true
                    height: appInner.implicitHeight * appOpen.value
                    SpringValue { id: appOpen; target: page.mode === "app" ? 1 : 0; damping: 0.72; stiffness: 280 }
                    Column {
                        id: appInner
                        width: parent.width
                        spacing: 8
                        opacity: appOpen.value
                        y: (1 - appOpen.value) * -10
                        topPadding: 8

                SearchField {
                    id: appSearch
                    width: parent.width
                    icon: "apps"
                    placeholder: "Какое приложение открывать"
                }
                ListView {
                    id: hits
                    width: parent.width
                    height: count * 52 + Math.max(0, count - 1) * 4
                    spacing: 4
                    interactive: false
                    clip: true
                    model: Apps.search(appSearch.text).slice(0, 6)
                    add: Transition {
                        SequentialAnimation {
                            PauseAnimation { duration: ViewTransition.index * 26 }
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 240; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    addDisplaced: Transition {
                        NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 120 }
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: hits.width
                        height: 52
                        transformOrigin: Item.Top
                        radius: Shape.medium
                        color: page.chosen && page.chosen.id === modelData.id ? Colors.m3secondaryContainer : Colors.m3surfaceContainer
                        Behavior on color { ColorAnim {} }
                        AppIcon {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 28
                            source: Apps.iconSourceFor(modelData.id)
                        }
                        Column {
                            x: 60
                            width: parent.width - 76
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            MText { width: parent.width; text: modelData.name; elide: Text.ElideRight; textStyle: Type.bodyLarge }
                            MText {
                                width: parent.width
                                visible: !!modelData.genericName && modelData.genericName !== modelData.name
                                text: modelData.genericName || ""
                                elide: Text.ElideRight
                                textStyle: Type.bodySmall
                                color: Colors.m3onSurfaceVariant
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { page.chosen = { id: modelData.id, name: modelData.name }; page.pending = ""; newCapture.forceActiveFocus(); }
                        }
                    }
                }
                Item {
                    id: newCapture
                    visible: page.chosen !== null
                    width: parent.width
                    height: visible ? 48 : 0
                    focus: visible
                    Keys.onPressed: event => {
                        event.accepted = true;
                        const next = page.chord(event);
                        if (next === "") { page.closeOverlay(); return; }
                        if (next) page.pending = next;
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: 132
                        radius: Shape.small
                        color: Colors.m3surfaceContainerHighest
                        MText { anchors.centerIn: parent; text: page.pending || ("Клавиша для " + (page.chosen?.name || "")); textStyle: Type.bodyMedium }
                    }
                    FilterChip {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Сохранить"
                        onClicked: page.commitNew()
                    }
                }
                    }
                }

                Rectangle {
                    visible: page.mode !== "edit"
                    width: parent.width
                    height: 48
                    radius: Shape.medium
                    color: page.mode === "cmd" ? Colors.m3secondaryContainer : Colors.m3surfaceContainer
                    Behavior on color { ColorAnim {} }
                    MIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "terminal"; size: 22; color: page.mode === "cmd" ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant }
                    MText { x: 48; anchors.verticalCenter: parent.verticalCenter; text: "Команда"; textStyle: Type.bodyLarge }
                    MIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "expand_more"
                        size: 22
                        rotation: cmdOpen.value * 180
                        color: Colors.m3primary
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.mode = page.mode === "cmd" ? "pick" : "cmd"; page.chosen = null; page.pending = ""; } }
                }
                Item {
                    visible: page.mode !== "edit"
                    width: parent.width
                    clip: true
                    height: cmdInner.implicitHeight * cmdOpen.value
                    SpringValue { id: cmdOpen; target: page.mode === "cmd" ? 1 : 0; damping: 0.72; stiffness: 280 }
                    Column {
                        id: cmdInner
                        width: parent.width
                        spacing: 8
                        opacity: cmdOpen.value
                        y: (1 - cmdOpen.value) * -10
                        topPadding: 8
                        SearchField { id: nameField; width: parent.width; icon: "edit"; placeholder: "Как назвать" }
                        SearchField { id: runField; width: parent.width; icon: "terminal"; placeholder: "Команда, например kitty -e htop" }
                        Item {
                            id: cmdCapture
                            width: parent.width
                            height: 48
                            focus: page.mode === "cmd"
                            Keys.onPressed: event => {
                                event.accepted = true;
                                const next = page.chord(event);
                                if (next === "") { page.closeOverlay(); return; }
                                if (next) page.pending = next;
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.rightMargin: 132
                                radius: Shape.small
                                color: Colors.m3surfaceContainerHighest
                                MText { anchors.centerIn: parent; text: page.pending || "Нажми сочетание для команды"; textStyle: Type.bodyMedium }
                            }
                            FilterChip {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Сохранить"
                                onClicked: page.commitNew()
                            }
                        }
                    }
                }
            }
        }
    }

    component BindFlow: Flow {
        required property string section
        width: parent.width
        spacing: 6
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: page.modelFor(parent.section)
            Rectangle {
                id: row
                required property string bid
                required property string key
                required property string title
                required property string displayKey
                required property string command
                required property string desktop
                required property string bin
                required property string kind
                required property bool removable
                readonly property var bind: ({
                    id: row.bid, key: row.key, title: row.title, displayKey: row.displayKey,
                    command: row.command, desktop: row.desktop, bin: row.bin, kind: row.kind, removable: row.removable
                })
                readonly property var look: page.face(bind)
                width: Math.min(parent.width, line.implicitWidth + 12)
                height: 40
                radius: Shape.medium
                color: Colors.m3surfaceContainer
                transformOrigin: Item.Center

                ParallelAnimation {
                    id: byeAnim
                    NumberAnimation { target: row; property: "opacity"; to: 0; duration: 110; easing.type: Easing.OutCubic }
                    NumberAnimation { target: row; property: "scale"; to: 0.86; duration: 110; easing.type: Easing.OutCubic }
                    onFinished: {
                        const gone = row.bid;
                        Qt.callLater(() => page.dropLeave(gone));
                    }
                }

                Row {
                    id: line
                    x: 6
                    y: 4
                    height: 32
                    spacing: 8
                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 22
                        source: row.look.source
                        visible: !!row.look.source
                    }
                    Rectangle {
                        visible: !row.look.source
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        radius: 6
                        color: Colors.m3secondaryContainer
                        MIcon {
                            anchors.centerIn: parent
                            icon: row.look.glyph
                            size: 14
                            color: Colors.m3onSecondaryContainer
                        }
                    }
                    MText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 180)
                        text: row.look.title
                        elide: Text.ElideRight
                        textStyle: Type.bodyLarge
                    }
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "edit"
                        size: 32
                        onClicked: page.openEdit(row.bind)
                    }
                    IconButton {
                        visible: row.removable
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "delete"
                        size: 32
                        onClicked: {
                            if (page.leaving) return;
                            page.leaving = row.bid;
                            byeAnim.start();
                        }
                    }
                }
            }
        }
    }

    component DeskStrip: Column {
        required property string title
        required property string hint
        required property var rows
        width: parent.width
        spacing: 6
        visible: rows.length > 0
        MText { text: title; textStyle: Type.titleSmall; color: Colors.m3onSurfaceVariant }
        MText { text: hint; textStyle: Type.bodySmall; color: Colors.m3onSurfaceVariant }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: rows
                Rectangle {
                    required property var modelData
                    width: 44
                    height: 40
                    radius: Shape.medium
                    color: Colors.m3surfaceContainer
                    MText {
                        anchors.centerIn: parent
                        text: modelData.n
                        textStyle: Type.titleMedium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.openEdit({
                            id: modelData.bid, key: modelData.key, title: modelData.title,
                            displayKey: modelData.displayKey, command: modelData.command,
                            desktop: modelData.desktop, bin: modelData.bin, kind: modelData.kind,
                            removable: modelData.removable
                        })
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10
        DeskStrip {
            title: "Рабочие столы"
            hint: "Нажми номер, чтобы сменить клавишу. Перенос окна на этот стол ставится сам: то же сочетание и Shift."
            rows: page.deskFocus
        }
        DeskStrip {
            title: "Сдвинуть окно"
            hint: "Стрелки с Super. Это не перенос на другой стол."
            rows: page.nudge
        }
        Repeater {
            model: sectionModel
            Column {
                required property string sid
                required property string label
                width: parent.width
                spacing: 4
                visible: page.modelFor(sid).count > 0
                MText { text: label; textStyle: Type.titleSmall; color: Colors.m3onSurfaceVariant }
                BindFlow { section: sid }
            }
        }
    }
}

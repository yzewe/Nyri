import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets

Surface {
    id: root

    name: "session"
    scrimOpacity: 0.55

    property int current: 0

    readonly property var actions: [
        { key: "L", label: "Блокировка",  icon: "lock",               shape: "cookie9Sided", run: () => Lock.lock() },
        { key: "S", label: "Сон",         icon: "bedtime",            shape: "clover4Leaf",  run: () => { Lock.lock(); system(["systemctl", "suspend"]); } },
        { key: "E", label: "Выйти",       icon: "logout",             shape: "sunny",        run: () => system(Compositor.isHyprland ? ["hyprctl", "dispatch", "exit"] : ["niri", "msg", "action", "quit", "--skip-confirmation"], true) },
        { key: "R", label: "Перезагрузка", icon: "restart_alt",       shape: "cookie12Sided", run: () => system(["systemctl", "reboot"], true) },
        { key: "P", label: "Выключение",  icon: "power_settings_new", shape: "softBurst",    run: () => system(["systemctl", "poweroff"], true) }
    ]

    function system(cmd, keep) {
        if (Panels.nested)
            console.log("nested: skipped", cmd.join(" "));
        else if (keep)
            Quickshell.execDetached(["sh", "-c", "\"$0\" save --quiet; exec \"$@\"", Paths.bin + "/nyri-session", ...cmd]);
        else
            Quickshell.execDetached(cmd);
    }

    function activate(i) {
        Panels.close();
        actions[i].run();
    }

    property int holding: -1
    property real hold: 0
    property bool nudge: false
    function startHold(i) {
        if (holding === i) return;
        current = i;
        holding = i;
        letGo.stop();
        grip.restart();
    }
    function stopHold() {
        if (holding < 0) return;
        grip.stop();
        if (hold < 1) {
            nudge = true;
            nudgeOff.restart();
        }
        letGo.restart();
    }
    NumberAnimation {
        id: grip
        target: root
        property: "hold"
        to: 1
        duration: 2000 * (1 - root.hold)
        onFinished: { const i = root.holding; root.holding = -1; root.hold = 0; root.activate(i); }
    }
    SequentialAnimation {
        id: letGo
        NumberAnimation { target: root; property: "hold"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        ScriptAction { script: root.holding = -1 }
    }
    Timer { id: nudgeOff; interval: 1600; onTriggered: root.nudge = false }

    property var profiles: []
    Process {
        id: listJob
        command: [Paths.bin + "/nyri-session", "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.profiles = JSON.parse(text); } catch (e) { root.profiles = []; } } }
    }
    Process {
        id: changeJob
        onExited: listJob.running = true
    }
    function saveAs(name) {
        changeJob.command = [Paths.bin + "/nyri-session", "save", name.trim() || "Прошлый раз"];
        changeJob.running = true;
    }
    function forget(name) {
        changeJob.command = [Paths.bin + "/nyri-session", "delete", name];
        changeJob.running = true;
    }
    function plural(n, one, few, many) {
        const m10 = n % 10, m100 = n % 100;
        return n + " " + (m10 === 1 && m100 !== 11 ? one : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? few : many);
    }
    function when(sec) {
        const d = new Date(sec * 1000), now = new Date();
        const day = d.toDateString() === now.toDateString() ? "сегодня" : Qt.formatDate(d, "d MMM");
        return day + " в " + Qt.formatTime(d, "HH:mm");
    }
    property bool naming: false

    onOpenChanged: {
        if (!open) return;
        current = 0;
        holding = -1;
        hold = 0;
        naming = false;
        listJob.running = true;
        keys.forceActiveFocus();
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.isAutoRepeat) { event.accepted = true; return; }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.current = (root.current + 1) % root.actions.length;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                root.current = (root.current + root.actions.length - 1) % root.actions.length;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.startHold(root.current);
            } else {
                const i = root.actions.findIndex(a => a.key === event.text.toUpperCase());
                if (i < 0) return;
                root.startHold(i);
            }
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if (event.isAutoRepeat) return;
            root.stopHold();
            event.accepted = true;
        }
    }

    Row {
        id: acts
        anchors.centerIn: parent
        spacing: 28
        opacity: root.fade

        Repeater {
            model: root.actions

            Column {
                id: item

                required property var modelData
                required property int index
                readonly property bool selected: root.current === index
                readonly property real h: root.holding === index ? root.hold : 0

                spacing: 14

                Item {
                    id: bubble
                    width: 112
                    height: 112

                    property real pop: 0
                    scale: pop * (1 + 0.1 * item.h)
                    rotation: (1 - pop) * -120

                    Connections {
                        target: root
                        function onOpenChanged() { if (root.open) popIn.restart() }
                    }
                    SequentialAnimation {
                        id: popIn
                        ScriptAction { script: bubble.pop = 0 }
                        PauseAnimation { duration: 60 + item.index * 55 }
                        SpatialAnim { target: bubble; property: "pop"; from: 0; to: 1; speed: "fast" }
                    }

                    CircularProgress {
                        anchors.fill: parent
                        anchors.margins: -12
                        visible: item.h > 0
                        stroke: 6
                        animated: false
                        value: item.h
                        trackColor: "transparent"
                    }

                    MaterialShape {
                        anchors.fill: parent
                        shape: item.selected ? item.modelData.shape : "circle"
                        color: item.selected ? Colors.m3primary : Colors.m3secondaryContainer
                        rotation: (item.selected ? 30 : 0) + item.h * 90

                        Behavior on rotation { enabled: item.h === 0; SpatialAnim { speed: "slow" } }
                    }

                    MIcon {
                        anchors.centerIn: parent
                        icon: item.modelData.icon
                        size: 40
                        fill: item.selected ? 1 : 0
                        color: item.selected ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (root.holding < 0) root.current = item.index
                        onPressed: root.startHold(item.index)
                        onReleased: root.stopHold()
                        onCanceled: root.stopHold()
                    }
                }

                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textStyle: item.selected ? Type.titleMediumEmph : Type.titleMedium
                    color: Colors.m3onSurface
                    text: item.modelData.label
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 28
                    height: 28
                    radius: 8
                    color: Colors.m3surfaceContainerHigh
                    opacity: item.selected ? 1 : 0.6
                    Behavior on opacity { EffectAnim {} }

                    MText {
                        anchors.centerIn: parent
                        textStyle: Type.labelLargeEmph
                        color: Colors.m3onSurfaceVariant
                        text: item.modelData.key
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: acts.top
        anchors.bottomMargin: 28
        width: nudgeText.implicitWidth + 32
        height: 36
        radius: 18
        color: Colors.m3inverseSurface
        SpringValue { id: nudgeIn; target: root.nudge ? 1 : 0; damping: 0.6; stiffness: 520 }
        opacity: Math.max(0, Math.min(1, nudgeIn.value))
        scale: 0.85 + 0.15 * nudgeIn.value
        visible: opacity > 0.01
        MText { id: nudgeText; anchors.centerIn: parent; textStyle: Type.labelLarge; color: Colors.m3inverseOnSurface; text: "Зажмите на 2 секунды" }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: acts.bottom
        anchors.topMargin: 56
        spacing: 12
        opacity: root.fade

        Repeater {
            model: root.profiles
            Rectangle {
                id: card
                required property var modelData
                required property int index
                width: cardRow.implicitWidth + 40 + (cardHover.hovered ? 36 : 0)
                height: 60
                radius: cardLayer.pressed ? Shape.medium : height / 2
                color: modelData.last ? Colors.m3primaryContainer : Colors.m3secondaryContainer
                readonly property color ink: modelData.last ? Colors.m3onPrimaryContainer : Colors.m3onSecondaryContainer
                Behavior on radius { SpatialAnim { speed: "fast" } }
                Behavior on width { SpatialAnim { speed: "fast" } }
                SpringValue { id: cardIn; target: root.open ? 1 : 0; damping: 0.6; stiffness: 420 - Math.min(5, card.index) * 50 }
                scale: 0.8 + 0.2 * Math.max(0, cardIn.value)
                HoverHandler { id: cardHover }
                StateLayer {
                    id: cardLayer
                    radius: card.radius
                    color: card.ink
                    onClicked: { Panels.close(); Quickshell.execDetached([Paths.bin + "/nyri-session", "restore", card.modelData.name]); }
                }
                Row {
                    id: cardRow
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: card.modelData.last ? "history" : "restore_page"; size: 22; fill: 1; color: card.ink }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        MText { textStyle: Type.labelLargeEmph; color: card.ink; text: card.modelData.name }
                        MText { textStyle: Type.labelSmall; color: card.ink; opacity: 0.8; text: root.plural(card.modelData.count, "окно", "окна", "окон") + " · " + root.when(card.modelData.saved) }
                    }
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cardHover.hovered
                    size: 32
                    iconSize: 18
                    icon: "close"
                    onClicked: root.forget(card.modelData.name)
                }
            }
        }

        Rectangle {
            id: add
            width: root.naming ? 280 : addRow.implicitWidth + 40
            height: 60
            radius: height / 2
            color: Colors.m3surfaceContainerHigh
            Behavior on width { SpatialAnim { speed: "fast" } }
            StateLayer {
                visible: !root.naming
                radius: add.radius
                onClicked: { root.naming = true; nameInput.text = ""; nameInput.forceActiveFocus(); }
            }
            Row {
                id: addRow
                visible: !root.naming
                anchors.centerIn: parent
                spacing: 10
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "add"; size: 22; color: Colors.m3onSurface }
                MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLargeEmph; text: "Сохранить окна" }
            }
            TextInput {
                id: nameInput
                visible: root.naming
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: okBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.family: Type.family
                font.pixelSize: 16
                color: Colors.m3onSurface
                selectionColor: Colors.m3primary
                clip: true
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !parent.text
                    font: parent.font
                    color: Colors.m3onSurfaceVariant
                    text: "Название"
                }
                Keys.onReturnPressed: { root.saveAs(text); root.naming = false; keys.forceActiveFocus(); }
                Keys.onEnterPressed: { root.saveAs(text); root.naming = false; keys.forceActiveFocus(); }
                Keys.onEscapePressed: { root.naming = false; keys.forceActiveFocus(); }
            }
            IconButton {
                id: okBtn
                visible: root.naming
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                size: 40
                iconSize: 20
                style: "filled"
                icon: "check"
                onClicked: { root.saveAs(nameInput.text); root.naming = false; keys.forceActiveFocus(); }
            }
        }
    }
}

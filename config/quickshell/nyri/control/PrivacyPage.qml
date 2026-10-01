import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets

Column {
    id: root

    signal back
    spacing: 16

    PageHeader {
        title: "Приватность"
        hasSwitch: true
        checked: Config.o.privacy.mode
        onBack: root.back()
        onToggled: c => Config.o.privacy.mode = c
    }

    MText {
        width: root.width
        wrapMode: Text.Wrap
        textStyle: Type.bodyMedium
        color: Colors.m3onSurfaceVariant
        text: "Режим приватности скрывает текст уведомлений и убирает личное из трансляции экрана."
    }

    component Sensor: Rectangle {
        id: sensor
        property string icon
        property string offIcon
        property string label
        property bool on: false
        property bool blocked: false
        property string apps: ""
        property string action: ""
        property string freeText: "Свободен"
        property string offText: "Выключен"
        signal act
        width: (root.width - 16) / 3
        height: 148
        radius: Shape.largeIncreased
        property bool accent: false
        color: on ? Colors.m3errorContainer : accent ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHigh
        Behavior on color { ColorAnim {} }
        scale: press.value
        SpringValue { id: press; target: layer.pressed ? 0.95 : 1; damping: 0.5; stiffness: 800; epsilon: 0.001 }

        StateLayer {
            id: layer
            radius: sensor.radius
            color: sensor.on ? Colors.m3onErrorContainer : Colors.m3onSurface
            enabled: sensor.action !== ""
            onClicked: sensor.act()
        }
        Column {
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 6
            MaterialShape {
                width: 44; height: 44
                shape: sensor.on ? "softBurst" : sensor.blocked ? "clover4Leaf" : "cookie9Sided"
                color: sensor.on ? Colors.m3error : sensor.accent ? Colors.m3primary : Colors.m3surfaceContainerHighest
                MIcon {
                    anchors.centerIn: parent
                    icon: sensor.blocked ? sensor.offIcon : sensor.icon
                    size: 22; fill: 1
                    color: sensor.on ? Colors.m3onError : sensor.accent ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                }
            }
            MText { textStyle: Type.labelLargeEmph; color: sensor.on ? Colors.m3onErrorContainer : Colors.m3onSurface; text: sensor.label }
            MText {
                width: parent.width
                elide: Text.ElideRight
                textStyle: Type.labelMedium
                color: sensor.on ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                text: sensor.on ? sensor.apps : sensor.blocked ? sensor.offText : sensor.freeText
            }
            MText {
                visible: sensor.action !== ""
                width: parent.width
                elide: Text.ElideRight
                textStyle: Type.labelLargeEmph
                color: sensor.on ? Colors.m3onErrorContainer : Colors.m3primary
                text: sensor.action
            }
        }
    }

    Row {
        spacing: 8
        Sensor {
            icon: "mic"; offIcon: "mic_off"; label: "Микрофон"
            on: Privacy.micOn && !Privacy.micBlocked
            blocked: Privacy.micBlocked
            accent: !Privacy.micBlocked
            apps: Privacy.micApps.join(", ")
            action: Privacy.micBlocked ? "Включить" : "Отключить"
            onAct: Privacy.setMicBlocked(!Privacy.micBlocked)
        }
        Sensor {
            icon: "videocam"; offIcon: "videocam_off"; label: "Камера"; freeText: "Свободна"; offText: "Выключена"
            on: Privacy.camOn
            apps: Privacy.camApps.join(", ")
        }
        Sensor {
            icon: "screen_share"; offIcon: "stop_screen_share"; label: "Экран"
            on: Privacy.casting
            apps: Privacy.castApps.join(", ") || "Трансляция"
            action: Privacy.casting ? "Прекратить" : ""
            onAct: Privacy.stopCasts()
        }
    }

    ListGroup {
        width: root.width
        SettingRow {
            icon: "cast"
            title: "Сам при трансляции"
            subtitle: "Включать режим приватности, пока экран транслируется"
            MSwitch { checked: Config.o.privacy.autoOnCast; onToggled: c => Config.o.privacy.autoOnCast = c }
        }
        SettingRow {
            icon: "do_not_disturb_on"
            title: "Без всплывающих"
            subtitle: "В режиме приватности уведомления не всплывают совсем"
            MSwitch { checked: Config.o.privacy.dndWhenActive; onToggled: c => Config.o.privacy.dndWhenActive = c }
        }
    }

    Item {
        width: root.width
        height: 36
        MText { anchors.verticalCenter: parent.verticalCenter; x: 4; textStyle: Type.titleSmall; text: "Журнал" }
        Chip {
            anchors.right: parent.right
            visible: Privacy.history.length > 0
            onClicked: Privacy.clearHistory()
            MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; color: Colors.m3primary; text: "Очистить" }
        }
    }

    readonly property var log: Privacy.running.concat(Privacy.history).slice(0, 30)
    function when(ms) {
        const d = new Date(ms), today = new Date();
        return d.toDateString() === today.toDateString() ? Qt.formatTime(d, "HH:mm") : Qt.formatDateTime(d, "d MMM, HH:mm");
    }
    function lasted(e) {
        const s = Math.round(((e.end || Date.now()) - e.start) / 1000);
        return s < 60 ? s + " с" : s < 3600 ? Math.round(s / 60) + " мин" : Math.floor(s / 3600) + " ч " + Math.round(s % 3600 / 60) + " мин";
    }

    ListGroup {
        width: root.width
        visible: root.log.length > 0
        Repeater {
            model: root.log
            SettingRow {
                required property var modelData
                color: modelData.end ? Colors.m3surfaceContainerHigh : Colors.m3errorContainer
                icon: modelData.kind === "mic" ? "mic" : modelData.kind === "camera" ? "videocam" : "screen_share"
                title: modelData.app
                subtitle: (modelData.kind === "mic" ? "Микрофон" : modelData.kind === "camera" ? "Камера" : "Экран")
                          + " · " + root.when(modelData.start) + (modelData.end ? " · " + root.lasted(modelData) : " · сейчас")
            }
        }
    }
    MText {
        visible: root.log.length === 0
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        textStyle: Type.bodyMedium
        color: Colors.m3onSurfaceVariant
        text: "Пока никто ничего не включал"
    }
}

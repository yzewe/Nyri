import QtQuick
import Quickshell.Widgets
import Quickshell.Io
import Quickshell
import qs.theme
import qs.services
import qs.widgets

Column {
    id: root
    readonly property var cardKinds: [
        { id: "media", label: "Плеер" }, { id: "timer", label: "Таймер" },
        { id: "stopwatch", label: "Секундомер" }, { id: "phone", label: "Телефон" },
        { id: "bt", label: "Bluetooth" }, { id: "vpn", label: "VPN" },
        { id: "record", label: "Запись экрана" }, { id: "cast", label: "Трансляция" },
        { id: "camera", label: "Камера" }, { id: "mic", label: "Микрофон" },
        { id: "download", label: "Загрузка" }, { id: "downloaded", label: "Загружено" },
        { id: "job", label: "Файловые операции" }, { id: "copy", label: "Копирование" },
        { id: "done", label: "Завершено" }, { id: "update", label: "Обновление" }
    ]
    spacing: 24

    ListGroup {
        width: parent.width

        SettingRow {
            icon: "do_not_disturb_on"
            title: "Не беспокоить"
            subtitle: "Всплывают только срочные"
            MSwitch { checked: Notifs.dnd; onToggled: c => Notifs.dnd = c }
        }

        SettingRow {
            icon: "timer"
            title: "Сколько висит уведомление"
            subtitle: Config.o.notifications.timeout + " с · срочные висят, пока не закроешь"

            below: MSlider {
                width: parent.width
                value: (Config.o.notifications.timeout - 3) / 12
                onMoved: v => Config.o.notifications.timeout = Math.round(3 + v * 12)
            }
        }

        SettingRow {
            icon: "picture_in_picture"
            title: "Где всплывают"
            choice: Config.o.notifications.position
            choices: [{ value: "left", label: "Слева" }, { value: "center", label: "По центру" }, { value: "right", label: "Справа" }]
            onChosen: v => Config.o.notifications.position = v
        }

        SettingRow {
            icon: "delete_sweep"
            title: "Очистить историю"
            subtitle: Notifs.count > 0 ? Notifs.count + " в центре управления" : "История пуста"
            clickable: Notifs.count > 0
            onClicked: Notifs.clearAll()
        }
    }

    ListGroup {
        width: parent.width
        title: "Шторка и подсказки"

        SettingRow {
            icon: "grid_view"
            title: "Плитки в шторке"
            subtitle: "Нажми, чтобы убрать или вернуть"
            below: Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        { id: "wifi", label: "Wi-Fi" }, { id: "bt", label: "Bluetooth" }, { id: "dnd", label: "Не беспокоить" },
                        { id: "power", label: "Питание" }, { id: "caffeine", label: "Не засыпать" }, { id: "night", label: "Ночной свет" },
                        { id: "mic", label: "Микрофон" }, { id: "privacy", label: "Приватность" },
                        { id: "dark", label: "Тёмная тема" }, { id: "capture", label: "Захват экрана" }
                    ]
                    FilterChip {
                        required property var modelData
                        readonly property var hidden: Config.list(Config.o.control.hidden)
                        text: modelData.label
                        picked: hidden.indexOf(modelData.id) < 0
                        onClicked: Config.o.control.hidden = picked ? hidden.concat([modelData.id]) : hidden.filter(h => h !== modelData.id)
                    }
                }
            }
        }

        SettingRow {
            icon: "view_carousel"
            title: "Карточки в шторке"
            subtitle: "Выбери, какие карточки показывать"
            below: Column {
                width: parent.width
                spacing: 8
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.cardKinds
                        FilterChip {
                            required property var modelData
                            readonly property var hidden: Config.list(Config.o.control.hiddenCards)
                            text: modelData.label
                            picked: hidden.indexOf(modelData.id) < 0
                            onClicked: Config.o.control.hiddenCards = picked ? hidden.concat([modelData.id]) : hidden.filter(h => h !== modelData.id)
                        }
                    }
                }
                FilterChip {
                    text: "Убрать все карточки"
                    picked: false
                    onClicked: Config.o.control.hiddenCards = root.cardKinds.map(c => c.id)
                }
            }
        }

        SettingRow {
            icon: "tips_and_updates"
            title: "Подсказки"
            subtitle: "Где показывать громкость, яркость, язык и остальные"
            choice: {
                const p = Config.o.osd.position;
                if (p === "top" || p === "bottom" || p === "center") return p;
                if (p === "opposite") return Panels.barBottom ? "top" : "bottom";
                return Panels.barBottom ? "bottom" : "top";
            }
            choices: [{ value: "top", label: "Вверху" }, { value: "bottom", label: "Внизу" }, { value: "center", label: "По центру" }]
            onChosen: v => Config.o.osd.position = v
        }
    }
}

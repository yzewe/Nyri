import QtQuick
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets

Column {
    id: page

    spacing: 24

    function mins(v) {
        return v === 0 ? "никогда" : v + " мин";
    }

    component MinuteRow: SettingRow {
        id: row
        property string key
        property int max: 60
        subtitle: page.mins(Config.o.idle[key])

        below: MSlider {
            width: parent.width
            value: Config.o.idle[row.key] / row.max
            onMoved: v => Config.o.idle[row.key] = Math.round(v * row.max)
        }
    }

    ListGroup {
        width: parent.width
        title: "Профиль"

        SettingRow {
            icon: "speed"
            title: "Режим питания"

            choice: Power.profile
            choices: [
                    { value: PowerProfile.PowerSaver, label: "Экономия", icon: "eco" },
                    { value: PowerProfile.Balanced, label: "Баланс", icon: "balance" },
                    { value: PowerProfile.Performance, label: "Мощность", icon: "bolt" }
                ]
            onChosen: v => PowerProfiles.profile = v
        }
    }

    ListGroup {
        width: parent.width
        title: "Когда не пользуешься"

        MinuteRow { icon: "monitor"; title: "Гасить экран от сети"; key: "screenAc"; max: 30 }
        MinuteRow { icon: "battery_4_bar"; title: "Гасить экран от батареи"; key: "screenBattery"; max: 30 }
        MinuteRow { icon: "lock_clock"; title: "Блокировать"; key: "lock" }
        MinuteRow { icon: "bedtime"; title: "Засыпать от сети"; key: "suspendAc" }
        MinuteRow { icon: "battery_saver"; title: "Засыпать от батареи"; key: "suspendBattery" }

        SettingRow {
            icon: "login"
            title: "Блокировать при входе"
            subtitle: "Экран блокировки сразу после логина"
            MSwitch { checked: Config.o.idle.lockOnLogin; onToggled: c => Config.o.idle.lockOnLogin = c }
        }
    }
}

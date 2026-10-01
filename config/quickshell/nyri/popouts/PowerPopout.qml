import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets

Surface {
    id: root

    name: "power"
    keyboard: false

    property string page: "battery"
    readonly property var dev: UPower.displayDevice
    readonly property real level: {
        const p = dev?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.PendingCharge

    property var today: ({})
    property var week: []
    property var weekLabels: []
    property var weekDays: []
    property int day: 6
    property string openApp: ""

    function refreshUsage() {
        const vals = [], labels = [], days = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date(Date.now() - i * 86400000);
            const t = ScreenTime.dayTotals(d);
            days.push(t);
            vals.push(ScreenTime.total(t));
            labels.push(Qt.locale().toString(d, "ddd"));
        }
        weekDays = days;
        week = vals;
        weekLabels = labels;
        today = days[day] ?? {};
    }
    onDayChanged: { today = weekDays[day] ?? {}; openApp = ""; }
    function appWeek(app) { return weekDays.map(t => t[app] ?? 0); }
    function dayTitle() {
        if (day === 6) return "Сегодня за экраном";
        if (day === 5) return "Вчера за экраном";
        const d = new Date(Date.now() - (6 - day) * 86400000);
        const s = d.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function openAppNow(app) {
        const w = Object.values(Compositor.windows).find(w => w.app_id === app);
        Panels.close();
        if (w) Compositor.action("focus-window", "--id", String(w.id));
        else {
            const e = DesktopEntries.heuristicLookup(app);
            if (e) Apps.launch(e);
        }
    }

    readonly property var topApps: Object.entries(today)
        .sort((a, b) => b[1] - a[1]).slice(0, 8)

    onOpenChanged: {
        if (open) {
            page = Panels.tab || "battery";
            day = 6;
            openApp = "";
            BatteryInfo.refresh();
            refreshUsage();
        }
    }

    Timer {
        running: root.open && root.page === "usage"
        interval: 60000
        repeat: true
        onTriggered: root.refreshUsage()
    }

    component Stat: Rectangle {
        id: stat
        property string icon
        property string label
        property string value
        width: (440 - 40 - 16) / 3
        height: 84
        radius: Shape.largeIncreased
        color: Colors.m3surfaceContainerHigh

        Column {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            MIcon {
                icon: stat.icon
                size: 20
                fill: 1
                color: Colors.m3primary
            }

            RollingText {
                textStyle: Type.titleMediumEmph
                text: stat.value
            }

            MText {
                textStyle: Type.labelMedium
                color: Colors.m3onSurfaceVariant
                text: stat.label
            }
        }
    }

    function duration(sec) {
        const total = Math.round(sec / 60), h = Math.floor(total / 60), m = total % 60;
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }

    Popout {
        progress: root.progress
        toX: parent.width - toW - 12
        toW: 440
        toH: col.implicitHeight + 40
        defaultFromX: parent.width - 12 - 60
        defaultFromW: 60

        Behavior on toH { SpatialAnim {} }

        Column {
            id: col
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 16

            SegmentedButtons {
                width: parent.width
                value: root.page
                options: [
                    { value: "battery", label: "Батарея", icon: "battery_full" },
                    { value: "usage", label: "Экранное время", icon: "hourglass_top" }
                ]
                onSelected: v => { root.page = v; if (v === "usage") root.refreshUsage(); }
            }

            Column {
                width: parent.width
                spacing: 16
                visible: root.page === "battery"

                Row {
                    spacing: 18

                    BatteryPill {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 40
                        level: root.level
                        charging: root.charging
                        textSize: 38
                        textWeight: 700
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        FlowText {
                            textStyle: Type.titleMediumEmph
                            text: root.charging ? "Заряжается"
                                : root.dev?.state === UPowerDeviceState.FullyCharged ? "Заряжена" : "От батареи"
                        }

                        FlowText {
                            textStyle: Type.bodyMedium
                            color: Colors.m3onSurfaceVariant
                            text: root.charging && root.dev?.timeToFull > 0 ? "до полной " + root.duration(root.dev.timeToFull)
                                : root.dev?.timeToEmpty > 0 ? "хватит на " + root.duration(root.dev.timeToEmpty) : ""
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 196
                    radius: Shape.largeIncreased
                    color: Colors.m3surfaceContainerHigh

                    MText {
                        x: 16
                        y: 14
                        textStyle: Type.titleSmall
                        text: "Последние 24 часа"
                    }

                    BatteryChart {
                        x: 16
                        y: 44
                        width: parent.width - 32
                        height: parent.height - 56
                        points: BatteryInfo.history
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Stat { icon: "electric_bolt"; label: "Расход"; value: BatteryInfo.rate > 0 ? BatteryInfo.rate.toFixed(1) + " Вт" : "—" }
                    Stat { icon: "health_and_safety"; label: "Здоровье"; value: BatteryInfo.health > 0 ? Math.round(BatteryInfo.health) + "%" : "—" }
                    Stat { icon: "autorenew"; label: "Циклы"; value: BatteryInfo.cycles >= 0 ? String(BatteryInfo.cycles) : "—" }
                }

                SegmentedButtons {
                    width: parent.width
                    value: Power.profile
                    options: [
                        { value: PowerProfile.PowerSaver, label: "Экономия", icon: "eco" },
                        { value: PowerProfile.Balanced, label: "Баланс", icon: "balance" },
                        { value: PowerProfile.Performance, label: "Мощность", icon: "bolt" }
                    ]
                    onSelected: v => PowerProfiles.profile = v
                }
            }

            Column {
                width: parent.width
                spacing: 16
                visible: root.page === "usage"

                Column {
                    spacing: 2

                    FlowText {
                        textStyle: Type.labelLarge
                        color: Colors.m3onSurfaceVariant
                        text: root.dayTitle()
                    }

                    MText {
                        textStyle: Type.displaySmall
                        font.variableAxes: ({ "wght": 600 })
                        text: ScreenTime.fmt(ScreenTime.total(root.today))
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 180
                    radius: Shape.largeIncreased
                    color: Colors.m3surfaceContainerHigh

                    WeekBars {
                        x: 16
                        y: 16
                        width: parent.width - 32
                        barHeight: 120
                        values: root.week
                        labels: root.weekLabels
                        selected: root.day
                        interactive: true
                        onPicked: i => root.day = i
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.topApps.length > 0

                    Repeater {
                        model: root.topApps

                        Item {
                            id: app

                            required property var modelData
                            readonly property var entry: DesktopEntries.heuristicLookup(modelData[0])
                            readonly property real share: modelData[1] / Math.max(1, root.topApps[0][1])
                            readonly property bool unfolded: root.openApp === modelData[0]
                            SpringValue { id: unfold; target: app.unfolded ? 1 : 0; damping: 0.72; stiffness: 420; epsilon: 0.002 }
                            readonly property real u: Math.max(0, unfold.value)

                            width: col.width
                            height: 56 + (detail.implicitHeight + 8) * u
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -2
                                radius: Shape.large
                                color: Colors.m3surfaceContainerHigh
                                opacity: app.u
                            }

                            StateLayer {
                                width: parent.width
                                height: 56
                                radius: Shape.large
                                onClicked: root.openApp = app.unfolded ? "" : app.modelData[0]
                            }

                            AppIcon {
                                y: 12
                                x: 4
                                implicitSize: 32
                                source: Apps.iconSourceFor(app.modelData[0])
                            }

                            MText {
                                x: 50
                                y: 8
                                width: parent.width - 50 - 90
                                elide: Text.ElideRight
                                textStyle: Type.titleSmall
                                text: Apps.nameFor(app.modelData[0])
                            }

                            MText {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                y: 8
                                textStyle: Type.labelLarge
                                color: Colors.m3onSurfaceVariant
                                text: ScreenTime.fmt(app.modelData[1])
                            }

                            Rectangle {
                                x: 50
                                y: 34
                                width: parent.width - 54
                                height: 8
                                radius: 4
                                color: Colors.m3secondaryContainer

                                Rectangle {
                                    width: Math.max(8, parent.width * app.share)
                                    height: parent.height
                                    radius: 4
                                    color: Colors.m3primary

                                    Behavior on width { SpatialAnim {} }
                                }
                            }

                            Column {
                                id: detail
                                x: 12
                                y: 64
                                width: parent.width - 24
                                spacing: 10
                                opacity: Math.max(0, app.u * 1.5 - 0.5)
                                visible: app.u > 0.01

                                WeekBars {
                                    width: parent.width
                                    barHeight: 56
                                    values: app.unfolded ? root.appWeek(app.modelData[0]) : [0, 0, 0, 0, 0, 0, 0]
                                    labels: root.weekLabels
                                    selected: root.day
                                }

                                Row {
                                    spacing: 8
                                    bottomPadding: 4

                                    Chip {
                                        onClicked: root.openAppNow(app.modelData[0])
                                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "open_in_new"; size: 18; color: Colors.m3onSurfaceVariant }
                                        MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; text: "Открыть" }
                                    }
                                    MText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        textStyle: Type.labelMedium
                                        color: Colors.m3onSurfaceVariant
                                        text: "за неделю " + ScreenTime.fmt(root.appWeek(app.modelData[0]).reduce((a, b) => a + b, 0))
                                    }
                                }
                            }
                        }
                    }
                }

                MText {
                    visible: root.topApps.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    textStyle: Type.bodyMedium
                    color: Colors.m3onSurfaceVariant
                    text: Panels.nested ? "В тестовом окне время не считается" : !Config.o.screenTime.enabled ? "Учёт выключен в настройках" : "Пока ничего не набралось"
                }
            }
        }
    }
}

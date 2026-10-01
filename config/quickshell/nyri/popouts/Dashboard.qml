import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets
import qs.control

Surface {
    id: root

    name: "dashboard"
    keyboard: false

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.visible
    }

    onOpenChanged: {
        if (open) {
            cal.shownMonth = new Date();
            Weather.refreshIfStale();
            SysStats.watchers++;
        } else {
            SysStats.watchers = Math.max(0, SysStats.watchers - 1);
        }
    }

    component Meter: Column {
        id: meter
        property string label
        property real value
        property string text
        property string sub
        width: parent.width / 3
        spacing: 6

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            height: 76

            CircularProgress {
                anchors.fill: parent
                value: meter.value
                activeColor: meter.value > 0.85 ? Colors.m3error : Colors.m3primary
            }

            RollingText {
                anchors.centerIn: parent
                textStyle: Type.titleMediumEmph
                text: meter.text
            }
        }

        MText {
            anchors.horizontalCenter: parent.horizontalCenter
            textStyle: Type.labelLarge
            text: meter.label
        }

        MText {
            anchors.horizontalCenter: parent.horizontalCenter
            textStyle: Type.labelMedium
            color: Colors.m3onSurfaceVariant
            text: meter.sub
        }
    }

    component Section: Rectangle {
        default property alias body: holder.data
        property alias spacing: holder.spacing
        width: parent.width
        height: holder.implicitHeight + 32
        radius: Shape.largeIncreased
        color: Colors.m3surfaceContainerHigh

        Column {
            id: holder
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 10
        }
    }

    Popout {
        progress: root.progress
        toX: (parent.width - toW) / 2
        toW: 800
        toH: col.implicitHeight + 40

        Behavior on toH { SpatialAnim {} }

        Column {
            id: col
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 16

            Item {
                width: parent.width
                height: 92

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        spacing: 4

                        RollingText {
                            pixelSize: 64
                            weight: 700
                            color: Colors.m3primary
                            speed: "default"
                            text: Qt.formatTime(clock.date, "HH:mm")
                        }

                        RollingText {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            pixelSize: 24
                            weight: 500
                            color: Colors.m3onSurfaceVariant
                            text: Qt.formatTime(clock.date, "ss")
                        }
                    }

                    MText {
                        textStyle: Type.titleMedium
                        color: Colors.m3onSurfaceVariant
                        text: Qt.locale().toString(clock.date, "dddd, d MMMM")
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    visible: Weather.ready

                    readonly property var now: Weather.ready ? Weather.describe(Weather.current.code, Weather.current.day) : ({})

                    MaterialShape {
                        width: 72
                        height: 72
                        shape: "sunny"
                        color: Colors.m3primaryContainer

                        MIcon {
                            anchors.centerIn: parent
                            icon: parent.parent.now.icon ?? "cloud"
                            size: 36
                            fill: 1
                            color: Colors.m3onPrimaryContainer
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        MText {
                            font.pixelSize: 36
                            font.variableAxes: ({ "wght": 600 })
                            text: (Weather.current?.temp ?? "") + "°"
                        }

                        FlowText {
                            textStyle: Type.labelLarge
                            text: [parent.parent.now.text, Weather.city].filter(Boolean).join(" · ")
                        }

                        FlowText {
                            textStyle: Type.labelMedium
                            color: Colors.m3onSurfaceVariant
                            text: "ощущается " + (Weather.current?.feels ?? "") + "° · " + (Weather.current?.humidity ?? "") + "% · " + (Weather.current?.wind ?? 0).toFixed(1) + " м/с"
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 12

                Column {
                    width: 360
                    spacing: 12

                    Section {
                        CalendarView {
                            id: cal
                            width: parent.width
                            today: clock.date
                        }
                    }

                    Section {
                        id: usage

                        property var today: ({})
                        readonly property var topApps: Object.entries(today).sort((a, b) => b[1] - a[1]).slice(0, 3)

                        Connections {
                            target: root
                            function onOpenChanged() { if (root.open) usage.today = ScreenTime.dayTotals(new Date()) }
                        }

                        Item {
                            width: parent.width
                            height: 44

                            Column {
                                MText {
                                    textStyle: Type.labelLarge
                                    color: Colors.m3onSurfaceVariant
                                    text: "Сегодня за экраном"
                                }
                                MText {
                                    textStyle: Type.titleLarge
                                    font.variableAxes: ({ "wght": 600 })
                                    text: ScreenTime.fmt(ScreenTime.total(usage.today))
                                }
                            }

                            IconButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "bar_chart"
                                style: "tonal"
                                onClicked: Panels.open("power", "usage")
                            }
                        }

                        Repeater {
                            model: usage.topApps

                            Row {
                                id: appRow
                                required property var modelData
                                readonly property var entry: DesktopEntries.heuristicLookup(modelData[0])
                                width: parent.width
                                spacing: 10

                                AppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24
                                    height: 24
                                    source: Apps.iconSourceFor(appRow.modelData[0])
                                }

                                MText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 34 - 80
                                    elide: Text.ElideRight
                                    textStyle: Type.bodyMedium
                                    text: Apps.nameFor(appRow.modelData[0])
                                }

                                MText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 70
                                    horizontalAlignment: Text.AlignRight
                                    textStyle: Type.labelLarge
                                    color: Colors.m3onSurfaceVariant
                                    text: ScreenTime.fmt(appRow.modelData[1])
                                }
                            }
                        }

                        MText {
                            visible: usage.topApps.length === 0
                            textStyle: Type.bodyMedium
                            color: Colors.m3onSurfaceVariant
                            text: Panels.nested ? "В тестовом окне не считается" : !Config.o.screenTime.enabled ? "Учёт выключен в настройках" : "Пока пусто"
                        }
                    }
                }

                Column {
                    width: parent.width - 360 - 12
                    spacing: 12

                    MediaCard {
                        width: parent.width
                        visible: Media.player !== null
                        active: root.open
                    }

                    Section {
                        visible: Weather.daily.length > 0

                        Row {
                            width: parent.width

                            Repeater {
                                model: Weather.daily

                                Column {
                                    required property var modelData
                                    required property int index
                                    width: parent.width / Math.max(1, Weather.daily.length)
                                    spacing: 4

                                    MText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        textStyle: index === 0 ? Type.labelLargeEmph : Type.labelMedium
                                        color: index === 0 ? Colors.m3primary : Colors.m3onSurfaceVariant
                                        text: index === 0 ? "Сегодня" : Qt.locale().toString(modelData.date, "ddd")
                                    }

                                    MIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        icon: Weather.describe(modelData.code, true).icon
                                        size: 28
                                        fill: 1
                                        color: Colors.m3primary
                                    }

                                    MText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        textStyle: Type.labelLargeEmph
                                        text: modelData.max + "°"
                                    }

                                    MText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        textStyle: Type.labelMedium
                                        color: Colors.m3onSurfaceVariant
                                        text: modelData.min + "°"
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Row {
                            width: parent.width

                            Meter {
                                label: "Процессор"
                                value: SysStats.cpu
                                text: Math.round(SysStats.cpu * 100) + "%"
                                sub: SysStats.temp > 0 ? Math.round(SysStats.temp) + "°C" : ""
                            }
                            Meter {
                                label: "Память"
                                value: SysStats.mem
                                text: Math.round(SysStats.mem * 100) + "%"
                                sub: SysStats.memUsedGb.toFixed(1) + " ГБ"
                            }
                            Meter {
                                label: "Диск"
                                value: SysStats.disk
                                text: Math.round(SysStats.disk * 100) + "%"
                                sub: SysStats.diskText
                            }
                        }
                    }
                }
            }
        }
    }
}

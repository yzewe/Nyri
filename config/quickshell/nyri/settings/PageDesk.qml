import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Column {
    id: page
    spacing: 20

    readonly property var cfg: Config.o.desktop

    Rectangle {
        id: hero
        width: parent.width
        height: Math.round(width * 0.42)
        radius: Shape.extraLarge
        color: Colors.m3surfaceContainerHighest

        ClippingRectangle {
            anchors.fill: parent
            radius: hero.radius
            color: hero.color
        Image {
            anchors.fill: parent
            source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
            scale: heroHover.hovered ? 1.04 : 1
            Behavior on scale { SpatialAnim { speed: "slow" } }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 96
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Colors.m3scrim, 0) }
                GradientStop { position: 1; color: Qt.alpha(Colors.m3scrim, 0.45) }
            }
        }
        }
        HoverHandler { id: heroHover }

        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 16
            spacing: 10

            HeroButton {
                icon: "dashboard_customize"
                label: "Изменить стол"
                primary: true
                onClicked: { page.cfg.enabled = true; Panels.settingsOpen = false; Panels.deskEdit = true; }
            }
            HeroButton {
                icon: "palette"
                label: "Студия обоев"
                onClicked: Panels.open("wallpaper")
            }
        }
    }

    component HeroButton: Rectangle {
        id: hb
        property string icon
        property string label
        property bool primary: false
        signal clicked
        width: hbRow.implicitWidth + 36
        height: 48
        radius: hbLayer.pressed ? Shape.medium : height / 2
        color: primary ? Colors.m3primary : Colors.m3surfaceContainerHigh
        scale: hbSq.value
        SpringValue { id: hbSq; target: hbLayer.pressed ? 0.94 : 1; damping: 0.5; stiffness: 800; epsilon: 0.001 }
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Row {
            id: hbRow
            anchors.centerIn: parent
            spacing: 8
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: hb.icon; size: 20; fill: 1; color: hb.primary ? Colors.m3onPrimary : Colors.m3onSurface }
            MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLargeEmph; color: hb.primary ? Colors.m3onPrimary : Colors.m3onSurface; text: hb.label }
        }
        StateLayer { id: hbLayer; radius: hb.radius; color: hb.primary ? Colors.m3onPrimary : Colors.m3onSurface; onClicked: hb.clicked() }
    }

    ListGroup {
        width: parent.width
        SettingRow {
            icon: "animation"
            title: "Живые обои"
            MSwitch { checked: Config.o.wallpaper.animated; onToggled: c => Config.o.wallpaper.animated = c }
        }
        SettingRow {
            visible: Config.o.wallpaper.animated
            icon: "speed"
            title: "Скорость живых обоев"
            below: MSlider {
                width: parent.width
                value: (Math.log(Config.o.wallpaper.pace) / Math.LN2 + 2) / 4
                onMoved: v => deskPace.want = Math.pow(2, v * 4 - 2)
                Timer {
                    id: deskPace
                    property real want: 1
                    onWantChanged: restart()
                    interval: 200
                    onTriggered: Config.o.wallpaper.pace = Math.abs(want - 1) < 0.08 ? 1 : Math.round(want * 20) / 20
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 40
        MText { anchors.verticalCenter: parent.verticalCenter; x: 4; textStyle: Type.titleMediumEmph; text: "Виджеты" }
        MSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: page.cfg.enabled
            onToggled: c => page.cfg.enabled = c
        }
    }

    Grid {
        id: tiles
        width: parent.width
        columns: width > 560 ? 4 : 3
        spacing: 10
        opacity: page.cfg.enabled ? 1 : 0.45
        enabled: page.cfg.enabled
        Behavior on opacity { EffectAnim {} }
        readonly property real cell: (width - spacing * (columns - 1)) / columns

        Repeater {
            model: [
                { key: "clock", icon: "schedule", label: "Часы", shape: "cookie12Sided" },
                { key: "glance", icon: "today", label: "Дата и погода", shape: "pill" },
                { key: "battery", icon: "battery_full", label: "Батарея", shape: "clover4Leaf" },
                { key: "media", icon: "music_note", label: "Плеер", shape: "cookie9Sided" },
                { key: "forecast", icon: "partly_cloudy_day", label: "Прогноз", shape: "sunny" },
                { key: "calendar", icon: "calendar_month", label: "Календарь", shape: "square" },
                { key: "system", icon: "memory", label: "Система", shape: "cookie7Sided" },
                { key: "usage", icon: "hourglass_top", label: "Экранное время", shape: "clover8Leaf" }
            ]

            Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool on: page.cfg[modelData.key] === true
                width: tiles.cell
                height: 124
                radius: Shape.large
                color: on ? Colors.m3secondaryContainer : Colors.m3surfaceContainer
                Behavior on color { ColorAnim {} }

                SpringValue { id: pop; target: 1; damping: 0.45; stiffness: 700; epsilon: 0.001 }
                SpringValue { id: born; target: 1; damping: 0.65; stiffness: 420; Component.onCompleted: { value = 0; running = true; } }
                scale: (tileLayer.pressed ? 0.95 : 1) * pop.value * (0.85 + 0.15 * Math.min(1, born.value))
                opacity: Math.min(1, born.value * 1.5)

                MaterialShape {
                    id: badge
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    width: 56
                    height: 56
                    shape: tile.on ? tile.modelData.shape : "circle"
                    color: tile.on ? Colors.m3primary : Colors.m3surfaceContainerHighest
                    rotation: tile.on ? 0 : -30
                    Behavior on rotation { SpatialAnim { speed: "slow" } }
                    MIcon {
                        anchors.centerIn: parent
                        icon: tile.modelData.icon
                        size: 26
                        fill: tile.on ? 1 : 0
                        color: tile.on ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                        rotation: -badge.rotation
                    }
                }
                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    textStyle: tile.on ? Type.labelLargeEmph : Type.labelLarge
                    color: tile.on ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                    text: tile.modelData.label
                }
                StateLayer {
                    id: tileLayer
                    radius: tile.radius
                    color: tile.on ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                    onClicked: {
                        page.cfg[tile.modelData.key] = !tile.on;
                        pop.value = 0.88;
                        pop.running = true;
                    }
                }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: 8
        opacity: page.cfg.enabled ? 1 : 0.45
        enabled: page.cfg.enabled

        FilterChip {
            text: "Прилипать к сетке"
            picked: page.cfg.grid
            onClicked: page.cfg.grid = !page.cfg.grid
        }
        Repeater {
            model: [{ v: 16, label: "Мелкая" }, { v: 24, label: "Средняя" }, { v: 48, label: "Крупная" }]
            FilterChip {
                required property var modelData
                visible: page.cfg.grid
                text: modelData.label
                picked: page.cfg.gridSize === modelData.v
                onClicked: page.cfg.gridSize = modelData.v
            }
        }
        FilterChip {
            text: "Вернуть на место"
            picked: false
            onClicked: { page.cfg.positions = ({}); page.cfg.scales = ({}); page.cfg.only = ({}); }
        }
        FilterChip {
            visible: Quickshell.screens.length > 1
            text: "Одни обои на все экраны"
            picked: Config.o.wallpaper.span
            onClicked: Config.o.wallpaper.span = !Config.o.wallpaper.span
        }
    }
}

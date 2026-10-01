import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets

Column {
    id: page

    spacing: 20
    property var info: ({})

    Process {
        running: true
        command: [Paths.bin + "/nyri-sysinfo"]
        stdout: StdioCollector { onStreamFinished: { try { page.info = JSON.parse(text); } catch (e) {} } }
    }
    Component.onCompleted: SysStats.watchers++
    Component.onDestruction: SysStats.watchers = Math.max(0, SysStats.watchers - 1)

    function plural(n, one, few, many) {
        const m10 = n % 10, m100 = n % 100;
        return n + " " + (m10 === 1 && m100 !== 11 ? one : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? few : many);
    }
    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " ТБ" : (b / 1e9).toFixed(b >= 1e11 ? 0 : 1) + " ГБ"; }
    function since(sec) {
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return d ? d + " д " + h + " ч" : h ? h + " ч " + m + " мин" : m + " мин";
    }

    Rectangle {
        width: parent.width
        height: heroRow.implicitHeight + 40
        radius: Shape.extraLarge
        color: Colors.m3primaryContainer

        Row {
            id: heroRow
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 20

            MaterialShape {
                id: heroShape
                width: 96
                height: 96
                shape: "cookie12Sided"
                color: Colors.m3primary
                SpringValue { id: heroSpin; target: 30; damping: 0.5; stiffness: 60; Component.onCompleted: { value = -60; running = true; } }
                rotation: heroSpin.value
                MIcon { anchors.centerIn: parent; rotation: -heroShape.rotation; icon: "laptop_chromebook"; size: 44; fill: 1; color: Colors.m3onPrimary }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 96 - 20
                spacing: 4
                MText { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textStyle: Type.headlineMedium; color: Colors.m3onPrimaryContainer; text: page.info.model || "…" }
                FlowText { width: parent.width; elide: Text.ElideRight; textStyle: Type.bodyLarge; color: Colors.m3onPrimaryContainer; text: [page.info.os, page.info.hostname].filter(Boolean).join(" · ") }
                Flow {
                    width: parent.width
                    spacing: 6
                    topPadding: 6
                    Repeater {
                        model: [
                            { icon: "schedule", text: page.info.uptime ? "работает " + page.since(page.info.uptime) : "" },
                            { icon: "deployed_code", text: page.info.packages ? page.plural(page.info.packages, "пакет", "пакета", "пакетов") : "" },
                            { icon: "terminal", text: page.info.kernel ?? "" }
                        ].filter(c => c.text)
                        Rectangle {
                            required property var modelData
                            height: 30
                            width: chipRow.implicitWidth + 20
                            radius: 15
                            color: Qt.alpha(Colors.m3onPrimaryContainer, 0.12)
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: modelData.icon; size: 16; color: Colors.m3onPrimaryContainer }
                                MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; color: Colors.m3onPrimaryContainer; text: modelData.text }
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        width: parent.width
        spacing: 10
        Repeater {
            model: [
                { label: "Процессор", value: SysStats.cpu, text: Math.round(SysStats.cpu * 100) + "%", sub: SysStats.temp > 0 ? Math.round(SysStats.temp) + " °C" : "" },
                { label: "Память", value: SysStats.mem, text: Math.round(SysStats.mem * 100) + "%", sub: SysStats.memTotalGb ? SysStats.memUsedGb.toFixed(1) + " из " + SysStats.memTotalGb.toFixed(0) + " ГБ" : "" },
                { label: "Диск", value: SysStats.disk, text: Math.round(SysStats.disk * 100) + "%", sub: SysStats.diskText },
                { label: "Батарея", value: Math.min(100, page.info.battery?.health ?? 0) / 100,
                  text: page.info.battery ? Math.min(100, page.info.battery.health) + "%" : "—",
                  sub: page.info.battery && page.info.battery.cycles >= 0 ? page.plural(page.info.battery.cycles, "цикл", "цикла", "циклов") : "" }
            ]
            Rectangle {
                id: meter
                required property var modelData
                required property int index
                width: (parent.width - 30) / 4
                height: 150
                radius: Shape.large
                color: Colors.m3surfaceContainer
                SpringValue { id: ring; target: Math.min(1, meter.modelData.value); damping: 1; stiffness: 40; epsilon: 0.001 }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 72
                    height: 72
                    CircularProgress { anchors.fill: parent; stroke: 7; value: ring.value; animated: false; activeColor: meter.index < 3 && meter.modelData.value > 0.85 ? Colors.m3error : Colors.m3primary }
                    MText { anchors.centerIn: parent; textStyle: Type.titleMediumEmph; font.features: { "tnum": 1 }; text: meter.modelData.text }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    MText { anchors.horizontalCenter: parent.horizontalCenter; textStyle: Type.labelLargeEmph; text: meter.modelData.label }
                    MText { anchors.horizontalCenter: parent.horizontalCenter; textStyle: Type.labelMedium; color: Colors.m3onSurfaceVariant; text: meter.modelData.sub; visible: text !== "" }
                }
            }
        }
    }

    component Fact: Rectangle {
        id: fact
        property string icon
        property string title
        property var lines: []
        width: (page.width - 10) / 2
        height: Math.max(120, factCol.implicitHeight + 32)
        radius: Shape.large
        color: Colors.m3surfaceContainer
        Row {
            x: 16
            y: 16
            spacing: 14
            width: parent.width - 32
            MaterialShape {
                width: 44
                height: 44
                shape: "cookie9Sided"
                color: Colors.m3secondaryContainer
                MIcon { anchors.centerIn: parent; icon: fact.icon; size: 22; fill: 1; color: Colors.m3onSecondaryContainer }
            }
            Column {
                id: factCol
                width: parent.width - 58
                spacing: 2
                MText { textStyle: Type.titleSmall; text: fact.title }
                Repeater {
                    model: fact.lines.filter(Boolean)
                    MText {
                        required property string modelData
                        width: factCol.width
                        wrapMode: Text.Wrap
                        textStyle: Type.bodyMedium
                        color: Colors.m3onSurfaceVariant
                        text: modelData
                    }
                }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: 10

        Fact {
            icon: "memory"
            title: "Процессор"
            lines: [page.info.cpu, page.info.cores ? page.plural(page.info.cores, "ядро", "ядра", "ядер") + " · " + page.plural(page.info.threads, "поток", "потока", "потоков") + (page.info.ghz ? " · до " + page.info.ghz + " ГГц" : "") : ""]
        }
        Fact {
            icon: "developer_board"
            title: "Графика"
            lines: page.info.gpus ?? []
        }
        Fact {
            icon: "memory_alt"
            title: "Память"
            lines: page.info.memTotal ? [page.gb(page.info.memUsed) + " занято из " + page.gb(page.info.memTotal),
                                         page.info.swapTotal ? "подкачка " + page.gb(page.info.swapUsed) + " из " + page.gb(page.info.swapTotal) : ""] : []
        }
        Fact {
            icon: "hard_drive"
            title: "Диски"
            lines: (page.info.disks ?? []).map(d => d.mount + " · свободно " + page.gb(d.total - d.used) + " из " + page.gb(d.total))
        }
        Fact {
            icon: "monitor"
            title: (page.info.outputs?.length ?? 0) > 1 ? "Экраны" : "Экран"
            lines: (page.info.outputs ?? []).map(o => o.name + " · " + o.w + "×" + o.h + " · " + o.hz + " Гц" + (o.scale !== 1 ? " · ×" + Math.round(o.scale * 100) / 100 : ""))
        }
        Fact {
            icon: "wifi"
            title: "Сеть"
            lines: [Net.label].concat((page.info.ips ?? []).map(a => a.dev + " · " + a.ip))
        }
        Fact {
            visible: !!page.info.battery
            icon: "battery_full"
            title: "Батарея"
            lines: page.info.battery ? ["Ёмкость " + page.info.battery.fullWh + " из " + page.info.battery.designWh + " Вт·ч",
                                        [page.info.battery.tech, page.info.battery.maker].filter(Boolean).join(" · ")] : []
        }
        Fact {
            icon: "deployed_code"
            title: "Nyri"
            lines: [page.info.nyri ? (page.info.branch ? page.info.branch + " · " : "") + page.info.nyri : "",
                    page.info.shellMemory ? "Оболочка · " + Math.round(page.info.shellMemory / 1e6) + " МБ" : ""]
        }
    }

    ListGroup {
        width: parent.width
        title: "Программы"
        SettingRow { icon: "grid_view"; title: Compositor.isHyprland ? "Hyprland" : "niri"; subtitle: (page.info.compositor ?? page.info.niri ?? "").replace(/^(?:niri|Hyprland)\s*/i, "").replace(/\s*\(.*\)\s*$/, "") }
        SettingRow { icon: "widgets"; title: "Quickshell"; subtitle: (page.info.quickshell ?? "").replace(/^quickshell\s*/i, "").replace(/\s*\(.*\)\s*$/, "") }
        SettingRow { icon: "terminal"; title: "Ядро"; subtitle: page.info.kernel ?? "" }
    }

    ListGroup {
        width: parent.width
        title: "Погода"

        SettingRow {
            id: cityRow
            icon: "location_on"
            title: "Город"
            subtitle: Config.o.weather.city + " · " + Config.o.weather.lat.toFixed(2) + ", " + Config.o.weather.lon.toFixed(2)

            below: Row {
                width: parent.width
                spacing: 8

                SearchField {
                    id: city
                    width: parent.width - 56
                    icon: "search"
                    placeholder: "Найти город"
                    input.onAccepted: find.clicked()
                }

                IconButton {
                    id: find
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "arrow_forward"
                    style: "filled"
                    size: 48
                    onClicked: if (city.text.trim()) geo.lookup(city.text.trim())
                }
            }

            Process {
                id: geo
                function lookup(name) {
                    command = ["curl", "-s", "--max-time", "10", "https://geocoding-api.open-meteo.com/v1/search?count=1&language=ru&name=" + encodeURIComponent(name)];
                    running = true;
                }
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const r = JSON.parse(text).results?.[0];
                            if (!r) { cityRow.subtitle = "Не нашёл такой город"; return; }
                            Config.o.weather.city = r.name;
                            Config.o.weather.lat = r.latitude;
                            Config.o.weather.lon = r.longitude;
                            city.text = "";
                            Weather.refresh();
                        } catch (e) {}
                    }
                }
            }
        }
    }

    ListGroup {
        width: parent.width
        title: "Полезное"
        SettingRow {
            icon: "keyboard"
            title: "Горячие клавиши"
            clickable: true
            onClicked: {
                if (Compositor.isHyprland) Panels.openSettings("keys");
                else Quickshell.execDetached(["niri", "msg", "action", "show-hotkey-overlay"]);
            }
        }
        SettingRow {
            icon: "folder_open"
            title: "Открыть папку Nyri"
            clickable: true
            onClicked: Quickshell.execDetached(["nemo", Paths.root])
        }
    }
}

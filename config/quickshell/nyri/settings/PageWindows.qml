import QtQuick
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets

Column {
    id: page
    width: parent.width
    spacing: 20
    readonly property var values: Hypr.windowOptions
    property string message: ""
    property bool error: false

    function change(key, value) {
        if (save.running || !page.values) return;
        save.previousValues = page.values;
        save.errorOutput = "";
        var next = {};
        for (var name in page.values) next[name] = page.values[name];
        next[key] = value;
        Hypr.applyWindowOptions(next);
        page.message = "";
        page.error = false;
        save.command = [Paths.bin + "/nyri-hypr", "set", key, String(value)];
        save.running = true;
    }
    Process {
        id: save
        property var previousValues: ({})
        property string errorOutput: ""
        command: []
        stdout: StdioCollector { onStreamFinished: {
            try { Hypr.applyWindowOptions(JSON.parse(text)); page.message = "Применено"; page.error = false; }
            catch (e) { Hypr.reloadWindowOptions(); }
        }}
        stderr: StdioCollector { onStreamFinished: if (text.trim()) save.errorOutput = text.trim() }
        onExited: code => {
            if (code === 0) return;
            Hypr.applyWindowOptions(save.previousValues);
            page.error = true;
            page.message = save.errorOutput || "Не удалось сохранить настройку";
        }
    }
    MText {
        visible: !Compositor.isHyprland
        width: parent.width
        wrapMode: Text.Wrap
        textStyle: Type.bodyMedium
        color: Colors.m3onSurfaceVariant
        text: "Эти настройки работают в Hyprland"
    }
    ListGroup {
        visible: Compositor.isHyprland && page.values
        enabled: !save.running
        width: parent.width
        title: "Раскладка"
        SettingRow {
            icon: "grid_view"
            title: "Алгоритм размещения"
            subtitle: "Оба режима заполняют доступную область"
            choice: page.values?.layout ?? ""
            choices: [{ value: "dwindle", label: "Dwindle" }, { value: "master", label: "Master" }]
            onChosen: v => page.change("layout", v)
        }
        SettingRow {
            icon: "space_dashboard"
            title: "Между окнами"
            choice: page.values?.gapsIn ?? 0
            choices: [{ value: 0, label: "0 px" }, { value: 4, label: "4 px" }, { value: 8, label: "8 px" }, { value: 12, label: "12 px" }, { value: 16, label: "16 px" }, { value: 24, label: "24 px" }]
            onChosen: v => page.change("gapsIn", v)
        }
        SettingRow {
            icon: "crop_free"
            title: "Отступ от краёв и панели"
            choice: page.values?.gapsOut ?? 0
            choices: [{ value: 0, label: "0 px" }, { value: 4, label: "4 px" }, { value: 8, label: "8 px" }, { value: 10, label: "10 px" }, { value: 12, label: "12 px" }, { value: 16, label: "16 px" }, { value: 24, label: "24 px" }]
            onChosen: v => page.change("gapsOut", v)
        }
    }
    ListGroup {
        visible: Compositor.isHyprland && page.values
        enabled: !save.running
        width: parent.width
        title: "Вид окон"
        SettingRow {
            icon: "border_style"
            title: "Толщина рамки"
            choice: page.values?.border ?? 0
            choices: [{ value: 0, label: "Нет" }, { value: 2, label: "2 px" }, { value: 3, label: "3 px" }, { value: 4, label: "4 px" }, { value: 6, label: "6 px" }]
            onChosen: v => page.change("border", v)
        }
        SettingRow {
            icon: "rounded_corner"
            title: "Скругление углов"
            choice: page.values?.corner ?? 0
            choices: [{ value: 0, label: "Нет" }, { value: 8, label: "8 px" }, { value: 12, label: "12 px" }, { value: 20, label: "20 px" }, { value: 28, label: "28 px" }]
            onChosen: v => page.change("corner", v)
        }
        SettingRow {
            icon: "shadow"
            title: "Тень окон"
            MSwitch { checked: (page.values?.shadow ?? 0) === 1; onToggled: v => page.change("shadow", v ? 1 : 0) }
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
}

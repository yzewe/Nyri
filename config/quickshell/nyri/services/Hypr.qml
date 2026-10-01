pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property var liveAddresses: null
    property var workspaces: []
    property var windows: ({})
    function normalizedAddress(value) {
        const hex = String(value ?? "").toLowerCase();
        return hex.startsWith("0x") ? hex : "0x" + hex;
    }
    function rebuildWorkspaces() {
        workspaces = Hyprland.workspaces.values.map(w => ({
            id: w.id, idx: w.id, name: w.name,
            output: w.monitor?.name ?? "",
            is_active: w.active, is_focused: w.focused, is_urgent: w.urgent,
            active_window_id: null
        })).filter(w => w.id > 0).sort((a, b) => a.idx - b.idx);
    }
    function rebuildWindows() {
        const map = {};
        for (const t of Hyprland.toplevels.values) {
            if (!t.address) continue;
            if (liveAddresses && !liveAddresses[normalizedAddress(t.address)]) continue;
            const info = t.lastIpcObject ?? {};
            const history = Number(info.focusHistoryID ?? 999999);
            map[t.address] = {
                id: t.address, app_id: info["class"] || info.initialClass || t.wayland?.appId || "",
                title: t.title, pid: info.pid ?? 0,
                workspace_id: t.workspace?.id ?? info.workspace?.id ?? 0,
                is_focused: t.activated, is_floating: info.floating ?? false,
                is_urgent: t.urgent,
                focus_timestamp: { secs: 1000000 - history, nanos: 0 }
            };
        }
        windows = map;
    }
    function noteStructure() { settle.restart(); }
    Timer { id: settle; interval: 32; onTriggered: { root.rebuildWorkspaces(); root.rebuildWindows(); } }

    readonly property var focusedWindowId: Hyprland.activeToplevel?.address ?? null
    readonly property var focusedWindow: {
        const t = Hyprland.activeToplevel;
        if (!t || !t.address) return null;
        const row = windows[t.address];
        if (!row) return null;
        const info = t.lastIpcObject ?? {};
        const title = t.title || row.title;
        const appId = info["class"] || info.initialClass || t.wayland?.appId || row.app_id;
        if (title === row.title && appId === row.app_id && !!t.activated === row.is_focused) return row;
        return Object.assign({}, row, { title, app_id: appId, is_focused: !!t.activated });
    }
    readonly property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
    property var windowOptions: null
    property int windowRev: 0
    function applyWindowOptions(values) {
        windowRev++;
        windowOptions = values;
    }
    function reloadWindowOptions() {
        windowRead.rev = windowRev;
        if (!windowRead.running) windowRead.running = true;
    }
    Process {
        id: windowRead
        property int rev: 0
        command: [Paths.bin + "/nyri-hypr", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (windowRead.rev !== root.windowRev) return;
                try { root.windowOptions = JSON.parse(text); }
                catch (e) { console.warn("Hyprland window options:", e); }
            }
        }
    }
    property var layoutNames: []
    property int layoutIndex: 0
    readonly property string layoutShort: {
        const name = layoutNames[layoutIndex] ?? "";
        if (/^English/.test(name)) return "EN";
        if (/^Russian/.test(name)) return "RU";
        return name.slice(0, 2).toUpperCase();
    }
    readonly property bool overviewOpen: false
    readonly property var activeCasts: []

    function workspacesOn(output) {
        const existing = workspaces.filter(w => w.output === output);
        if (output !== focusedOutput) return existing;
        const result = existing.slice();
        for (let idx = 1; idx <= 5; idx++) {
            if (!result.some(w => w.idx === idx))
                result.push({ id: idx, idx, name: String(idx), output,
                    is_active: false, is_focused: false, is_urgent: false, active_window_id: null });
        }
        return result.sort((a, b) => a.idx - b.idx);
    }
    function windowCount(id) { return Object.values(windows).filter(w => w.workspace_id === id).length; }
    function windowOfPid(pid) { return Object.values(windows).find(w => w.pid === pid) ?? null; }

    function action(name, ...args) {
        const id = args.includes("--id") ? args[args.indexOf("--id") + 1] : null;
        const windowId = args.includes("--window-id") ? args[args.indexOf("--window-id") + 1] : id;
        function addressOf(value) {
            if (!value) return "";
            const hex = String(value);
            return "address:" + (hex.startsWith("0x") ? hex : "0x" + hex);
        }
        const address = addressOf(id);
        switch (name) {
        case "focus-workspace": Hyprland.dispatch("workspace " + args[0]); break;
        case "focus-workspace-down": Hyprland.dispatch("workspace r+1"); break;
        case "focus-workspace-up": Hyprland.dispatch("workspace r-1"); break;
        case "focus-window": Hyprland.dispatch("focuswindow " + address); break;
        case "close-window": Hyprland.dispatch("closewindow " + address); break;
        case "maximize-window-to-edges":
            if (id) Hyprland.dispatch("focuswindow " + address);
            Hyprland.dispatch("fullscreen 1"); break;
        case "fullscreen-window":
            if (id) Hyprland.dispatch("focuswindow " + address);
            Hyprland.dispatch("fullscreen 0"); break;
        case "toggle-window-floating": Hyprland.dispatch("togglefloating " + address); break;
        case "move-window-to-workspace":
            Hyprland.dispatch("movetoworkspace " + args[args.length - 1] + "," + addressOf(windowId)); break;
        case "switch-layout": Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]); break;
        default: console.warn("Unsupported Hyprland action:", name);
        }
    }

    Process {
        id: devices
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? [];
                    const kb = keyboards.find(k => k.main) ?? keyboards[0];
                    if (!kb) return;
                    root.layoutNames = [kb.active_keymap ?? ""];
                    root.layoutIndex = 0;
                } catch (e) { console.warn("Hyprland keyboard info:", e); }
            }
        }
    }
    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const live = {};
                    for (const window of JSON.parse(text)) live[root.normalizedAddress(window.address)] = true;
                    root.liveAddresses = live;
                    root.rebuildWindows();
                } catch (e) { console.warn("Hyprland client list:", e); }
            }
        }
    }
    Timer { id: scanClients; interval: 100; onTriggered: clients.running = true }
    Timer { interval: 4000; repeat: true; running: true; onTriggered: if (!clients.running) clients.running = true }
    Component.onCompleted: {
        rebuildWorkspaces();
        rebuildWindows();
        devices.running = true;
        clients.running = true;
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) reloadWindowOptions();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.parse(2);
                root.layoutNames = [parts[1] ?? ""];
                root.layoutIndex = 0;
            }
            if (event.name === "workspace" || event.name === "workspacev2"
                    || event.name === "focusedmon" || event.name === "focusedmonv2"
                    || event.name === "createworkspace" || event.name === "destroyworkspace"
                    || event.name === "openwindow" || event.name === "closewindow"
                    || event.name === "movewindow" || event.name === "activewindowv2")
                root.noteStructure();
            if (event.name === "openwindow" || event.name === "closewindow") scanClients.restart();
        }
    }
}

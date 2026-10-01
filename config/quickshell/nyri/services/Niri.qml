pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property var focusedWindowId: null
    property var layoutNames: []
    property int layoutIndex: 0
    property bool overviewOpen: false
    property var casts: []
    readonly property var activeCasts: casts.filter(c => c.is_active !== false)

    readonly property string focusedOutput: workspaces.find(ws => ws.is_focused)?.output ?? ""
    readonly property var focusedWindow: focusedWindowId !== null ? (windows[focusedWindowId] ?? null) : null
    readonly property string layoutShort: {
        const name = layoutNames[layoutIndex] ?? "";
        const known = { "English (US)": "EN", "Russian": "RU" };
        return known[name] ?? name.slice(0, 2).toUpperCase();
    }

    function workspacesOn(output) {
        return workspaces.filter(ws => ws.output === output);
    }

    function windowOfPid(pid) {
        for (const id in windows)
            if (windows[id].pid === pid) return windows[id];
        return null;
    }

    function windowCount(workspaceId) {
        let n = 0;
        for (const id in windows)
            if (windows[id].workspace_id === workspaceId)
                n++;
        return n;
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    function setWorkspaces(list) {
        root.workspaces = list.slice().sort((a, b) =>
            a.output === b.output ? a.idx - b.idx : a.output.localeCompare(b.output));
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            setWorkspaces(ev.WorkspacesChanged.workspaces);
        } else if (ev.WorkspaceActivated) {
            const { id, focused } = ev.WorkspaceActivated;
            const output = workspaces.find(ws => ws.id === id)?.output;
            setWorkspaces(workspaces.map(ws => Object.assign({}, ws, {
                is_active: ws.output === output ? ws.id === id : ws.is_active,
                is_focused: focused ? ws.id === id : ws.is_focused
            })));
        } else if (ev.WorkspaceActiveWindowChanged) {
            const { workspace_id, active_window_id } = ev.WorkspaceActiveWindowChanged;
            setWorkspaces(workspaces.map(ws => ws.id === workspace_id
                ? Object.assign({}, ws, { active_window_id }) : ws));
        } else if (ev.WorkspaceUrgencyChanged) {
            const { id, urgent } = ev.WorkspaceUrgencyChanged;
            setWorkspaces(workspaces.map(ws => ws.id === id ? Object.assign({}, ws, { is_urgent: urgent }) : ws));
        } else if (ev.WindowsChanged) {
            const map = {};
            let focused = null;
            for (const w of ev.WindowsChanged.windows) {
                map[w.id] = w;
                if (w.is_focused)
                    focused = w.id;
            }
            root.windows = map;
            root.focusedWindowId = focused;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const map = Object.assign({}, windows);
            map[w.id] = w;
            root.windows = map;
            if (w.is_focused)
                root.focusedWindowId = w.id;
        } else if (ev.WindowClosed) {
            const map = Object.assign({}, windows);
            delete map[ev.WindowClosed.id];
            root.windows = map;
            if (focusedWindowId === ev.WindowClosed.id)
                root.focusedWindowId = null;
        } else if (ev.WindowFocusChanged) {
            root.focusedWindowId = ev.WindowFocusChanged.id;
        } else if (ev.WindowLayoutsChanged) {
            const map = Object.assign({}, windows);
            for (const [id, layout] of ev.WindowLayoutsChanged.changes)
                if (map[id]) map[id] = Object.assign({}, map[id], { layout });
            root.windows = map;
        } else if (ev.WindowUrgencyChanged) {
            const { id, urgent } = ev.WindowUrgencyChanged;
            if (windows[id]) {
                const map = Object.assign({}, windows);
                map[id] = Object.assign({}, map[id], { is_urgent: urgent });
                root.windows = map;
            }
        } else if (ev.KeyboardLayoutsChanged) {
            root.layoutNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
            root.layoutIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            root.layoutIndex = ev.KeyboardLayoutSwitched.idx;
        } else if (ev.ConfigLoaded) {
            if (ev.ConfigLoaded.failed)
                Quickshell.execDetached(["notify-send", "-a", "niri", "-u", "critical", "-i", "dialog-error",
                    "Ошибка в конфиге niri", "Работает прежняя версия. Подробности: niri validate"]);
        } else if (ev.CastsChanged) {
            root.casts = ev.CastsChanged.casts ?? [];
        } else if (ev.CastStartedOrChanged) {
            const c = ev.CastStartedOrChanged.cast;
            root.casts = root.casts.filter(x => x.stream_id !== c.stream_id).concat([c]);
        } else if (ev.CastStopped) {
            const id = ev.CastStopped.stream_id;
            root.casts = root.casts.filter(x => x.stream_id !== id);
        } else if (ev.OverviewOpenedOrClosed) {
            root.overviewOpen = ev.OverviewOpenedOrClosed.is_open;
        }
    }

    Process {
        id: stream
        running: !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {
                    console.warn("niri event unreadable:", e, line.slice(0, 200));
                }
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }
}

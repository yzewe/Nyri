pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var micStreams: Pipewire.nodes.values.filter(n => n.isStream
        && n.properties["media.class"] === "Stream/Input/Audio"
        && !/(peak|monitor|cava|quickshell)/i.test(n.properties["application.name"] ?? ""))
    readonly property var micApps: uniq(micStreams.map(n => appOfNode(n)))

    property var camUsers: []
    readonly property var videoStreams: Pipewire.nodes.values.filter(n => n.isStream
        && n.properties["media.class"] === "Stream/Input/Video")
    readonly property var camApps: uniq(camUsers.map(u => appOfPid(u.pid, u.app))
        .concat(Compositor.activeCasts.length ? [] : videoStreams.map(n => appOfNode(n))))

    readonly property var casts: Compositor.activeCasts
    readonly property var castApps: uniq(casts.map(c => appOfPid(c.pid, "")).filter(Boolean))
    readonly property bool casting: casts.length > 0

    readonly property bool micOn: micApps.length > 0
    readonly property bool camOn: camApps.length > 0
    readonly property bool anyOn: micOn || camOn || casting

    readonly property bool active: Config.o.privacy.mode || (Config.o.privacy.autoOnCast && casting)

    function uniq(list) { return list.filter((x, i) => x && list.indexOf(x) === i); }
    function appOfNode(n) {
        const pid = parseInt(n.properties["application.process.id"] ?? "0");
        return appOfPid(pid, n.properties["application.name"] ?? n.name ?? "");
    }
    function appOfPid(pid, fallback) {
        const w = pid ? Compositor.windowOfPid(pid) : null;
        return w ? Apps.nameFor(w.app_id) : fallback;
    }

    function muteMic(on) {
        if (Audio.source?.audio) Audio.source.audio.muted = on;
        for (const n of micStreams) if (n.audio) n.audio.muted = on;
    }
    property bool micBlocked: false
    function setMicBlocked(on) {
        Quickshell.execDetached([Paths.bin + "/nyri-device-block", on ? "block" : "unblock", "mic"]);
    }
    FileView {
        path: Paths.state + "/device-block.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.micBlocked = !!state.mic;
            } catch (e) {}
        }
    }
    Timer {
        running: root.micBlocked
        interval: 3000
        repeat: true
        onTriggered: Quickshell.execDetached([Paths.bin + "/nyri-device-block", "enforce"])
    }
    function stopCasts() {
        for (const c of casts)
            Compositor.action("stop-cast", "--session-id", String(c.session_id));
    }
    PwObjectTracker { objects: root.micStreams }

    Process {
        running: true
        command: [Paths.bin + "/nyri-camwatch"]
        stdout: SplitParser {
            onRead: line => { try { root.camUsers = JSON.parse(line); } catch (e) {} }
        }
    }

    property var history: []
    property var open: ({})

    function track(kind, apps) {
        const now = Date.now();
        const next = Object.assign({}, open);
        let log = history.slice();
        let changed = false;
        for (const app of apps) {
            const k = kind + ":" + app;
            if (!(k in next)) { next[k] = now; changed = true; }
        }
        for (const k in next) {
            if (!k.startsWith(kind + ":")) continue;
            const app = k.slice(kind.length + 1);
            if (apps.indexOf(app) < 0) {
                log.unshift({ kind, app, start: next[k], end: now });
                delete next[k];
                changed = true;
            }
        }
        if (!changed) return;
        open = next;
        history = log.slice(0, 200);
        save();
    }
    onMicAppsChanged: track("mic", micApps)
    onCamAppsChanged: track("camera", camApps)
    onCastAppsChanged: track("screen", casting ? (castApps.length ? castApps : ["Экран"]) : [])
    onCastingChanged: track("screen", casting ? (castApps.length ? castApps : ["Экран"]) : [])

    readonly property var running: Object.keys(open).map(k => {
        const i = k.indexOf(":");
        return { kind: k.slice(0, i), app: k.slice(i + 1), start: open[k], end: 0 };
    })

    function clearHistory() { history = []; save(); }
    function save() { if (!Panels.nested) store.setText(JSON.stringify(history)); }

    FileView {
        id: store
        path: Paths.state + "/privacy.json"
        printErrors: false
        onLoaded: { try { root.history = JSON.parse(text()); } catch (e) {} }
    }

    readonly property string liveKdl: active
        ? "// Written by the shell (services/Privacy.qml) while privacy mode is on.\n"
          + "layer-rule {\n    match namespace=\"^nyri-(notifications|clipboard|launcher|control)$\"\n    block-out-from \"screencast\"\n}\n"
        : "// Written by the shell (services/Privacy.qml). Empty: privacy mode is off.\n"
    onLiveKdlChanged: writeLive()
    Component.onCompleted: writeLive()
    function writeLive() {
        if (Panels.nested) return;
        live.setText(liveKdl);
    }
    FileView {
        id: live
        path: Paths.root + "/config/niri/live.kdl"
        printErrors: false
    }
}

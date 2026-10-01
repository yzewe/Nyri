pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var list: {
        const out = [];
        if (Toggles.recording)
            out.push({ id: "record", kind: "record", icon: "radio_button_checked", tone: "error", priority: 100,
                       title: "Запись экрана", text: "Идёт запись", since: Toggles.recordingSince, progress: -1,
                       actions: [{ icon: "stop", label: "Остановить", key: "stop" }] });
        if (Privacy.casting)
            out.push({ id: "cast", kind: "cast", icon: "screen_share", tone: "error", priority: 95,
                       title: "Экран транслируется", text: Privacy.castApps.join(", ") || "Трансляция через niri", progress: -1,
                       actions: [{ icon: "stop_screen_share", label: "Прекратить", key: "stop" }] });
        if (Privacy.camOn)
            out.push({ id: "camera", kind: "camera", icon: "videocam", tone: "error", priority: 90,
                       title: "Камера включена", text: Privacy.camApps.join(", "), progress: -1,
                       actions: [] });
        if (Privacy.micOn)
            out.push({ id: "mic", kind: "mic", icon: Privacy.micBlocked ? "mic_off" : "mic", tone: Privacy.micBlocked ? "primary" : "error", priority: 85,
                       title: Privacy.micBlocked ? "Микрофон заглушён" : "Микрофон слушает", text: Privacy.micApps.join(", "), progress: -1,
                       actions: [{ icon: Privacy.micBlocked ? "mic" : "mic_off", label: Privacy.micBlocked ? "Включить" : "Заглушить", key: "toggle" }] });
        for (const t of timers)
            out.push({ id: "timer:" + t.id, kind: "timer", icon: "timer", tone: "primary", priority: 80,
                       title: t.label || "Таймер", text: "",
                       until: t.paused ? 0 : t.end, frozen: t.paused ? t.left : -1,
                       progress: 1 - Math.max(0, t.paused ? t.left : t.end - now) / t.total,
                       actions: [{ icon: t.paused ? "play_arrow" : "pause", label: t.paused ? "Дальше" : "Пауза", key: "pause" },
                                 { icon: "more_time", label: "+1 мин", key: "more" },
                                 { icon: "close", label: "Отменить", key: "stop" }] });
        if (stopwatch)
            out.push({ id: "stopwatch", kind: "stopwatch", icon: "timer_play", tone: "primary", priority: 78,
                       title: "Секундомер", text: stopwatch.laps.length ? "Круг " + (stopwatch.laps.length + 1) + " · прошлый " + fmtClock(stopwatch.laps[0]) : (stopwatch.paused ? "Пауза" : ""),
                       since: stopwatch.paused ? 0 : stopwatch.start, frozen: stopwatch.paused ? stopwatch.pausedAt - stopwatch.start : -1, progress: -1,
                       actions: [{ icon: stopwatch.paused ? "play_arrow" : "pause", label: stopwatch.paused ? "Дальше" : "Пауза", key: "pause" },
                                 { icon: "flag", label: "Круг", key: "lap" }, { icon: "stop", label: "Стоп", key: "stop" }] });
        for (const j of Object.values(jobs))
            out.push(j);
        for (const d of downloadList)
            out.push(d);
        if (updating)
            out.push({ id: "update", kind: "update", icon: "system_update_alt", tone: "primary", priority: 60,
                       title: "Обновление системы", text: "pacman устанавливает пакеты", progress: -2, actions: [] });
        if (vpnNames.length)
            out.push({ id: "vpn", kind: "vpn", icon: "vpn_lock", tone: "primary", priority: 40, ambient: true,
                       title: "VPN", text: vpnNames.join(", "), progress: -1, actions: [] });
        if (Phone.reachable && Phone.phone)
            out.push({ id: "phone:" + Phone.phone.id, kind: "phone", icon: "smartphone", tone: "primary", priority: 32, ambient: !(Phone.battery && Phone.battery.charge <= 15 && !Phone.battery.charging),
                       title: Phone.phone.name + (Phone.battery ? " · " + Phone.battery.charge + "%" : ""), text: Phone.battery ? "Заряд " + Phone.battery.charge + "%" + (Phone.battery.charging ? " · заряжается" : "") : "На связи",
                       progress: -1, actions: [] });
        for (const d of btDevices)
            out.push({ id: "bt:" + d.address, kind: "bt", icon: Bt.deviceIcon(d), tone: "primary", priority: 30, ambient: true,
                       title: d.name + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : ""), text: d.batteryAvailable ? "Заряд " + Math.round(d.battery * 100) + "%" : "Подключено",
                       progress: -1, actions: [] });
        const p = Media.player;
        if (p && p.isPlaying)
            out.push({ id: "media", kind: "media", icon: "music_note", tone: "primary", priority: 50, ambient: false,
                       title: p.trackTitle || p.identity, text: p.trackArtist ?? "", cover: Media.art,
                       progress: -1, actions: [] });
        for (const f of flashes)
            out.push(f);
        return out.sort((a, b) => b.priority - a.priority);
    }
    readonly property int count: list.length
    readonly property var loud: list.filter(a => !a.ambient || freshIds.indexOf(a.id) >= 0)

    property var freshIds: []
    property var seenIds: []
    onListChanged: {
        const ids = list.map(a => a.id);
        const born = ids.filter(id => seenIds.indexOf(id) < 0);
        seenIds = ids;
        if (!born.length) return;
        freshIds = freshIds.concat(born);
        const t = Qt.createQmlObject("import QtQuick; Timer { interval: 5000 }", root);
        t.triggered.connect(() => { root.freshIds = root.freshIds.filter(id => born.indexOf(id) < 0); t.destroy(); });
        t.start();
    }

    function open(a) {
        if (!a) return;
        if (a.kind === "media") Panels.toggle("player");
        else if (a.kind === "download" || a.kind === "downloaded") Qt.openUrlExternally("file://" + (a.path ? a.path.replace(/\/[^/]*$/, "") : downloads));
        else if (a.kind === "mic" || a.kind === "camera" || a.kind === "cast") Panels.open("control", "privacy");
        else if (a.kind === "bt") Panels.open("control", "bt");
        else if (a.kind === "phone") Panels.open("control", "phone");
        else if (a.kind === "vpn") Panels.open("control", "wifi");
        else Panels.toggle("live");
    }

    function act(id, key) {
        const a = list.find(x => x.id === id);
        if (!a) return;
        if (a.kind === "record") Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
        else if (a.kind === "cast") Privacy.stopCasts();
        else if (a.kind === "mic") Privacy.setMicBlocked(!Privacy.micBlocked);
        else if (a.kind === "timer") {
            const tid = parseInt(id.split(":")[1]);
            if (key === "more") timers = timers.map(t => t.id === tid ? Object.assign({}, t, { end: t.end + 60000, left: (t.left ?? 0) + 60000, total: t.total + 60000 }) : t);
            else if (key === "pause") timers = timers.map(t => t.id !== tid ? t
                : t.paused ? Object.assign({}, t, { paused: false, end: Date.now() + t.left })
                : Object.assign({}, t, { paused: true, left: Math.max(0, t.end - Date.now()) }));
            else timers = timers.filter(t => t.id !== tid);
        } else if (a.kind === "stopwatch") {
            const sw = Object.assign({}, stopwatch), t = Date.now();
            if (key === "pause") {
                if (sw.paused) { sw.start += t - sw.pausedAt; sw.paused = false; }
                else { sw.paused = true; sw.pausedAt = t; }
                stopwatch = sw;
            } else if (key === "lap") {
                const total = (sw.paused ? sw.pausedAt : t) - sw.start;
                sw.laps = [total - (sw.lapTotal ?? 0)].concat(sw.laps);
                sw.lapTotal = total;
                stopwatch = sw;
            } else stopwatch = null;
        } else if (a.kind === "job") {
            jobsProc.write(key + " " + id.split(":")[1] + "\n");
        } else if (a.kind === "copy") {
            if (a.pid) Quickshell.execDetached(["kill", String(a.pid)]);
            end(id);
        } else if (a.kind === "phone") {
            Phone.ring();
        } else if (a.kind === "downloaded") {
            if (key === "open") Qt.openUrlExternally("file://" + a.path);
            flashes = flashes.filter(f => f.id !== id);
        }
    }

    property var flashes: []
    function flash(a, ms) {
        const item = Object.assign({ priority: 20, progress: -1, actions: [], tone: "primary" }, a);
        flashes = flashes.filter(f => f.id !== item.id).concat([item]);
        const t = Qt.createQmlObject("import QtQuick; Timer { interval: " + (ms || 6000) + " }", root);
        t.triggered.connect(() => { root.flashes = root.flashes.filter(f => f.id !== item.id); t.destroy(); });
        t.start();
    }

    function push(json) {
        let a;
        try { a = JSON.parse(json); } catch (e) { return; }
        if (!a.id) return;
        const next = Object.assign({}, jobs);
        next[a.id] = Object.assign({ kind: "copy", icon: "file_copy", tone: "primary", priority: 70, progress: -2,
                                     actions: [{ icon: "close", label: "Отменить", key: "stop" }] }, next[a.id] ?? {}, a);
        jobs = next;
    }
    function end(id, doneTitle) {
        const a = jobs[id];
        const next = Object.assign({}, jobs);
        delete next[id];
        jobs = next;
        if (a && doneTitle) flash({ id: id + ":done", kind: "done", icon: "task_alt", title: doneTitle, text: a.title });
    }

    property var jobs: ({})
    Process {
        id: jobsProc
        running: !Panels.nested
        stdinEnabled: true
        command: [Paths.bin + "/nyri-jobs"]
        stdout: SplitParser {
            onRead: line => {
                let m;
                try { m = JSON.parse(line); } catch (e) { return; }
                const id = "job:" + m.id;
                if (m.op === "end") { root.end(id, "Готово"); return; }
                const total = m.total || 0, done = m.processed || 0;
                const pct = m.percent >= 0 ? m.percent / 100 : total > 0 ? done / total : -2;
                const detail = [m.value1, m.value2].filter(Boolean).map(v => v.replace(/^file:\/\//, "").split("/").pop());
                const next = Object.assign({}, root.jobs);
                next[id] = {
                    id, kind: "job", icon: /extract|распак/i.test(m.title) ? "folder_zip" : /удал|delet/i.test(m.title) ? "delete" : "file_copy",
                    tone: "primary", priority: 70, title: m.title || Apps.nameFor(m.app) || "Операция с файлами",
                    text: (m.suspended ? "Пауза · " : "") + (detail.join(" → ") || m.info || "")
                          + (m.speed > 0 ? " · " + root.size(m.speed) + "/с" : ""),
                    progress: pct,
                    actions: [{ icon: m.suspended ? "play_arrow" : "pause", label: m.suspended ? "Продолжить" : "Пауза", key: m.suspended ? "resume" : "suspend" },
                              { icon: "close", label: "Отменить", key: "cancel" }]
                };
                root.jobs = next;
            }
        }
    }

    property var timers: []
    property int nextTimer: 1
    property real now: Date.now()
    Timer {
        running: root.timers.length > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            const done = root.timers.filter(t => !t.paused && t.end <= root.now);
            if (!done.length) return;
            root.timers = root.timers.filter(t => t.paused || t.end > root.now);
            for (const t of done) {
                root.flash({ id: "timer-done:" + t.id, kind: "done", icon: "alarm", tone: "primary", priority: 90,
                             title: "Время вышло", text: t.label || root.fmtDuration(t.total) }, 12000);
                Quickshell.execDetached(["notify-send", "-a", "Таймер", "-i", "alarm-symbolic", "Время вышло", t.label || root.fmtDuration(t.total)]);
                Quickshell.execDetached(["sh", "-c", "pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/complete.oga"]);
            }
        }
    }
    property var stopwatch: null
    function startStopwatch() { if (!stopwatch) stopwatch = { start: Date.now(), paused: false, pausedAt: 0, laps: [], lapTotal: 0 }; }
    function fmtClock(ms) {
        const s = Math.max(0, Math.round(ms / 1000)), m = Math.floor(s / 60), r = s % 60;
        return m + ":" + String(r).padStart(2, "0");
    }

    function addTimer(seconds, label) {
        if (!(seconds > 0)) return;
        const t = { id: nextTimer++, label: label || "", end: Date.now() + seconds * 1000, total: seconds * 1000 };
        now = Date.now();
        timers = timers.concat([t]);
    }
    function parseDuration(s) {
        s = (s || "").toLowerCase().trim();
        let m = s.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
        if (m) return m[3] !== undefined ? +m[1] * 3600 + +m[2] * 60 + +m[3] : +m[1] * 60 + +m[2];
        let total = 0, any = false;
        const re = /(\d+(?:[.,]\d+)?)\s*(ч|час\S*|h\S*|м|мин\S*|m\S*|с|сек\S*|s\S*)?/g;
        while ((m = re.exec(s)) !== null) {
            if (!m[0].trim()) { re.lastIndex++; continue; }
            const v = parseFloat(m[1].replace(",", "."));
            const u = m[2] ?? "м";
            total += /^(ч|час|h)/.test(u) ? v * 3600 : /^(с|сек|s)/.test(u) ? v : v * 60;
            any = true;
        }
        return any ? Math.round(total) : 0;
    }
    function fmtDuration(ms) {
        const s = Math.round(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        return h ? h + " ч " + (m ? m + " мин" : "") : m ? m + " мин" + (r ? " " + r + " с" : "") : r + " с";
    }
    function size(b) {
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " ГБ" : b >= 1e6 ? (b / 1e6).toFixed(1) + " МБ" : Math.round(b / 1e3) + " КБ";
    }

    readonly property string downloads: Quickshell.env("XDG_DOWNLOAD_DIR") || Quickshell.env("HOME") + "/Downloads"
    FolderListModel {
        id: partial
        folder: "file://" + root.downloads
        nameFilters: ["*.part", "*.crdownload", "*.download", "*.partial", "*.opdownload"]
        showDirs: false
        showHidden: true
        onCountChanged: root.scanDownloads()
    }
    property var sizes: ({})
    property var lastSizes: ({})
    property var downloadList: []
    property var lastParts: []
    function scanDownloads() {
        const parts = [];
        const fresh = Date.now() - 120000;
        for (let i = 0; i < partial.count; i++)
            if (partial.get(i, "fileModified").getTime() > fresh || (sizes[partial.get(i, "filePath")] ?? 0) !== (lastSizes[partial.get(i, "filePath")] ?? -1))
                parts.push(partial.get(i, "filePath"));
        for (const p of lastParts)
            if (parts.indexOf(p) < 0) {
                const final = p.replace(/\.(part|crdownload|download|partial|opdownload)$/, "").replace(/\.[A-Za-z0-9]{6}$/, "");
                finished.check(final);
            }
        lastParts = parts;
        downloadList = parts.map(p => {
            const name = p.split("/").pop().replace(/\.(part|crdownload|download|partial|opdownload)$/, "");
            const got = sizes[p] ?? 0;
            return { id: "dl:" + p, kind: "download", path: p, icon: "downloading", tone: "primary", priority: 65,
                     title: name, text: got ? "Загружено " + root.size(got) : "Загрузка…", progress: -2,
                     actions: [{ icon: "folder_open", label: "Папка", key: "folder" }] };
        });
    }
    Timer {
        running: root.lastParts.length > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!sizer.running) { sizer.command = ["stat", "-c", "%s %n", ...root.lastParts]; sizer.running = true; } }
    }
    Process {
        id: sizer
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(" ");
                    if (i > 0) next[line.slice(i + 1)] = parseInt(line.slice(0, i));
                }
                root.lastSizes = root.sizes;
                root.sizes = next;
                root.scanDownloads();
            }
        }
    }
    Process {
        id: finished
        property string path: ""
        function check(p) { path = p; command = ["test", "-s", p]; running = true; }
        onExited: code => {
            if (code !== 0) return;
            root.flash({ id: "dl-done:" + path, kind: "downloaded", path, icon: "download_done", priority: 55,
                         title: "Загружено", text: path.split("/").pop(),
                         actions: [{ icon: "open_in_new", label: "Открыть", key: "open" }] }, 8000);
        }
    }

    FolderListModel {
        id: pacman
        folder: "file:///var/lib/pacman"
        nameFilters: ["db.lck"]
        showDirs: false
    }
    readonly property bool updating: pacman.count > 0

    property var vpnNames: []
    Process {
        running: true
        command: ["ip", "-o", "monitor", "link"]
        stdout: SplitParser { onRead: _ => vpnScan.restart() }
    }
    Timer { id: vpnScan; interval: 300; running: true; onTriggered: { vpnList.running = false; vpnList.running = true; } }
    Process {
        id: vpnList
        command: ["ip", "-j", "link", "show", "up"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.vpnNames = JSON.parse(text)
                        .filter(l => /^(tun|tap|wg|tailscale|nordlynx|proton|mullvad|zt|ppp|utun|singbox|sing-box|mihomo|clash|Meta|amn|awg|outline)/i.test(l.ifname)
                                     || (l.link_type === "none" && l.ifname !== "lo"))
                        .map(l => l.ifname);
                } catch (e) {}
            }
        }
    }

    readonly property var btDevices: Bt.connected.filter(d => d.batteryAvailable || /audio|headset|headphone/.test(d.icon ?? ""))
}

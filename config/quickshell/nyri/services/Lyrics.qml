pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int wanted: 0
    readonly property var player: Media.player
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property real length: player?.length ?? 0
    readonly property string key: artist + "\u0001" + title

    property var cache: ({})
    readonly property var entry: cache[key] ?? null
    readonly property var lines: entry ? (entry.synced.length ? entry.synced : entry.plain.map(t => ({ t: -1, text: t }))) : []
    readonly property bool synced: (entry?.synced.length ?? 0) > 0
    readonly property bool loading: fetch.running
    readonly property bool none: entry?.none ?? false

    property real basePos: 0
    property real baseAt: Date.now()
    property real now: Date.now()
    readonly property real position: player?.isPlaying ? basePos + (now - baseAt) / 1000 : basePos
    Connections {
        target: root.player
        function onPositionChanged() { root.basePos = root.player.position; root.baseAt = Date.now(); }
    }
    Timer {
        running: root.wanted > 0 && root.synced && (root.player?.isPlaying ?? false)
        interval: 200
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.now - root.baseAt > 2000) root.player.positionChanged();
        }
    }
    readonly property int current: {
        if (!synced) return -1;
        const p = position + 0.25;
        let i = -1;
        for (let k = 0; k < lines.length; k++) { if (lines[k].t <= p) i = k; else break; }
        return i;
    }
    readonly property real lineProgress: {
        const i = current;
        if (i < 0) return 0;
        const t0 = lines[i].t;
        const t1 = lines[i + 1]?.t ?? (t0 + 4);
        return Math.max(0, Math.min(1, (position + 0.25 - t0) / Math.max(0.5, Math.min(t1 - t0, 8))));
    }
    function seek(i) {
        const l = lines[i];
        if (l && l.t >= 0 && player?.canSeek) { player.position = l.t; basePos = l.t; baseAt = Date.now(); }
    }

    property bool queued: false
    onKeyChanged: maybeFetch()
    Component.onCompleted: maybeFetch()
    function maybeFetch() {
        if (!title || cache[key]) { queued = false; return; }
        if (fetch.running) { queued = true; return; }
        queued = false;
        const q = s => encodeURIComponent(s);
        let url = "https://lrclib.net/api/get?track_name=" + q(title) + "&artist_name=" + q(artist);
        if (album) url += "&album_name=" + q(album);
        if (length > 0) url += "&duration=" + Math.round(length);
        fetch.asked = key;
        fetch.search = false;
        fetch.command = ["curl", "-s", "-m", "8", "-A", "Nyri (github.com/yzewe/Nyri)", url];
        fetch.running = true;
    }

    function parse(obj) {
        const synced = [], plain = [];
        for (const line of (obj?.syncedLyrics ?? "").split("\n")) {
            const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
            if (m) synced.push({ t: +m[1] * 60 + +m[2], text: m[3] });
        }
        for (const line of (obj?.plainLyrics ?? "").split("\n")) plain.push(line);
        return { synced, plain: plain.filter((l, i) => l.trim() || (i > 0 && plain[i - 1].trim())), none: !synced.length && !plain.some(l => l.trim()) };
    }

    function norm(s) {
        return (s || "").toLowerCase().replace(/ё/g, "е").replace(/\(.*?\)|\[.*?\]/g, " ")
            .replace(/prod\.?.*$/, " ").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
    }
    function matches(d) {
        const a = norm(artist), t = norm(title);
        const da = norm(d.artistName), dt = norm(d.trackName);
        const artistOk = !a || da.includes(a) || a.includes(da) || dt.includes(a);
        const titleOk = dt === t || dt.replace(a, "").trim() === t || (t.length > 3 && dt.includes(t) && dt.length - t.length <= a.length + 3);
        const lengthOk = !(length > 0 && d.duration > 0) || Math.abs(d.duration - length) <= 8;
        return artistOk && titleOk && lengthOk;
    }

    Timer { id: retry; interval: 2500; onTriggered: fetch.running = true }

    Process {
        id: fetch
        property string asked: ""
        property bool search: false
        property int tries: 0
        onRunningChanged: if (!running && root.queued) Qt.callLater(root.maybeFetch)
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try { data = JSON.parse(text); } catch (e) {}
                if (data && !Array.isArray(data) && data.statusCode == 503 && fetch.tries < 2) {
                    fetch.tries++;
                    retry.restart();
                    return;
                }
                fetch.tries = 0;
                if (Array.isArray(data)) {
                    const ok = data.filter(d => root.matches(d));
                    data = ok.find(d => d.syncedLyrics) ?? ok[0] ?? null;
                } else if (data && !root.matches(data)) {
                    data = null;
                }
                const got = data && (data.syncedLyrics || data.plainLyrics) ? root.parse(data) : null;
                if (!got && !fetch.search) {
                    fetch.search = true;
                    fetch.command = ["curl", "-s", "-m", "8", "-A", "Nyri (github.com/yzewe/Nyri)",
                                     "https://lrclib.net/api/search?q=" + encodeURIComponent(root.artist + " " + root.title)];
                    Qt.callLater(() => fetch.running = true);
                    return;
                }
                const next = Object.assign({}, root.cache);
                next[fetch.asked] = got ?? { synced: [], plain: [], none: true };
                root.cache = next;
                if (root.queued || root.key !== fetch.asked) Qt.callLater(root.maybeFetch);
            }
        }
    }
}

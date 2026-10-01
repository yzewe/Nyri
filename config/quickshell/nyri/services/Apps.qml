pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function launcherPriority(entry) {
        const id = (entry.id ?? "").toLowerCase();
        if (id.startsWith("userapp-") || id.includes("url-handler")) return 0;
        return 10 + (entry.icon ? 1 : 0);
    }

    function launcherKey(name) {
        const key = name.toLowerCase();
        return key.startsWith("ayugram") ? "ayugram" : key;
    }

    readonly property var all: {
        const byName = new Map();
        for (const entry of DesktopEntries.applications.values) {
            const id = (entry.id ?? "").toLowerCase();
            const name = (entry.name ?? "").trim();
            if (entry.noDisplay || !name || id.startsWith("userapp-") ||
                (id.includes("ayugram") && name.toLowerCase().startsWith("quit ")))
                continue;
            const key = launcherKey(name);
            const previous = byName.get(key);
            if (!previous || launcherPriority(entry) > launcherPriority(previous))
                byName.set(key, entry);
        }
        return [...byName.values()];
    }
    property var counts: ({})
    property var iconFiles: ({})
    function loadIcons(contents) {
        try { iconFiles = JSON.parse(contents); } catch (e) {}
    }
    Component.onCompleted: loadIcons(iconsFile.text())

    Process {
        command: [Paths.bin + "/nyri-icon-index"]
        running: true
        onExited: iconsFile.reload()
    }
    FileView {
        id: iconsFile
        path: Paths.state + "/icons.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loadIcons(text())
    }

    function iconFor(appId, title) {
        if (appId === "org.quickshell")
            return "preferences-system";
        const id = (appId ?? "").toLowerCase();
        if (title) {
            const name = title.toLowerCase().trim();
            const entry = all.find(e => {
                const appName = (e.name ?? "").toLowerCase();
                return appName.length > 3 && name.includes(appName);
            });
            if (entry?.icon) return entry.icon;
            if (name.includes("termius")) return "termius";
            if (name.includes("ayugram")) return "telegram";
        }
        const icon = DesktopEntries.heuristicLookup(appId)?.icon;
        if (icon) return icon;
        const entry = all.find(e => {
            const entryId = (e.id ?? "").toLowerCase().replace(/\.desktop$/, "");
            return entryId === id || entryId.endsWith("." + id) || id.endsWith("." + entryId);
        });
        if (entry?.icon) return entry.icon;
        if (id.includes("termius")) return "termius";
        if (id.includes("ayugram")) return "telegram";
        return appId || "application-x-executable";
    }

    function fileForIcon(icon) {
        if (!icon) return "";
        const raw = String(icon);
        if (raw.startsWith("file:") || raw.startsWith("image:")) return raw;
        if (raw.startsWith("/")) return "file://" + raw;
        if (raw.startsWith("qrc:/nix/store/")) return "file://" + raw.slice(4);
        const key = raw.toLowerCase().replace(/-symbolic$/, "");
        const file = iconFiles[key] || iconFiles[raw.toLowerCase()];
        if (file) return "file://" + file;
        const path = Quickshell.iconPath(raw);
        if (!path || path === raw) return "";
        if (path.startsWith("qrc:/nix/store/")) return "file://" + path.slice(4);
        if (path.startsWith("/")) return "file://" + path;
        if (path.startsWith("file:")) return path;
        return "";
    }

    function iconSourceFor(appId, title) {
        const icon = iconFor(appId, title);
        if (icon.toLowerCase() === "termius-app" || icon.toLowerCase() === "termius")
            return "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/scalable/apps/termius-app.svg";
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.startsWith("qrc:/nix/store/")) return "file://" + icon.slice(4);
        if (icon.startsWith("file:") || icon.startsWith("image:")) return icon;
        if (icon === "application-x-executable") return "";
        const file = iconFiles[icon.toLowerCase()];
        if (file) return "file://" + file;
        const path = Quickshell.iconPath(icon);
        return path.startsWith("qrc:/nix/store/") ? "file://" + path.slice(4) : path;
    }

    function nameFor(appId) {
        if (appId === "org.quickshell")
            return "Настройки Nyri";
        return DesktopEntries.heuristicLookup(appId)?.name ?? appId ?? "";
    }

    readonly property var index: all.map(e => {
        const name = e.name.toLowerCase();
        const id = (e.id ?? "").toLowerCase().replace(/\.desktop$/, "");
        return { e, key: e.id, name, id, words: name.split(/[\s\-_.]+/),
                 extra: [e.genericName, e.comment, e.id, ...(e.keywords ?? [])].join(" ").toLowerCase(),
                 terms: [...new Set([name, ...name.split(/[\s\-_.]+/), id, ...id.split(/[\s\-_.]+/)])].filter(t => t) };
    })

    function rank(x) {
        return Math.log((counts[x.key] ?? 0) + 1);
    }

    function score(x, q) {
        const name = x.name;
        if (name.startsWith(q)) return 100;
        if (x.words.some(w => w.startsWith(q))) return 80;
        if (name.includes(q)) return 60;
        if (x.extra.includes(q)) return 40;
        let i = 0, gaps = 0, last = -1;
        for (const ch of q) {
            const at = name.indexOf(ch, i);
            if (at < 0) return 0;
            if (last >= 0) gaps += at - last - 1;
            last = at;
            i = at + 1;
        }
        return Math.max(1, 30 - gaps);
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return index.slice().sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name)).map(x => x.e);
        return index
            .map(x => ({ x, s: score(x, q) + rank(x) * 6 }))
            .filter(r => r.s > rank(r.x) * 6)
            .sort((a, b) => b.s - a.s || a.x.name.localeCompare(b.x.name))
            .map(r => r.x.e);
    }

    function launch(entry) {
        const next = Object.assign({}, counts);
        next[entry.id] = (next[entry.id] ?? 0) + 1;
        counts = next;
        store.setText(JSON.stringify(next));

        const cmd = entry.runInTerminal ? ["kitty", "-e", ...entry.command] : entry.command;
        Quickshell.execDetached({ command: cmd, workingDirectory: entry.workingDirectory || Quickshell.env("HOME") });
    }

    FileView {
        id: store
        path: Paths.state + "/launches.json"
        onLoaded: {
            try { root.counts = JSON.parse(text()); } catch (e) {}
        }
    }
}

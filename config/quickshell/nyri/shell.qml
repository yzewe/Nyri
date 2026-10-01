import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.bar
import qs.osd
import qs.launcher
import qs.notifications
import qs.control
import qs.session
import qs.clipboard
import qs.wallpaper
import qs.lock
import qs.switcher
import qs.popouts
import qs.settings
import qs.overlays
import qs.snip
import qs.polkit
import qs.dock

ShellRoot {
    Wallpaper {}
    Bar {}
    Dock {}
    Osd {}
    Popups {}
    Launcher {}
    ControlCenter {}
    Session {}
    Clipboard {}
    Picker {}
    LockScreen {}
    Idle {}
    Switcher { id: altTab }
    Dashboard {}
    PowerPopout {}
    WindowMenu {}
    TrayPopout {}
    LivePopout {}
    PlayerPopout {}
    Settings { id: settingsApp }
    Crosshair {}
    SnipMenu {}
    PolkitDialog { id: polkit }
    ScreenCorners {}
    DemoPointer {}

    Component.onCompleted: { ScreenTime.since; Schedule.on; Privacy.active; }

    Connections {
        target: Quickshell
        function onReloadFailed(error) {
            Quickshell.execDetached(["notify-send", "-a", "nyri", "-u", "critical", "-i", "dialog-error",
                "Ошибка в шелле", error.split("\n")[0]]);
        }
    }

    IpcHandler {
        target: "nyri"

        function toggle(panel: string): void { Panels.anchorW = 0; Panels.toggle(panel); }
        function close(): void { Panels.close(); }
        function open(panel: string, page: string): void { Panels.anchorW = 0; Panels.open(panel, page); }
        function osd(kind: string): void { Osd.show(kind); }
        function state(): string { return JSON.stringify({ panel: Panels.current, tab: Panels.tab, screen: Panels.screen?.name ?? null, output: Compositor.focusedOutput, locked: Lock.locked, windows: Object.keys(Compositor.windows).length, workspaces: Compositor.workspaces.length, screenTime: { app: ScreenTime.current, away: ScreenTime.away, focused: Compositor.focusedWindow?.app_id ?? null } }); }
        function lock(): void { Lock.lock(); }
        function unlockNested(): void { if (Panels.nested) Lock.unlockRequested(); }
        function polkitDemo(): void { if (Panels.nested) polkit.showDemo(); }
        function demoPointer(x: real, y: real): void { if (!Demo.allowed) return; Demo.pointer = true; Demo.x = x; Demo.y = y; }
        function demoHidePointer(): void { Demo.pointer = false; }
        function demoClick(): void { if (Demo.allowed) Demo.clicks++; }
        function demoMenu(key: string): void { if (Demo.allowed) Demo.menuRequested(key); }
        function demoMenuClose(): void { if (Demo.allowed) Demo.menuClose(); }
        function demoLook(key: string, index: int): void { if (Demo.allowed) Demo.lookRequested(key, index); }
        function demoDrag(key: string, x: real, y: real): void { if (Demo.allowed) Demo.dragRequested(key, x, y); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
        function deskEdit(): void { Panels.deskEdit = !Panels.deskEdit; }
        function dark(): void { Toggles.toggleDark(); }
        function settings(): void { settingsApp.toggle(); }
        function settingsAt(page: string): void { Panels.openSettings(page); }
        function crosshair(): void { Toggles.crosshair = !Toggles.crosshair; }
        function autohide(): void { Config.o.bar.autohide = !Config.o.bar.autohide; }
        function recording(on: bool): void { Toggles.recording = on; if (on) Toggles.recordingSince = Date.now(); }
        function switcher(dir: string): void { altTab.step(dir === "prev" ? -1 : 1); }
        function activity(json: string): void { Activities.push(json); }
        function activityEnd(id: string, done: string): void { Activities.end(id, done); }
        function timer(spec: string, label: string): void { Activities.addTimer(Activities.parseDuration(spec), label); }
        function privacy(): void { Config.o.privacy.mode = !Config.o.privacy.mode; }
    }
}

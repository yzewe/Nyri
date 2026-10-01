pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property string current: ""
    readonly property bool barBottom: Config.o.bar.position === "bottom"
    readonly property real barReach: 12 + 40
    property bool deskEdit: false
    property string prefill: ""
    property string tab: ""
    property bool snipping: false
    property string snipTab: ""
    property real anchorX: 0
    property real anchorW: 0

    readonly property bool nested: Quickshell.env("NYRI_NESTED") === "1"

    readonly property var screen: {
        const name = Compositor.focusedOutput;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    function toggleFrom(name, item, page) {
        const p = item.mapToItem(null, 0, 0);
        anchorX = p.x;
        anchorW = item.width;
        toggle(name, page);
    }

    PersistentProperties {
        id: kept
        reloadableId: "nyri-settings"
        property bool open: false
        property string page: "look"
    }
    property alias settingsOpen: kept.open
    function openSettings(page) {
        current = "";
        if (page) settingsPage = page;
        settingsOpen = true;
    }
    property alias settingsPage: kept.page

    PersistentProperties {
        id: keptStudio
        reloadableId: "nyri-studio"
        property bool open: false
    }
    property alias studioOpen: keptStudio.open

    function toggle(name, page) {
        if (name === "snip") { snipTab = page ?? ""; snipping = !snipping; return; }
        if (name === "wallpaper") { current = ""; studioOpen = !studioOpen; return; }
        if (current === name && (page === undefined || tab === page)) {
            current = "";
        } else {
            tab = page ?? "";
            current = name;
        }
    }

    function open(name, page) {
        if (name === "snip") { snipTab = page ?? ""; snipping = true; return; }
        if (name === "wallpaper") { current = ""; studioOpen = true; return; }
        tab = page ?? "";
        current = name;
    }

    function close() {
        if (snipping) { snipping = false; return; }
        current = "";
    }
}

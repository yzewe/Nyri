pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    property bool crosshair: false

    property bool recording: false
    property real recordingSince: 0

    property bool capsLock: false
    property bool capsReady: false
    Process {
        running: true
        command: [Paths.bin + "/nyri-capswatch"]
        stdout: SplitParser {
            onRead: line => {
                root.capsLock = line.trim() === "1";
                if (root.capsReady) Osd.show("caps");
                root.capsReady = true;
            }
        }
    }

    property bool caffeine: false

    readonly property bool nightLight: Config.o.night.mode !== "off"
    function setNightLight(on) { Config.o.night.mode = on ? "on" : "off"; }
    Process {
        running: root.nightLight
        command: Config.o.night.mode === "auto"
            ? ["wlsunset", "-t", String(Config.o.night.temp), "-T", "6500",
               "-l", String(Config.o.weather.lat), "-L", String(Config.o.weather.lon)]
            : ["wlsunset", "-t", String(Config.o.night.temp), "-T", String(Config.o.night.temp + 1),
               "-s", "00:00", "-S", "23:59", "-d", "1"]
    }

    readonly property bool dark: Colors.mode !== "light"
    function setMode(mode) {
        Quickshell.execDetached(["env", "NYRI_MODE=" + mode, Paths.bin + "/nyri-theme"]);
    }
    function toggleDark() { setMode(dark ? "light" : "dark"); }
}

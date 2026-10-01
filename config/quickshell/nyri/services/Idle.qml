import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

Scope {
    id: root

    readonly property bool battery: UPower.onBattery

    readonly property var cfg: Config.o.idle
    readonly property int screenMinutes: battery ? cfg.screenBattery : cfg.screenAc
    readonly property int suspendMinutes: battery ? cfg.suspendBattery : cfg.suspendAc

    IdleMonitor {
        enabled: root.screenMinutes > 0
        timeout: root.screenMinutes * 60
        onIsIdleChanged: {
            if (Compositor.isHyprland) Quickshell.execDetached(["hyprctl", "dispatch", "dpms", isIdle ? "off" : "on"]);
            else if (isIdle) Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
        }
    }

    IdleMonitor {
        enabled: root.cfg.lock > 0 && !Panels.nested
        timeout: root.cfg.lock * 60
        onIsIdleChanged: if (isIdle) Lock.lock()
    }

    IdleMonitor {
        enabled: !Panels.nested && root.suspendMinutes > 0
        timeout: root.suspendMinutes * 60
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "suspend"])
    }

    Process {
        running: !Panels.nested
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => { if (line.includes("PrepareForSleep (true")) Lock.lock() }
        }
    }

    Process {
        running: !Panels.nested && root.cfg.lockOnLogin && !Compositor.isHyprland
        command: ["sh", "-c", "m=\"$XDG_RUNTIME_DIR/nyri-locked-once\"; [ -e \"$m\" ] && exit 1; touch \"$m\""]
        onExited: code => { if (code === 0) Lock.lock() }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var roles: ({})
    property string wallpaper: ""
    property string mode: "dark"
    property string scheme: "scheme-content"

    function role(name, fallback) {
        return roles[name] ?? fallback;
    }

    function loadTheme(contents) {
        try {
            const data = JSON.parse(contents);
            root.roles = data.colors ?? {};
            root.wallpaper = data.wallpaper ?? "";
            root.mode = data.mode ?? "dark";
            root.scheme = data.scheme ?? "scheme-content";
            const bin = (Quickshell.env("HOME") || "") + "/nyri/bin/nyri-greetd";
            Quickshell.execDetached([bin, "publish"]);
        } catch (e) {
            console.warn("theme.json unreadable:", e);
        }
    }

    FileView {
        id: themeFile
        path: (Quickshell.env("NYRI_STATE") || Quickshell.env("HOME") + "/.local/state/nyri") + "/theme.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loadTheme(text())
    }

    Component.onCompleted: loadTheme(themeFile.text())

    property color m3primary: role("primary", "#ffb68c")
    property color m3onPrimary: role("on_primary", "#532200")
    property color m3primaryContainer: role("primary_container", "#e57a32")
    property color m3onPrimaryContainer: role("on_primary_container", "#000000")
    property color m3primaryFixed: role("primary_fixed", "#ffdbc9")
    property color m3primaryFixedDim: role("primary_fixed_dim", "#ffb68c")
    property color m3onPrimaryFixed: role("on_primary_fixed", "#331200")

    property color m3secondary: role("secondary", "#e5bfaa")
    property color m3onSecondary: role("on_secondary", "#432b1d")
    property color m3secondaryContainer: role("secondary_container", "#6b3e22")
    property color m3onSecondaryContainer: role("on_secondary_container", "#ffdbc9")

    property color m3tertiary: role("tertiary", "#c7ce44")
    property color m3onTertiary: role("on_tertiary", "#2f3300")
    property color m3tertiaryContainer: role("tertiary_container", "#8f9500")
    property color m3onTertiaryContainer: role("on_tertiary_container", "#000000")

    property color m3error: role("error", "#ffb4ab")
    property color m3onError: role("on_error", "#690005")
    property color m3errorContainer: role("error_container", "#93000a")
    property color m3onErrorContainer: role("on_error_container", "#ffdad6")

    property color m3surface: role("surface", "#1a110c")
    property color m3onSurface: role("on_surface", "#f0dfd7")
    property color m3onSurfaceVariant: role("on_surface_variant", "#dbc1b3")
    property color m3surfaceContainerLowest: role("surface_container_lowest", "#140c08")
    property color m3surfaceContainerLow: role("surface_container_low", "#231914")
    property color m3surfaceContainer: role("surface_container", "#281d18")
    property color m3surfaceContainerHigh: role("surface_container_high", "#332822")
    property color m3surfaceContainerHighest: role("surface_container_highest", "#3e322c")
    property color m3surfaceBright: role("surface_bright", "#423630")
    property color m3inverseSurface: role("inverse_surface", "#f2dfd5")
    property color m3inverseOnSurface: role("inverse_on_surface", "#392e28")

    property color m3outline: role("outline", "#a48c7f")
    property color m3outlineVariant: role("outline_variant", "#564338")
    property color m3shadow: role("shadow", "#000000")
    property color m3scrim: role("scrim", "#000000")
}

pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property string kind: ""
    property bool shown: false

    function show(k) {
        if (k === "brightness")
            Brightness.refresh();
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.shown = false
    }

    property bool layoutReady: false
    Connections {
        target: Compositor
        function onLayoutShortChanged() {
            if (root.layoutReady)
                root.show("layout");
            root.layoutReady = true;
        }
    }
}

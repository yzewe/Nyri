import QtQuick
import Quickshell.Widgets
import qs.theme

IconImage {
    id: root

    layer.enabled: Colors.mode === "light"
    layer.effect: ShaderEffect {
        property color ink: Colors.m3onSurfaceVariant
        fragmentShader: Qt.resolvedUrl("../lib/shaders/ink.frag.qsb")
    }
}

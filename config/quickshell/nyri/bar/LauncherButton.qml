import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    implicitWidth: 40
    implicitHeight: 40

    property real intro: 0
    scale: intro
    SpatialAnim on intro { id: introAnim; running: false; from: 0; to: 1; speed: "slow" }
    function playIntro() { intro = 0; introAnim.restart(); }
    function holdIntro() { introAnim.stop(); intro = 0; }
    Component.onCompleted: if (!Lock.locked) playIntro()
    Connections {
        target: Lock
        function onLockedChanged() { if (Lock.locked) root.holdIntro(); else root.playIntro(); }
    }

    MaterialShape {
        id: shape
        anchors.fill: parent
        shape: mouse.pressed ? "softBurst" : mouse.containsMouse ? "sunny" : "cookie9Sided"
        color: mouse.containsMouse ? Colors.m3primary : Colors.m3primaryContainer
        rotation: mouse.containsMouse ? 60 : 0

        Behavior on rotation { SpatialAnim { speed: "slow" } }
    }

    MIcon {
        anchors.centerIn: parent
        icon: "apps"
        size: 20
        fill: 1
        color: mouse.containsMouse ? Colors.m3onPrimary : Colors.m3onPrimaryContainer
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggleFrom("launcher", root)
    }
}

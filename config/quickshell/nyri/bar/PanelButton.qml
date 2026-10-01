import QtQuick
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    implicitWidth: 40
    implicitHeight: 40

    property real intro: 0
    scale: intro
    SequentialAnimation on intro {
        id: introAnim
        running: false
        PauseAnimation { duration: 480 }
        SpatialAnim { from: 0; to: 1; speed: "slow" }
    }
    function playIntro() { intro = 0; introAnim.restart(); }
    function holdIntro() { introAnim.stop(); intro = 0; }
    Component.onCompleted: if (!Lock.locked) playIntro()
    Connections {
        target: Lock
        function onLockedChanged() { if (Lock.locked) root.holdIntro(); else root.playIntro(); }
    }

    readonly property bool open: Panels.current === "control"

    MaterialShape {
        anchors.fill: parent
        shape: mouse.pressed ? "softBurst" : (mouse.containsMouse || root.open) ? "clover8Leaf" : "clover4Leaf"
        color: (mouse.containsMouse || root.open) ? Colors.m3primary : Colors.m3secondaryContainer
        rotation: root.open ? 45 : mouse.containsMouse ? -30 : 0

        Behavior on rotation { SpatialAnim { speed: "slow" } }
    }

    MIcon {
        anchors.centerIn: parent
        icon: "tune"
        size: 20
        fill: 1
        color: (mouse.containsMouse || root.open) ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggleFrom("control", root)
    }
}

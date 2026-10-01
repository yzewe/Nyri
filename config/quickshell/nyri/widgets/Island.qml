import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services

Item {
    id: root

    default property alias content: row.data
    property color color: Colors.m3surfaceContainer
    property int padding: 4
    property alias spacing: row.spacing
    property string widthSpeed: "default"
    property int introIndex: 0
    property real intro: 0

    implicitHeight: 40
    implicitWidth: row.implicitWidth + padding * 2
    width: grow.value
    height: implicitHeight

    SpringValue {
        id: grow
        target: root.implicitWidth
        damping: root.widthSpeed === "fast" ? 0.9 : 0.62
        stiffness: root.widthSpeed === "fast" ? 600 : 420
        epsilon: 0.2
    }

    transform: Translate { y: (1 - root.intro) * (Panels.barBottom ? 64 : -64) }
    opacity: Math.min(1, root.intro * 2)

    SequentialAnimation {
        id: introAnim
        PauseAnimation { duration: 120 + root.introIndex * 70 }
        SpatialAnim { target: root; property: "intro"; from: 0; to: 1; speed: "slow" }
    }
    function playIntro() { intro = 0; introAnim.restart(); }
    function holdIntro() { introAnim.stop(); intro = 0; }
    Component.onCompleted: if (!Lock.locked) playIntro()
    Connections {
        target: Lock
        function onLockedChanged() { if (Lock.locked) root.holdIntro(); else root.playIntro(); }
    }

    readonly property string barStyle: Config.o.bar.style
    readonly property bool plain: root.color === Colors.m3surfaceContainer
    property bool split: false
    readonly property bool bare: (barStyle === "strip" && plain) || (barStyle === "chips" && split)

    RectangularShadow {
        visible: root.barStyle !== "strip" && !root.bare
        anchors.fill: bg
        radius: bg.radius
        offset.y: 2
        blur: 8
        color: Qt.alpha(Colors.m3shadow, 0.35)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: root.bare ? "transparent" : root.color

        Behavior on color { ColorAnim {} }
    }

    Item {
        anchors.fill: parent
        clip: true

        Row {
            id: row
            x: root.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
        }
    }
}

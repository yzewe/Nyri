import QtQuick
import QtQuick.Effects
import qs.theme

Item {
    id: root

    default property alias content: body.data
    property color color: Colors.m3surfaceContainer
    property real radius: Shape.extraLarge
    property int elevation: 2
    property alias clip: body.clip

    RectangularShadow {
        anchors.fill: bg
        visible: root.elevation > 0
        radius: bg.radius
        offset.y: [0, 1, 2, 4, 6, 8][root.elevation]
        blur: [0, 3, 8, 14, 20, 28][root.elevation]
        color: Qt.alpha(Colors.m3shadow, 0.3)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.color

        Behavior on color { ColorAnim {} }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onWheel: event => event.accepted = false
    }

    Item {
        id: body
        anchors.fill: parent
    }
}

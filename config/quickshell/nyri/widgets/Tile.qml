import QtQuick
import qs.theme

Item {
    id: root

    property string icon
    property string label
    property string sublabel: ""
    property bool checked: false
    property bool details: false
    signal clicked
    signal secondaryClicked
    signal detailsClicked

    implicitHeight: 64

    scale: squish.value
    SpringValue { id: squish; target: tileLayer.pressed ? 0.95 : 1; damping: 0.5; stiffness: 800; epsilon: 0.001 }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.checked ? height / 2 : Shape.largeIncreased
        color: root.checked ? Colors.m3primary : Colors.m3surfaceContainerHighest

        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { ColorAnim {} }

        StateLayer {
            id: tileLayer
            radius: bg.radius
            color: root.checked ? Colors.m3onPrimary : Colors.m3onSurface
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? root.secondaryClicked() : root.clicked()
        }
    }

    Item {
        id: more
        visible: root.details
        anchors.right: parent.right
        width: 44
        height: parent.height

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 28
            color: root.checked ? Colors.m3onPrimary : Colors.m3outlineVariant
            opacity: 0.4
        }

        MIcon {
            anchors.centerIn: parent
            icon: "chevron_right"
            size: 20
            color: root.checked ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailsClicked()
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        width: parent.width - 28 - (root.details ? 36 : 0)
        spacing: 8

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: 22
            fill: root.checked ? 1 : 0
            color: root.checked ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30

            FlowText {
                width: parent.width
                elide: Text.ElideRight
                textStyle: Type.labelLargeEmph
                color: root.checked ? Colors.m3onPrimary : Colors.m3onSurface
                text: root.label
            }

            FlowText {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                textStyle: Type.labelMedium
                color: root.checked ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                opacity: 0.85
                text: root.sublabel
            }
        }
    }
}

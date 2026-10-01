import QtQuick
import qs.theme

Item {
    id: root

    property int length: 0
    property int max: 14
    property real size: 14
    property color color: Colors.m3primary
    property real spacing: 5
    readonly property int fit: width > size ? Math.max(1, Math.floor((width + spacing) / (size + spacing))) : max

    readonly property var pool: ["cookie4Sided", "cookie6Sided", "clover4Leaf", "sunny", "pentagon", "gem",
                                 "puffy", "flower", "diamond"]

    clip: true

    onLengthChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        while (chars.count < length)
            chars.append({ shape: pool[Math.floor(Math.random() * pool.length)] });
        while (chars.count > length)
            chars.remove(chars.count - 1);
    }

    ListModel { id: chars }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: row.width > root.width ? root.width - row.width : (root.width - row.width) / 2
        spacing: root.spacing

    Repeater {
        model: chars

        Item {
            id: slot
            required property int index
            required property string shape
            readonly property bool shown: index >= chars.count - root.fit

            width: shown ? root.size : 0
            height: root.size
            visible: shown

            property bool born: false
            Component.onCompleted: Qt.callLater(() => slot.born = true)
            SpringValue { id: pop; target: slot.born ? 1 : 0; damping: 0.78; stiffness: 520 }

            MaterialShape {
                anchors.fill: parent
                anchors.margins: 2
                shape: slot.shape
                color: root.color
                scale: 0.82 + 0.18 * Math.max(0, Math.min(1, pop.value))
            }
        }
    }
    }
}

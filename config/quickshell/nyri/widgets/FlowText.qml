import QtQuick
import qs.theme

Item {
    id: root

    property string text
    property var textStyle: Type.bodyMedium
    property color color: Colors.m3onSurface
    property int elide: Text.ElideNone
    property int horizontalAlignment: Text.AlignLeft
    property real rightPadding: 0
    property real maxWidth: Infinity
    property bool animate: true
    readonly property bool sized: elide !== Text.ElideNone

    property bool onA: true
    readonly property Text current: onA ? a : b
    readonly property Text previous: onA ? b : a

    SpringValue { id: t; target: 1; damping: 0.78; stiffness: 520; epsilon: 0.002 }
    TextMetrics { id: natural; font: root.current.font; text: root.current.text }
    SpringValue { id: w; target: Math.max(0, Math.min(root.maxWidth, Math.ceil(natural.advanceWidth) + root.rightPadding)); damping: 0.8; stiffness: 520; epsilon: 0.2 }

    implicitWidth: w.value
    implicitHeight: a.implicitHeight
    clip: t.running

    Component.onCompleted: { a.text = text; w.value = w.target; }

    onTextChanged: {
        if (current.text === text) return;
        if (!animate) {
            a.text = text;
            b.text = text;
            w.value = w.target;
            return;
        }
        previous.text = text;
        onA = !onA;
        t.value = 0;
        t.running = true;
    }

    readonly property real p: Math.max(0, Math.min(1.2, t.value))
    readonly property real travel: height * 0.7

    MText {
        id: a
        width: root.sized ? Math.max(0, root.width - root.rightPadding) : implicitWidth
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
        textStyle: root.textStyle
        color: root.color
        y: root.onA ? (1 - root.p) * root.travel : -root.p * root.travel
        opacity: root.onA ? Math.min(1, root.p * 1.4) : Math.max(0, 1 - root.p * 1.6)
    }

    MText {
        id: b
        width: root.sized ? Math.max(0, root.width - root.rightPadding) : implicitWidth
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
        textStyle: root.textStyle
        color: root.color
        y: !root.onA ? (1 - root.p) * root.travel : -root.p * root.travel
        opacity: !root.onA ? Math.min(1, root.p * 1.4) : Math.max(0, 1 - root.p * 1.6)
    }
}

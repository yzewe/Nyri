import QtQuick
import qs.theme

Row {
    id: root

    property string text
    property var textStyle: Type.bodyMedium
    property color color: Colors.m3onSurface
    property real pixelSize: textStyle.size
    property int weight: textStyle.weight
    property string speed: "fast"

    Repeater {
        model: root.text.length

        Item {
            id: slot

            required property int index
            readonly property string ch: root.text.charAt(index)
            property string shown: ch
            property string previous: ""
            property real t: 1

            width: now.implicitWidth
            height: now.implicitHeight
            clip: true

            Behavior on width { SpatialAnim { speed: "fast" } }

            onChChanged: {
                previous = shown;
                shown = ch;
                roll.restart();
            }

            SpatialAnim {
                id: roll
                target: slot
                property: "t"
                from: 0
                to: 1
                speed: root.speed
            }

            component Glyph: Text {
                font.family: Type.family
                font.pixelSize: root.pixelSize
                font.variableAxes: ({ "wght": root.weight, "ROND": root.textStyle.rond ?? 0 })
                font.features: ({ "tnum": 1 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                color: root.color
            }

            Glyph {
                text: slot.previous
                y: -slot.t * slot.height * 0.9
                opacity: 1 - Math.min(1, slot.t * 1.6)
            }

            Glyph {
                id: now
                text: slot.shown
                y: (1 - slot.t) * slot.height * 0.9
                opacity: Math.min(1, slot.t * 1.6)
            }
        }
    }
}

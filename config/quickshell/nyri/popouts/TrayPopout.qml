import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Surface {
    id: root

    name: "tray"
    keyboard: false

    readonly property var items: SystemTray.items.values.slice(4)
    TrayContextMenu { id: contextMenu; hostWindow: root }

    Popout {
        progress: root.progress
        toX: Math.max(12, Math.min(Panels.anchorX + Panels.anchorW / 2 - toW / 2, parent.width - toW - 12))
        toW: 4 * 72 + 32
        toH: grid.implicitHeight + 32

        Grid {
            id: grid
            x: 16
            y: 16
            columns: 4

            Repeater {
                model: root.items

                Item {
                    id: cell
                    required property var modelData
                    width: 72
                    height: 80

                    StateLayer {
                        radius: Shape.large
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton || cell.modelData.onlyMenu) {
                                contextMenu.openFor(cell.modelData, cell);
                            } else {
                                cell.modelData.activate();
                                Panels.close();
                            }
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: 44
                        height: 44
                        radius: 22
                        color: Colors.mode === "light" ? Colors.m3inverseSurface : Colors.m3surfaceContainerHighest

                        RectangularShadow {
                            anchors.fill: parent
                            radius: parent.radius
                            blur: 7
                            offset.y: 1
                            color: Qt.alpha(Colors.m3shadow, 0.22)
                            z: -1
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 24
                            source: cell.modelData.icon
                        }
                    }

                    MText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 58
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        textStyle: Type.labelSmall
                        color: Colors.m3onSurfaceVariant
                        text: cell.modelData.tooltipTitle || cell.modelData.title || cell.modelData.id
                    }
                }
            }
        }
    }
}

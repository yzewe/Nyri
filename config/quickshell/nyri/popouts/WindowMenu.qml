import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Surface {
    id: root

    name: "window"
    keyboard: false

    property var win: null
    readonly property var entry: win ? DesktopEntries.heuristicLookup(win.app_id) : null
    readonly property string appName: Apps.nameFor(win?.app_id)
    property real todaySec: 0

    onOpenChanged: {
        if (open) {
            win = Compositor.focusedWindow;
            todaySec = win ? (ScreenTime.dayTotals(new Date())[win.app_id] ?? 0) : 0;
        }
    }

    function act(...args) {
        Compositor.action(...args);
        Panels.close();
    }

    Popout {
        progress: root.progress
        toX: Math.max(12, Math.min(Panels.anchorX, parent.width - toW - 12))
        toW: 380
        toH: col.implicitHeight + 40

        Column {
            id: col
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 16

            Row {
                width: parent.width
                spacing: 14

                Rectangle {
                    width: 56
                    height: 56
                    radius: Shape.large
                    color: Colors.m3surfaceContainerHighest

                    AppIcon {
                        anchors.centerIn: parent
                        implicitSize: 40
                        source: Apps.iconSourceFor(root.win?.app_id, root.win?.title)
                    }
                }

                Column {
                    width: parent.width - 70
                    anchors.verticalCenter: parent.verticalCenter

                    MText {
                        width: parent.width
                        elide: Text.ElideRight
                        textStyle: Type.titleMediumEmph
                        text: root.appName
                    }

                    MText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textStyle: Type.bodyMedium
                        color: Colors.m3onSurfaceVariant
                        text: root.win?.title ?? ""
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { icon: "fit_screen", label: "Развернуть", run: () => root.act("maximize-window-to-edges", "--id", String(root.win.id)) },
                        { icon: "fullscreen", label: "Экран", run: () => root.act("fullscreen-window", "--id", String(root.win.id)) },
                        { icon: root.win?.is_floating ? "view_column" : "picture_in_picture", label: root.win?.is_floating ? "В колонку" : "Плавающее", run: () => root.act("toggle-window-floating", "--id", String(root.win.id)) },
                        { icon: "close", label: "Закрыть", danger: true, run: () => root.act("close-window", "--id", String(root.win.id)) }
                    ]

                    Rectangle {
                        id: action

                        required property var modelData

                        width: (col.width - 18) / 4
                        height: 76
                        radius: layer.pressed ? Shape.medium : Shape.largeIncreased
                        color: modelData.danger ? Colors.m3errorContainer : Colors.m3surfaceContainerHighest

                        Behavior on radius { SpatialAnim { speed: "fast" } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            MIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: action.modelData.icon
                                size: 24
                                color: action.modelData.danger ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                            }

                            MText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                textStyle: Type.labelMedium
                                color: action.modelData.danger ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                                text: action.modelData.label
                            }
                        }

                        StateLayer {
                            id: layer
                            radius: action.radius
                            color: action.modelData.danger ? Colors.m3onErrorContainer : Colors.m3onSurface
                            onClicked: action.modelData.run()
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                MText {
                    textStyle: Type.labelLarge
                    color: Colors.m3onSurfaceVariant
                    text: "Перенести на стол"
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: Compositor.workspacesOn(Compositor.focusedOutput)

                        Rectangle {
                            id: ws

                            required property var modelData
                            readonly property bool here: modelData.id === root.win?.workspace_id

                            width: 44
                            height: 40
                            radius: here ? height / 2 : Shape.medium
                            color: here ? Colors.m3primary : Colors.m3secondaryContainer

                            MText {
                                anchors.centerIn: parent
                                textStyle: Type.labelLargeEmph
                                color: ws.here ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
                                text: ws.modelData.idx
                            }

                            StateLayer {
                                visible: !ws.here
                                radius: ws.radius
                                color: Colors.m3onSecondaryContainer
                                onClicked: root.act("move-window-to-workspace", "--window-id", String(root.win.id), String(ws.modelData.idx))
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 56
                radius: Shape.largeIncreased
                color: Colors.m3surfaceContainerHigh

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 16
                    icon: "hourglass_top"
                    color: Colors.m3primary
                }

                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 52
                    textStyle: Type.bodyMedium
                    text: "Сегодня здесь " + ScreenTime.fmt(root.todaySec)
                }

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    icon: "chevron_right"
                    color: Colors.m3onSurfaceVariant
                }

                StateLayer {
                    radius: parent.radius
                    onClicked: Panels.open("power", "usage")
                }
            }
        }
    }
}

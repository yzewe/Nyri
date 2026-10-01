import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Notifications
import qs.theme
import qs.services
import qs.widgets

Card {
    id: root

    required property var notif
    property bool popup: false
    readonly property bool masked: popup && Privacy.active
    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property bool fromNiri: /\bniri\b/.test(((notif?.appName || "") + " " + (notif?.desktopEntry || "")).toLowerCase())
    readonly property string iconSource: {
        const n = notif;
        if (!n || fromNiri) return "";
        const icon = n.appIcon || DesktopEntries.byId(n.desktopEntry)?.icon || "";
        return Apps.fileForIcon(icon) || Apps.iconSourceFor(n.desktopEntry || "", "");
    }
    readonly property string picture: fromNiri || masked ? "" : String(notif?.image ?? "")
    readonly property string glyph: {
        if (fromNiri) return "view_column";
        const blob = ((notif?.appName || "") + " " + (notif?.summary || "") + " " + (notif?.appIcon || "")).toLowerCase();
        if (/запис|record|video|screen.?cast/.test(blob)) return "videocam";
        if (/скрин|screenshot|снимок/.test(blob)) return "screenshot_monitor";
        if (/пипет|color.?pick|eyedrop/.test(blob)) return "colorize";
        return "notifications";
    }

    signal closeRequested
    property bool animateClose: false

    function readable(s) {
        if (!s || s.indexOf("&") < 0 || s.indexOf("<") >= 0) return s || "";
        return s.replace(/&quot;|&#34;|&#x22;/gi, "\"")
            .replace(/&apos;|&#39;|&#x27;/gi, "'")
            .replace(/&lt;/gi, "<")
            .replace(/&gt;/gi, ">")
            .replace(/&amp;/gi, "&");
    }

    implicitHeight: body.implicitHeight + 28
    radius: Shape.largeIncreased
    color: critical ? Colors.m3errorContainer : popup ? Colors.m3surfaceContainerHigh : Colors.m3surfaceContainerHighest
    elevation: 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onWheel: event => event.accepted = false
        onClicked: {
            const def = root.notif?.actions.find(a => a.identifier === "default");
            if (def) Notifs.invoke(root.notif, def);
        }
    }

    Column {
        id: body
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 10

        Item {
            id: head
            width: parent.width
            height: Math.max(48, textCol.implicitHeight)

            Item {
                id: iconBox
                width: 48
                height: 48
                anchors.left: parent.left
                anchors.top: parent.top
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: root.critical ? Colors.m3error : Colors.m3secondaryContainer
                    visible: root.masked || shot.status !== Image.Ready
                }

                Image {
                    id: shot
                    anchors.fill: parent
                    visible: !root.masked && status === Image.Ready
                    source: root.picture
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: false
                }

                Image {
                    id: appIcon
                    anchors.fill: parent
                    visible: !root.masked && root.picture === "" && status === Image.Ready
                    source: root.picture === "" ? root.iconSource : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    smooth: true
                    mipmap: false
                    sourceSize.width: Math.round(iconBox.width * Screen.devicePixelRatio)
                    sourceSize.height: Math.round(iconBox.height * Screen.devicePixelRatio)
                }

                MIcon {
                    anchors.centerIn: parent
                    visible: root.masked || (root.picture === "" && appIcon.status !== Image.Ready)
                    icon: root.masked ? "visibility_off" : root.glyph
                    size: 22
                    fill: 1
                    color: root.critical ? Colors.m3onError : Colors.m3onSecondaryContainer
                }
            }

            Column {
                id: textCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 60
                anchors.rightMargin: 40
                spacing: 2

                MText {
                    width: parent.width
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignTop
                    font.family: "Liberation Sans"
                    font.kerning: true
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferDefaultHinting
                    font.variableAxes: ({})
                    font.weight: Font.Normal
                    textStyle: Type.labelMedium
                    color: root.critical ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                    text: [root.notif?.appName, Notifs.ago(root.notif?.id)].filter(Boolean).join(" · ")
                }

                MText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignTop
                    font.family: "Liberation Sans"
                    font.kerning: true
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferDefaultHinting
                    font.variableAxes: ({})
                    font.weight: Font.Bold
                    textStyle: Type.titleSmall
                    color: root.critical ? Colors.m3onErrorContainer : Colors.m3onSurface
                    text: root.masked ? "Новое уведомление" : root.notif?.summary ?? ""
                }

                MText {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.popup ? 4 : 6
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignTop
                    font.family: "Liberation Sans"
                    font.kerning: true
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferDefaultHinting
                    font.variableAxes: ({})
                    font.weight: Font.Normal
                    textFormat: (root.notif?.body ?? "").indexOf("<") >= 0 ? Text.StyledText : Text.PlainText
                    textStyle: Type.bodyMedium
                    color: root.critical ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                    linkColor: Colors.m3primary
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    text: root.masked ? "" : root.readable(root.notif?.body ?? "")
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.top: parent.top
                size: 32
                iconSize: 18
                icon: "close"
                onClicked: root.animateClose ? root.closeRequested() : root.notif?.dismiss()
            }
        }

        Flow {
            width: parent.width
            spacing: 8
            visible: actions.count > 0

            Repeater {
                id: actions
                model: (root.notif?.actions ?? []).filter(a => a.identifier !== "default" && a.text)

                Rectangle {
                    id: chip

                    required property var modelData

                    height: 36
                    width: label.implicitWidth + 32
                    radius: pressed.pressed ? Shape.medium : height / 2
                    color: Colors.m3secondaryContainer

                    Behavior on radius { SpatialAnim { speed: "fast" } }

                    MText {
                        id: label
                        anchors.centerIn: parent
                        font.family: "Liberation Sans"
                        font.kerning: true
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferDefaultHinting
                        font.variableAxes: ({})
                        font.weight: Font.Bold
                        textStyle: Type.labelLarge
                        color: Colors.m3onSecondaryContainer
                        text: chip.modelData.text
                    }

                    StateLayer {
                        id: pressed
                        radius: chip.radius
                        color: Colors.m3onSecondaryContainer
                        onClicked: Notifs.invoke(root.notif, chip.modelData)
                    }
                }
            }
        }
    }
}

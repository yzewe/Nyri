import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets

Surface {
    id: root

    name: "player"
    keyboard: false

    readonly property var player: Media.player
    readonly property bool playing: player?.isPlaying ?? false
    property bool lyricsOn: true

    onOpenChanged: {
        if (open) Lyrics.wanted++;
        else { Lyrics.wanted = Math.max(0, Lyrics.wanted - 1); Media.chosen = null; }
    }
    Timer {
        running: root.open && root.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player.positionChanged()
    }
    function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function karaoke(text, p) {
        const parts = text.split(/(\s+)/);
        const total = text.replace(/\s+/g, "").length || 1;
        let done = 0, lit = "", rest = "", on = true;
        for (const w of parts) {
            if (on && w.trim()) {
                done += w.length;
                if ((done - w.length) / total > p) on = false;
            }
            if (on) lit += w; else rest += w;
        }
        return "<font color='" + Colors.m3primary + "'>" + esc(lit) + "</font><font color='" + Colors.m3onSurfaceVariant + "'>" + esc(rest) + "</font>";
    }
    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function nextPlayer() {
        const players = Media.players;
        if (players.length < 2) return;
        const at = players.indexOf(root.player);
        Media.chosen = players[(at + 1) % players.length];
    }

    Popout {
        id: card
        progress: root.progress
        readonly property bool lyricsReady: root.lyricsOn && Lyrics.lines.length > 0 && !Lyrics.none
        SpringValue {
            id: lyricsIn
            target: card.lyricsReady ? 1 : 0
            damping: 0.78
            stiffness: 260
            epsilon: 0.001
            onTargetChanged: if (root.progress < 0.2) { value = target; velocity = 0; running = false; }
        }
        toW: 420 + 340 * lyricsIn.value
        toX: Math.max(12, Math.min(parent.width - toW - 12, (Panels.anchorW > 0 ? Panels.anchorX + Panels.anchorW / 2 : parent.width / 2) - toW / 2))
        toH: side.implicitHeight + 40

        Column {
            id: side
            x: 20
            y: 20
            width: 380
            spacing: 14

            Item {
                width: parent.width
                height: coverSlot.height
                Item { id: coverSlot; width: 148; height: 148 }
                Rectangle {
                    id: sourceChip
                    anchors.left: coverSlot.right
                    anchors.leftMargin: 18
                    anchors.top: coverSlot.top
                    visible: (root.player?.identity ?? "") !== ""
                    width: Math.min(parent.width - coverSlot.width - 18, srcRow.implicitWidth + 20)
                    height: 26
                    radius: 13
                    color: Colors.m3secondaryContainer
                    clip: true
                    Row {
                        id: srcRow
                        anchors.centerIn: parent
                        spacing: 5
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.playing ? "graphic_eq" : "pause"; size: 14; fill: 1; color: Colors.m3onSecondaryContainer }
                        MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelMedium; color: Colors.m3onSecondaryContainer; text: root.player?.identity ?? ""; elide: Text.ElideRight; width: Math.min(implicitWidth, sourceChip.width - 30) }
                    }
                    HoverHandler { cursorShape: Media.players.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { enabled: Media.players.length > 1; onTapped: root.nextPlayer() }
                }

                Column {
                    anchors.left: coverSlot.right
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.bottom: coverSlot.bottom
                    anchors.bottomMargin: -3
                    spacing: 4
                    MText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textStyle: ({ size: 22, weight: 650, rond: 50 })
                        text: root.player?.trackTitle || "Ничего не играет"
                    }
                    FlowText {
                        width: parent.width
                        elide: Text.ElideRight
                        textStyle: Type.bodyMedium
                        color: Colors.m3onSurfaceVariant
                        text: [root.player?.trackArtist, root.player?.trackAlbum].filter(Boolean).join(" · ")
                    }
                }
            }

            Item {
                width: parent.width
                height: 28
                visible: root.player?.lengthSupported ?? false
                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    textStyle: Type.labelMedium
                    font.features: { "tnum": 1 }
                    color: Colors.m3onSurfaceVariant
                    text: root.fmt(root.player?.position ?? 0)
                }
                WavyProgress {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 44
                    width: parent.width - 88
                    value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                    wavy: root.playing
                    flowing: root.open && root.playing
                    onSeek: v => { if (root.player?.canSeek) root.player.position = v * root.player.length }
                }
                MText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    textStyle: Type.labelMedium
                    font.features: { "tnum": 1 }
                    color: Colors.m3onSurfaceVariant
                    text: root.fmt(root.player?.length ?? 0)
                }
            }

            Item {
                width: parent.width
                height: 76

                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "shuffle"
                    visible: root.player?.shuffleSupported ?? false
                    style: root.player?.shuffle ? "tonal" : "standard"
                    onClicked: root.player.shuffle = !root.player.shuffle
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_previous"; size: 52; iconSize: 30
                        enabled: root.player?.canGoPrevious ?? false
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.player.previous()
                    }
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        SpringValue { id: playW; target: root.playing ? 96 : 76; damping: 0.6; stiffness: 520 }
                        width: playW.value
                        height: 76
                        scale: sq.value
                        SpringValue { id: sq; target: playL.pressed ? 0.88 : 1; damping: 0.45; stiffness: 900; epsilon: 0.001 }
                        Rectangle {
                            anchors.fill: parent
                            visible: root.playing
                            radius: Shape.large
                            color: Colors.m3primary
                        }
                        MaterialShape {
                            anchors.centerIn: parent
                            width: 76; height: 76
                            visible: !root.playing
                            shape: "cookie9Sided"
                            color: Colors.m3primary
                            rotation: spinS.value
                            SpringValue { id: spinS; target: root.playing ? 0 : 20; damping: 0.6; stiffness: 200 }
                        }
                        MIcon { anchors.centerIn: parent; icon: root.playing ? "pause" : "play_arrow"; size: 36; fill: 1; color: Colors.m3onPrimary }
                        StateLayer { id: playL; radius: Shape.large; color: Colors.m3onPrimary; onClicked: root.player.togglePlaying() }
                    }
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_next"; size: 52; iconSize: 30
                        enabled: root.player?.canGoNext ?? false
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.player.next()
                    }
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.player?.loopSupported ?? false
                    icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    style: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? "tonal" : "standard"
                    onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                     : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
            }

            Row {
                width: parent.width
                height: 44
                spacing: 8
                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.player?.volumeSupported ?? false
                    icon: (root.player?.volume ?? 1) < 0.01 ? "volume_off" : "volume_down"
                    size: 22
                    color: Colors.m3onSurfaceVariant
                }
                MSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.player?.volumeSupported ?? false
                    width: parent.width - 30 - 2 * 48 - 3 * 8
                    trackHeight: 24
                    value: root.player?.volume ?? 1
                    onMoved: v => root.player.volume = v
                }
                Item {
                    visible: !(root.player?.volumeSupported ?? false)
                    width: parent.width - 2 * 48 - 8
                    height: 1
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "lyrics"
                    style: root.lyricsOn ? "tonal" : "standard"
                    onClicked: root.lyricsOn = !root.lyricsOn
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "open_in_new"
                    enabled: root.player?.canRaise ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: { Panels.close(); root.player?.raise(); }
                }
            }
        }

        Rectangle {
            id: lyricsBox
            x: side.x + side.width + 16
            y: 20
            width: card.toW - x - 20
            height: card.toH - 40
            radius: Shape.large
            color: Colors.m3surfaceContainerHigh
            visible: lyricsIn.value > 0.04 && width > 40
            opacity: Math.min(1, lyricsIn.value * 1.6)
            scale: 0.94 + 0.06 * lyricsIn.value
            transformOrigin: Item.Left
            clip: true

            ListView {
                id: lyricList
                anchors.fill: parent
                anchors.margins: 12
                model: Lyrics.lines.length
                spacing: 6
                interactive: true
                Overscroll { flick: lyricList }
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: height * 0.35
                preferredHighlightEnd: height * 0.5
                highlightMoveDuration: 500
                currentIndex: Math.max(0, Lyrics.current)

                delegate: Item {
                    id: line
                    required property int index
                    readonly property var l: Lyrics.lines[index]
                    readonly property bool now: index === Lyrics.current
                    readonly property bool past: Lyrics.synced && index < Lyrics.current
                    width: lyricList.width
                    height: txt.implicitHeight * (1 + 0.1 * lit.value) + 10
                    SpringValue { id: lit; target: line.now ? 1 : 0; damping: 0.7; stiffness: 380 }

                    MText {
                        id: txt
                        width: (parent.width - 22) / 1.1
                        x: 8 + 6 * lit.value
                        y: 5
                        wrapMode: Text.Wrap
                        lineHeight: 1.12
                        font.pixelSize: 19
                        font.variableAxes: ({ "wght": 600, "ROND": 60 })
                        renderType: Text.CurveRendering
                        scale: 1 + 0.1 * lit.value
                        transformOrigin: Item.TopLeft
                        color: line.now ? Colors.m3primary : Colors.m3onSurface
                        opacity: !Lyrics.synced ? 0.9 : line.now ? 1 : line.past ? 0.35 : 0.6
                        textFormat: line.now ? Text.StyledText : Text.PlainText
                        text: line.now && Lyrics.synced ? root.karaoke(line.l?.text || "♪", Lyrics.lineProgress) : (line.l?.text || "♪")
                        Behavior on opacity { EffectAnim {} }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: Lyrics.synced
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Lyrics.seek(line.index)
                    }
                }
            }

        }
    }

    ClippingRectangle {
        id: flyer
        readonly property real p: Math.max(0, Math.min(1.05, root.progress))
        readonly property real fromX: Panels.anchorW > 0 ? Panels.anchorX + 6 : card.toX + 20
        readonly property real fromY: Panels.barBottom ? root.height - Panels.barReach + 6 : 12 + 6
        readonly property real toX: card.x + side.x
        readonly property real toY: card.y + side.y
        x: fromX + (toX - fromX) * p
        y: fromY + (toY - fromY) * p
        width: 28 + (coverSlot.width - 28) * p
        height: 28 + (coverSlot.height - 28) * p
        radius: 14 + (Shape.large - 14) * Math.min(1, p)
        color: Colors.m3secondaryContainer
        opacity: Math.min(1, root.progress * 3)
        visible: root.visible

        Image {
            id: big
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
        }
        MaterialShape {
            anchors.centerIn: parent
            visible: big.status !== Image.Ready
            width: Math.min(parent.width, parent.height) * 0.6
            height: width
            shape: "cookie12Sided"
            color: Colors.m3primaryContainer
            MIcon { anchors.centerIn: parent; icon: "music_note"; size: parent.width * 0.4; fill: 1; color: Colors.m3onPrimaryContainer }
        }
    }
}

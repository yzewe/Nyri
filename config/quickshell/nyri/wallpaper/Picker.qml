import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Panels.studioOpen
    function toggle() { Panels.studioOpen = !Panels.studioOpen; }

    readonly property string bin: Paths.bin + "/nyri-wall"
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string preview: runtime + "/nyri-wall-preview"
    readonly property string thumbDir: runtime + "/nyri-wall-thumbs"

    property var styles: []
    property var palettes: []
    property var files: []
    property string style: "bauhaus"
    property string palette: "Терракота"
    property int seed: 1
    property bool grid: false
    property real patternScale: 1.0
    property real hue: 0.72
    property var customColors: ["#e45757", "#f3c661", "#75c995", "#698ce4"]
    property int selectedColor: 0
    property string tone: ""
    property int frame: 0
    property int thumbGen: 0
    property bool applying: false

    readonly property bool custom: palette.startsWith("#")
    readonly property bool multi: palette.startsWith("colors:")
    readonly property string customSpec: Qt.hsla(hue, 0.62, 0.5, 1).toString() + (tone === "dark" ? "/dark" : "")
    readonly property string spec: multi ? palette : custom ? customSpec : palette + (tone ? "/" + tone : "")
    readonly property int styleIndex: styles.findIndex(s => s.id === style)
    readonly property int paletteIndex: custom || multi ? -1 : palettes.findIndex(p => p.name === palette)
    readonly property var styleInfo: styles[styleIndex] ?? null
    readonly property string paletteTitle: multi ? "Своя палитра" : custom ? "Свой цвет" : palette

    function args() {
        const a = grid ? ["--grid"] : [];
        if (Math.abs(patternScale - 1) > 0.01) a.push("--scale", patternScale.toFixed(2));
        return a;
    }
    Connections {
        target: Config.o.wallpaper
        function onAnimatedChanged() { if (Config.o.wallpaper.animated) root.regenerate(); }
    }
    Timer { id: scaleDebounce; interval: 150; onTriggered: root.refresh() }
    function regenerate() {
        frame = (frame + 1) % 2;
        make.command = [bin, "make", style, spec, String(seed), preview + frame + ".svg", "--size", "1440x900", ...args(), ...(Config.o.wallpaper.animated ? ["--scene", preview + frame + ".json"] : [])];
        make.running = true;
    }
    function rethumb() {
        thumbs.command = [bin, "thumbs", spec, String(seed), thumbDir, ...args()];
        thumbs.running = true;
    }
    function refresh() { regenerate(); rethumb(); }
    function pickStyle(id) { if (id === style) return; style = id; regenerate(); }
    function pickPalette(name) { if (name === palette) return; palette = name; refresh(); }
    function pickCustom() { palette = customSpec; refresh(); }
    function pickMulti() { tone = ""; palette = "colors:" + customColors.join(","); refresh(); }
    function hexColor(c) { return "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join(""); }
    function setColor(index, value) {
        if (!/^#[0-9a-fA-F]{6}$/.test(value)) return;
        const next = customColors.slice();
        next[index] = value.toLowerCase();
        customColors = next;
        palette = "colors:" + next.join(",");
        colorDebounce.restart();
    }
    function addColor() {
        if (customColors.length >= 16) return;
        customColors = customColors.concat([hexColor(Qt.hsla(hue, 0.62, 0.5, 1))]);
        selectedColor = customColors.length - 1;
        palette = "colors:" + customColors.join(",");
        colorDebounce.restart();
    }
    function removeColor() {
        if (customColors.length <= 2) return;
        const next = customColors.filter((_, i) => i !== selectedColor);
        customColors = next;
        selectedColor = Math.min(selectedColor, next.length - 1);
        palette = "colors:" + next.join(",");
        colorDebounce.restart();
    }
    function shuffle() { seed = Math.floor(Math.random() * 100000); dice.target += 180; refresh(); }
    function apply() {
        if (applying) return;
        applying = true;
        applier.command = [bin, "apply", style, spec, String(seed), ...args()];
        applier.running = true;
    }

    onCustomSpecChanged: if (custom) hueDebounce.restart()
    Timer { id: hueDebounce; interval: 120; onTriggered: { root.palette = root.customSpec; root.refresh(); } }
    Timer { id: colorDebounce; interval: 150; onTriggered: root.refresh() }

    onOpenChanged: {
        if (!open) return;
        if (!styles.length) lists.running = true;
        restore.reload();
        scan.running = true;
    }

    SpringValue { id: dice; damping: 0.55; stiffness: 260; epsilon: 0.05 }

    Process {
        id: lists
        command: ["sh", "-c", "\"$0\" styles; \"$0\" palettes", root.bin]
        stdout: StdioCollector {
            onStreamFinished: {
                const [s, p] = text.trim().split("\n");
                root.styles = JSON.parse(s);
                root.palettes = JSON.parse(p);
                root.refresh();
            }
        }
    }

    FileView {
        id: restore
        path: Paths.data + "/walls/current.json"
        onLoaded: {
            try {
                const c = JSON.parse(text());
                root.style = c.style;
                root.seed = parseInt(c.seed);
                root.grid = !!c.grid;
                root.patternScale = c.scale ?? 1;
                const [base, variant] = c.palette.split("/");
                root.tone = variant ?? "";
                if (base.startsWith("colors:")) {
                    root.customColors = base.slice(7).split(",");
                    root.palette = base;
                } else if (base.startsWith("#")) {
                    root.hue = Qt.color(base).hslHue;
                    root.palette = root.customSpec;
                } else {
                    root.palette = base;
                }
                if (root.styles.length) root.refresh();
            } catch (e) {}
        }
    }

    Process {
        id: make
        stdout: StdioCollector { onStreamFinished: loader.item?.showPreview("file://" + root.preview + root.frame + ".svg") }
    }
    Process {
        id: thumbs
        onExited: root.thumbGen++
    }
    Process {
        id: applier
        onExited: root.applying = false
    }
    Process {
        id: scan
        command: ["sh", "-c", "find \"${NYRI_PICTURES:-$HOME/Pictures/Wallpapers}\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort"]
        stdout: StdioCollector { onStreamFinished: root.files = text.split("\n").filter(Boolean) }
    }

    LazyLoader {
        id: loader
        active: root.open

        FloatingWindow {
            id: win

            title: "Nyri · Обои"
            visible: true
            implicitWidth: 1000
            implicitHeight: 820
            minimumSize: Qt.size(640, 520)
            color: Colors.m3surfaceContainerLow

            onVisibleChanged: if (!visible) Panels.studioOpen = false
            function showPreview(src) { stage.show(src); }

            Shortcut { sequence: "Escape"; onActivated: Panels.studioOpen = false }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    const n = root.styles.length, m = root.palettes.length;
                    if (event.key === Qt.Key_R || event.key === Qt.Key_Space) root.shuffle();
                    else if (event.key === Qt.Key_G) { root.grid = !root.grid; root.refresh(); }
                    else if (event.key === Qt.Key_C) root.pickCustom();
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.apply();
                    else if (event.key === Qt.Key_Right && n) root.pickStyle(root.styles[(root.styleIndex + 1) % n].id);
                    else if (event.key === Qt.Key_Left && n) root.pickStyle(root.styles[(root.styleIndex + n - 1) % n].id);
                    else if (event.key === Qt.Key_Down && m) root.pickPalette(root.palettes[(root.paletteIndex + 1) % m].name);
                    else if (event.key === Qt.Key_Up && m) root.pickPalette(root.palettes[(Math.max(0, root.paletteIndex) + m - 1) % m].name);
                    else if (event.key === Qt.Key_PageDown) flick.flick(0, -2600);
                    else if (event.key === Qt.Key_PageUp) flick.flick(0, 2600);
                    else return;
                    event.accepted = true;
                }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: col.implicitHeight + 40
                Overscroll { flick: flick }

                Column {
                    id: col
                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: 18

                    ClippingRectangle {
                        id: hero
                        width: parent.width
                        height: Math.min(width * 0.625, win.height * 0.56)
                        radius: Shape.extraLarge
                        color: Colors.m3surfaceContainerHighest

                        Item {
                            id: stage
                            anchors.fill: parent
                            property bool onA: true
                            function show(src) {
                                const next = onA ? imgB : imgA;
                                next.pending = true;
                                next.source = "";
                                next.source = src;
                            }
                            function reveal(img) {
                                img.pending = false;
                                live.file = Config.o.wallpaper.animated ? img.source.toString().replace("file://", "").replace(/\.svg$/, ".json") : "";
                                onA = img === imgA;
                                img.z = 1;
                                (img === imgA ? imgB : imgA).z = 0;
                                swap.value = 0;
                                swap.running = true;
                            }
                            SpringValue { id: swap; target: 1; damping: 0.8; stiffness: 240; epsilon: 0.002 }

                            Image {
                                id: imgA
                                property bool pending: false
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(width * 1.5, height * 1.5)
                                asynchronous: true
                                cache: false
                                opacity: stage.onA ? Math.min(1, swap.value * 1.2) : 1
                                scale: stage.onA ? 1.04 - 0.04 * swap.value : 1
                                onStatusChanged: if (status === Image.Ready && pending) stage.reveal(imgA)
                            }
                            Image {
                                id: imgB
                                property bool pending: false
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(width * 1.5, height * 1.5)
                                asynchronous: true
                                cache: false
                                opacity: !stage.onA ? Math.min(1, swap.value * 1.2) : 1
                                scale: !stage.onA ? 1.04 - 0.04 * swap.value : 1
                                onStatusChanged: if (status === Image.Ready && pending) stage.reveal(imgB)
                            }
                        }

                        Scene {
                            id: live
                            anchors.fill: parent
                            z: 1
                            visible: Config.o.wallpaper.animated && ready && !swap.running
                            running: visible
                        }

                        Rectangle {
                            x: 16
                            y: 16
                            z: 2
                            width: tag.implicitWidth + 28
                            height: 36
                            radius: 18
                            color: Qt.alpha(Colors.m3surfaceContainerLowest, 0.82)
                            Behavior on width { SpatialAnim { speed: "fast" } }

                            Row {
                                id: tag
                                anchors.centerIn: parent
                                spacing: 6
                                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.styleInfo?.icon ?? "wallpaper"; size: 18; fill: 1; color: Colors.m3primary }
                                FlowText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLargeEmph; text: root.styleInfo?.title ?? "" }
                                MText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; color: Colors.m3onSurfaceVariant; text: "·" }
                                FlowText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.labelLarge; color: Colors.m3onSurfaceVariant; text: root.paletteTitle }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 16
                            z: 2
                            spacing: 12

                            Rectangle {
                                id: shuffleBtn
                                anchors.verticalCenter: parent.verticalCenter
                                width: 56
                                height: 56
                                radius: shLayer.pressed ? Shape.medium : height / 2
                                color: Colors.m3secondaryContainer
                                Behavior on radius { SpatialAnim { speed: "fast" } }

                                MIcon {
                                    anchors.centerIn: parent
                                    icon: "casino"
                                    size: 26
                                    fill: 1
                                    rotation: dice.value
                                    color: Colors.m3onSecondaryContainer
                                }
                                StateLayer { id: shLayer; radius: shuffleBtn.radius; color: Colors.m3onSecondaryContainer; onClicked: root.shuffle() }
                            }

                            Rectangle {
                                id: applyBtn
                                anchors.verticalCenter: parent.verticalCenter
                                width: apRow.implicitWidth + 40
                                height: 64
                                radius: apLayer.pressed ? Shape.medium : Shape.large
                                color: Colors.m3primaryContainer
                                Behavior on radius { SpatialAnim { speed: "fast" } }

                                Row {
                                    id: apRow
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        height: 28
                                        MIcon { anchors.centerIn: parent; visible: !root.applying; icon: "format_paint"; size: 24; fill: 1; color: Colors.m3onPrimaryContainer }
                                        LoadingIndicator { anchors.fill: parent; visible: root.applying; running: root.applying; contained: false; color: Colors.m3onPrimaryContainer }
                                    }
                                    FlowText { anchors.verticalCenter: parent.verticalCenter; textStyle: Type.titleMediumEmph; color: Colors.m3onPrimaryContainer; text: root.applying ? "Применяю…" : "Применить" }
                                }
                                StateLayer { id: apLayer; radius: applyBtn.radius; color: Colors.m3onPrimaryContainer; onClicked: root.apply() }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 36
                        Section { anchors.verticalCenter: parent.verticalCenter; title: "Стиль" }
                        FilterChip {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Сетка"
                            picked: root.grid
                            onClicked: { root.grid = !root.grid; root.refresh(); }
                        }
                    }

                    ListView {
                        id: styleList
                        width: parent.width
                        height: 136
                        orientation: ListView.Horizontal
                        spacing: 2
                        clip: true
                        model: root.styles
                        currentIndex: root.styleIndex
                        highlightFollowsCurrentItem: false
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: card
                            required property var modelData
                            readonly property bool picked: root.style === modelData.id
                            width: 164
                            height: 136

                            SpringValue { id: pick; target: card.picked ? 1 : 0; damping: 0.6; stiffness: 500 }

                            ClippingRectangle {
                                id: thumb
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 10
                                width: 148
                                height: 92
                                radius: Shape.large + (Shape.extraLarge - Shape.large) * pick.value
                                color: Colors.m3surfaceContainerHighest
                                scale: 1 - 0.06 * pick.value

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(296, 184)
                                    asynchronous: true
                                    cache: false
                                    source: root.thumbGen > 0 ? "file://" + root.thumbDir + "/" + card.modelData.id + ".svg?" + root.thumbGen : ""
                                }
                            }
                            Rectangle {
                                anchors.fill: thumb
                                anchors.margins: -4
                                radius: thumb.radius + 4
                                color: "transparent"
                                border.width: 3
                                border.color: Colors.m3primary
                                opacity: Math.min(1, pick.value)
                            }
                            Rectangle {
                                x: thumb.x + thumb.width - width + 4
                                y: thumb.y - 6
                                width: 26
                                height: 26
                                radius: 13
                                color: Colors.m3primary
                                scale: Math.max(0, pick.value)
                                MIcon { anchors.centerIn: parent; icon: "check"; size: 18; color: Colors.m3onPrimary }
                            }
                            FlowText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                textStyle: card.picked ? Type.labelLargeEmph : Type.labelLarge
                                color: card.picked ? Colors.m3primary : Colors.m3onSurfaceVariant
                                text: card.modelData.title
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickStyle(card.modelData.id)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 48
                        MText {
                            id: scaleLabel
                            anchors.verticalCenter: parent.verticalCenter
                            textStyle: Type.labelLargeEmph
                            color: Colors.m3onSurfaceVariant
                            text: "Масштаб"
                        }
                        MSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: scaleLabel.right
                            anchors.leftMargin: 16
                            anchors.right: scaleValue.left
                            anchors.rightMargin: 12
                            value: (Math.log(root.patternScale) / Math.LN2 + 1) / 2
                            onMoved: v => {
                                const k = Math.pow(2, v * 2 - 1);
                                root.patternScale = Math.abs(k - 1) < 0.06 ? 1 : Math.round(k * 20) / 20;
                                scaleDebounce.restart();
                            }
                        }
                        Rectangle {
                            id: scaleValue
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            height: 32
                            radius: 16
                            color: Colors.m3secondaryContainer
                            MText {
                                anchors.centerIn: parent
                                textStyle: Type.labelLargeEmph
                                font.features: { "tnum": 1 }
                                color: Colors.m3onSecondaryContainer
                                text: "×" + (Math.round(root.patternScale * 100) / 100)
                            }
                            StateLayer {
                                radius: 16
                                color: Colors.m3onSecondaryContainer
                                onClicked: { root.patternScale = 1; root.refresh(); }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 48
                        MIcon { id: liveIcon; anchors.verticalCenter: parent.verticalCenter; icon: "animation"; size: 22; color: Colors.m3onSurfaceVariant }
                        Column {
                            anchors.left: liveIcon.right
                            anchors.leftMargin: 12
                            anchors.right: liveSwitch.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            MText { textStyle: Type.labelLargeEmph; color: Colors.m3onSurface; text: "Живые обои" }
                        }
                        MSwitch {
                            id: liveSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Config.o.wallpaper.animated
                            onToggled: c => Config.o.wallpaper.animated = c
                        }
                    }

                    Item {
                        width: parent.width
                        height: 48
                        visible: Config.o.wallpaper.animated
                        MText {
                            id: paceLabel
                            anchors.verticalCenter: parent.verticalCenter
                            textStyle: Type.labelLargeEmph
                            color: Colors.m3onSurfaceVariant
                            text: "Скорость"
                        }
                        MSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: paceLabel.right
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            value: (Math.log(Config.o.wallpaper.pace) / Math.LN2 + 2) / 4
                            onMoved: v => paceSet.want = Math.pow(2, v * 4 - 2)
                        }
                        Timer {
                            id: paceSet
                            property real want: 1
                            onWantChanged: restart()
                            interval: 200
                            onTriggered: Config.o.wallpaper.pace = Math.abs(want - 1) < 0.08 ? 1 : Math.round(want * 20) / 20
                        }
                    }

                    Section { title: "Палитра" }

                    ListView {
                        id: palList
                        width: parent.width
                        height: 80
                        orientation: ListView.Horizontal
                        spacing: 6
                        clip: true
                        model: root.palettes
                        currentIndex: root.paletteIndex
                        highlightFollowsCurrentItem: false
                        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                        boundsBehavior: Flickable.StopAtBounds

                        header: Item {
                            width: 70
                            height: 80
                            SpringValue { id: cPick; target: root.custom ? 1 : 0; damping: 0.6; stiffness: 520 }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                width: 56
                                height: 56
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#ff5a5a" }
                                        GradientStop { position: 0.2; color: "#ffd23f" }
                                        GradientStop { position: 0.4; color: "#5ad16a" }
                                        GradientStop { position: 0.6; color: "#3fb6ff" }
                                        GradientStop { position: 0.8; color: "#8a6bff" }
                                        GradientStop { position: 1.0; color: "#ff5ab4" }
                                    }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 56 - 10 - 6 * cPick.value
                                    height: width
                                    radius: width / 2
                                    color: Qt.hsla(root.hue, 0.62, 0.5, 1)
                                    border.width: 3
                                    border.color: Colors.m3surfaceContainerLow
                                    MIcon { anchors.centerIn: parent; icon: root.custom ? "check" : "palette"; size: 18; fill: 1; color: "white" }
                                }
                            }
                            MText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                textStyle: Type.labelSmall
                                color: root.custom ? Colors.m3primary : Colors.m3onSurfaceVariant
                                text: "Свой"
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pickCustom() }
                        }

                        delegate: Item {
                            id: sw
                            required property var modelData
                            readonly property bool picked: root.palette === modelData.name
                            readonly property var c: modelData.colors
                            width: 64
                            height: 80

                            SpringValue { id: swPick; target: sw.picked ? 1 : 0; damping: 0.6; stiffness: 520 }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                width: 56
                                height: 56

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Colors.m3surfaceContainerHighest
                                    border.width: 2
                                    border.color: Colors.m3primary
                                    opacity: Math.min(1, swPick.value)
                                }
                                ClippingRectangle {
                                    anchors.centerIn: parent
                                    width: 56 - 12 * swPick.value
                                    height: width
                                    radius: width / 2
                                    color: sw.c[0]
                                    Rectangle { y: parent.height / 2; width: parent.width / 2; height: parent.height / 2; color: sw.c[1] }
                                    Rectangle { x: parent.width / 2; y: parent.height / 2; width: parent.width / 2; height: parent.height / 2; color: sw.c[2] ?? sw.c[1] }
                                    Rectangle { x: parent.width / 2; width: parent.width / 2; height: parent.height / 2; color: sw.c[3] ?? sw.c[0] }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: Colors.m3primary
                                    scale: Math.max(0, swPick.value)
                                    MIcon { anchors.centerIn: parent; icon: "check"; size: 16; color: Colors.m3onPrimary }
                                }
                            }
                            MText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                textStyle: Type.labelSmall
                                color: sw.picked ? Colors.m3primary : Colors.m3onSurfaceVariant
                                text: sw.modelData.name
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickPalette(sw.modelData.name)
                            }
                        }
                    }

                    Item {
                        id: customBox
                        width: parent.width
                        SpringValue { id: cOpen; target: root.custom || root.multi ? 1 : 0; damping: 0.78; stiffness: 360 }
                        height: 56

                        Item {
                            id: hueBar
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.multi ? parent.width : Math.max(0, parent.width - modes.width - 16)
                            opacity: Math.max(0, Math.min(1, cOpen.value * 1.3))
                            visible: opacity > 0.01
                            height: 48

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 20
                                radius: 10
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0 / 6; color: Qt.hsla(0 / 6, 0.62, 0.5, 1) }
                                    GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.62, 0.5, 1) }
                                    GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.62, 0.5, 1) }
                                    GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.62, 0.5, 1) }
                                    GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.62, 0.5, 1) }
                                    GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.62, 0.5, 1) }
                                    GradientStop { position: 6 / 6; color: Qt.hsla(0.999, 0.62, 0.5, 1) }
                                }
                            }

                            Rectangle {
                                SpringValue { id: thumbX; target: root.hue * (hueBar.width - 36); damping: 0.8; stiffness: 900; epsilon: 0.1 }
                                SpringValue { id: thumbS; target: hueArea.pressed ? 1.2 : 1; damping: 0.55; stiffness: 700 }
                                x: thumbX.value
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 36
                                radius: 18
                                scale: thumbS.value
                                color: Qt.hsla(root.hue, 0.62, 0.5, 1)
                                border.width: 4
                                border.color: "white"
                            }

                            MouseArea {
                                id: hueArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function set(x) {
                                    root.hue = Math.max(0, Math.min(0.999, (x - 18) / (hueBar.width - 36)));
                                    if (root.multi) root.setColor(root.selectedColor, root.hexColor(Qt.hsla(root.hue, 0.62, 0.5, 1)));
                                }
                                onPressed: m => set(m.x)
                                onPositionChanged: m => { if (pressed) set(m.x); }
                            }
                        }

                        SegmentedButtons {
                            id: modes
                            visible: !root.multi
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.multi ? 0 : root.custom ? 260 : parent.width
                            Behavior on width { SpatialAnim {} }
                            value: root.custom && root.tone === "" ? "light" : root.tone
                            options: root.custom
                                ? [{ value: "light", label: "Светлые", icon: "light_mode" }, { value: "dark", label: "Тёмные", icon: "dark_mode" }]
                                : [{ value: "", label: "Как есть", icon: "palette" }, { value: "light", label: "Светлые", icon: "light_mode" }, { value: "dark", label: "Тёмные", icon: "dark_mode" }]
                            onSelected: v => {
                                root.tone = root.custom && v === "light" ? "" : v;
                                if (!root.custom) root.refresh();
                            }
                        }
                    }

                    FilterChip {
                        text: "Своя палитра"
                        picked: root.multi
                        onClicked: root.pickMulti()
                    }

                    Column {
                        width: parent.width
                        spacing: 10
                        visible: root.multi

                        MText {
                            textStyle: Type.labelMedium
                            color: Colors.m3onSurfaceVariant
                            text: "Добавь цвета, выбери полосы или любой другой рисунок"
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.customColors
                                FilterChip {
                                    required property int index
                                    required property string modelData
                                    text: String(index + 1)
                                    swatch: [modelData, modelData, modelData]
                                    picked: root.selectedColor === index
                                    onClicked: {
                                        root.selectedColor = index;
                                        root.hue = Qt.color(modelData).hslHue;
                                    }
                                }
                            }
                            FilterChip {
                                text: "+ Цвет"
                                onClicked: root.addColor()
                            }
                        }
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 144
                                height: 36
                                radius: Shape.small
                                color: Colors.m3surfaceContainerHighest
                                TextInput {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Colors.m3onSurface
                                    font.family: Type.monoFamily
                                    font.pixelSize: 14
                                    maximumLength: 7
                                    text: root.customColors[root.selectedColor] ?? ""
                                    onEditingFinished: root.setColor(root.selectedColor, text)
                                }
                            }
                            IconButton {
                                icon: "remove"
                                style: "tonal"
                                enabled: root.customColors.length > 2
                                onClicked: root.removeColor()
                            }
                        }
                    }

                    Section { title: "Мои картинки"; visible: root.files.length > 0 }

                    ListView {
                        width: parent.width
                        height: 92
                        visible: root.files.length > 0
                        orientation: ListView.Horizontal
                        spacing: 10
                        clip: true
                        model: root.files
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: ClippingRectangle {
                            id: pic
                            required property string modelData
                            width: 148
                            height: 92
                            radius: picArea.containsMouse ? Shape.extraLarge : Shape.large
                            color: Colors.m3surfaceContainerHighest
                            Behavior on radius { SpatialAnim { speed: "fast" } }

                            Image {
                                anchors.fill: parent
                                source: "file://" + pic.modelData
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(296, 184)
                                asynchronous: true
                            }
                            MouseArea {
                                id: picArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached([Paths.bin + "/nyri-theme", pic.modelData])
                            }
                        }
                    }

                    MText {
                        textStyle: Type.labelMedium
                        color: Colors.m3outline
                        text: "←/→ стиль · ↑/↓ палитра · C свой цвет · G сетка · R перемешать · Enter применить"
                    }
                }
            }
        }
    }

    component Section: MText {
        property string title
        textStyle: Type.titleMediumEmph
        color: Colors.m3primary
        text: title
    }
}

import QtQuick

Item {
    id: root

    required property Flickable flick
    property real step: 1
    property real touchpad: 1
    property real coast: 0.16
    property real coastMax: 360
    property real glideStiff: 280

    property real speed: 0
    property real lastAt: 0
    property real goal: 0
    property real written: 0
    property real ownUntil: 0

    width: 0
    height: 0

    readonly property real minY: flick.originY - flick.topMargin
    readonly property real maxY: Math.max(minY, flick.originY + flick.contentHeight + flick.bottomMargin - flick.height)

    function clamp(y) { return Math.max(minY, Math.min(maxY, y)); }
    function own() { ownUntil = Date.now() + 700; }

    SpringValue {
        id: glide
        damping: 1
        stiffness: 420
        epsilon: 0.15
        onValueChanged: if (running) { root.written = value; root.flick.contentY = value; }
    }

    function follow(delta, stiff) {
        const f = root.flick;
        f.cancelFlick();
        root.own();
        if (!glide.running) {
            glide.value = f.contentY;
            glide.velocity = 0;
            root.goal = f.contentY;
        }
        root.goal = root.clamp(root.goal + delta);
        glide.stiffness = stiff;
        glide.target = root.goal;
        glide.running = true;
    }

    WheelHandler {
        parent: root.flick
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            event.accepted = true;
            const pad = event.device.type === PointerDevice.TouchPad || (event.pixelDelta.y !== 0 && Math.abs(event.angleDelta.y) < 120);
            if (pad && event.phase === Qt.ScrollMomentum) return;
            const now = Date.now();
            if (pad && event.phase === Qt.ScrollBegin) { root.speed = 0; glide.running = false; root.goal = root.flick.contentY; }
            if (pad && event.phase === Qt.ScrollEnd) {
                const coast = Math.max(-root.coastMax, Math.min(root.coastMax, root.speed * root.coast));
                root.speed = 0;
                if (Math.abs(coast) > 8) root.follow(coast, Math.min(260, root.glideStiff));
                return;
            }
            const d = pad
                ? -(event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8) * root.touchpad
                : -event.angleDelta.y * root.step;
            if (Math.abs(d) < 0.4) return;
            const dt = Math.max(4, Math.min(80, now - root.lastAt));
            root.speed = root.speed * 0.45 + (d / dt * 1000) * 0.55;
            root.lastAt = now;
            root.follow(d, pad ? 2200 : root.glideStiff);
        }
    }

    Connections {
        target: root.flick
        function onDraggingChanged() {
            if (!root.flick.dragging) return;
            glide.running = false;
            root.goal = root.flick.contentY;
            glide.value = root.flick.contentY;
            root.written = root.flick.contentY;
        }
        function onContentYChanged() {
            const y = root.flick.contentY;
            const delta = y - root.written;
            if (Math.abs(delta) < 1) return;
            if (root.flick.dragging || Math.abs(delta) > 280) {
                glide.running = false;
                root.goal = y;
                glide.value = y;
                root.written = y;
                return;
            }
            if (glide.running || Date.now() < root.ownUntil) root.flick.contentY = root.written;
            else { root.goal = y; glide.value = y; root.written = y; }
        }
    }

    Component.onCompleted: {
        flick.interactive = Qt.binding(() => flick.contentHeight + flick.topMargin + flick.bottomMargin > flick.height + 1);
        flick.boundsBehavior = Flickable.StopAtBounds;
        flick.boundsMovement = Flickable.StopAtBounds;
        root.goal = flick.contentY;
        root.written = flick.contentY;
        glide.value = flick.contentY;
    }
}

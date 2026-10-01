import QtQuick

FrameAnimation {
    id: root

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real damping: 0.7
    property real stiffness: 420
    property real epsilon: 0.0005
    property bool spring: true

    onTargetChanged: {
        if (spring) running = true;
        else {
            value = target;
            velocity = 0;
            running = false;
        }
    }
    Component.onCompleted: value = target

    onTriggered: {
        const dt = Math.min(frameTime, 0.05);
        const steps = Math.max(1, Math.ceil(dt / 0.004));
        const h = dt / steps;
        const k = stiffness;
        const c = 2 * damping * Math.sqrt(k);
        let x = value, v = velocity;
        for (let i = 0; i < steps; i++) {
            v += (-k * (x - target) - c * v) * h;
            x += v * h;
        }
        if (Math.abs(x - target) < epsilon && Math.abs(v) < epsilon * 20) {
            x = target;
            v = 0;
            running = false;
        }
        velocity = v;
        value = x;
    }
}

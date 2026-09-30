#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;
};
layout(binding = 1) uniform sampler2D source;

float chroma(vec3 c) {
    return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

void main() {
    float seen = 0.0;
    float colored = 0.0;
    for (int y = 0; y < 6; y++) {
        for (int x = 0; x < 6; x++) {
            vec4 s = texture(source, (vec2(x, y) + 0.5) / 6.0);
            if (s.a > 0.3) {
                seen += 1.0;
                colored += step(0.2, chroma(s.rgb / s.a));
            }
        }
    }
    float plain = 1.0 - smoothstep(0.08, 0.2, colored / max(seen, 1.0));

    vec4 c = texture(source, qt_TexCoord0);
    if (c.a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 rgb = c.rgb / c.a;
    float gray = 1.0 - smoothstep(0.06, 0.2, chroma(rgb));
    float light = smoothstep(0.35, 0.75, dot(rgb, vec3(0.299, 0.587, 0.114)));
    fragColor = vec4(mix(rgb, ink.rgb, gray * light * plain) * c.a, c.a) * qt_Opacity;
}

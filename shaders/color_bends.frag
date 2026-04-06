#include <flutter/runtime_effect.glsl>

// Uniforms — set via shader.setFloat(index, value)
// 0: uWidth, 1: uHeight, 2: uTime, 3: uSpeed
// 4: uRotCos, 5: uRotSin, 6: uScale, 7: uFrequency
// 8: uWarpStrength, 9: uNoise
uniform float uWidth;
uniform float uHeight;
uniform float uTime;
uniform float uSpeed;
uniform float uRotCos;
uniform float uRotSin;
uniform float uScale;
uniform float uFrequency;
uniform float uWarpStrength;
uniform float uNoise;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    float t = uTime * uSpeed;

    // Normalized UV [0,1] → [-1,1]
    vec2 vUv = fragCoord / vec2(uWidth, uHeight);
    vec2 p = vUv * 2.0 - 1.0;

    // Apply rotation
    vec2 rp = vec2(p.x * uRotCos - p.y * uRotSin,
                   p.x * uRotSin + p.y * uRotCos);

    // Aspect ratio correction + domain distortion
    vec2 q = vec2(rp.x * (uWidth / uHeight), rp.y);
    q /= max(uScale, 0.0001);
    q /= 0.5 + 0.2 * dot(q, q);
    q += 0.2 * cos(t) - 7.56;

    // Original reactbits algorithm (no-colors path):
    // Each RGB channel gets its own sine-warp iteration.
    // Unrolled — no arrays, no dynamic indexing → works on all GPUs.
    vec3 col = vec3(0.0);

    // ── Channel R ──
    {
        vec2 s = q - 0.01;
        vec2 r = sin(1.5 * (s.yx * uFrequency) + 2.0 * cos(s * uFrequency));
        float m0 = length(r + sin(5.0 * r.y * uFrequency - 3.0 * t + 0.0) / 4.0);
        float kb = clamp(uWarpStrength, 0.0, 1.0);
        float km = pow(kb, 0.3);
        float gain = 1.0 + max(uWarpStrength - 1.0, 0.0);
        vec2 warped = s + (r - s) * kb * gain;
        float m1 = length(warped + sin(5.0 * warped.y * uFrequency - 3.0 * t + 0.0) / 4.0);
        float m = mix(m0, m1, km);
        col.r = 1.0 - exp(-6.0 / exp(6.0 * m));
    }

    // ── Channel G ──
    {
        vec2 s = q - 0.02;
        vec2 r = sin(1.5 * (s.yx * uFrequency) + 2.0 * cos(s * uFrequency));
        float m0 = length(r + sin(5.0 * r.y * uFrequency - 3.0 * t + 1.0) / 4.0);
        float kb = clamp(uWarpStrength, 0.0, 1.0);
        float km = pow(kb, 0.3);
        float gain = 1.0 + max(uWarpStrength - 1.0, 0.0);
        vec2 warped = s + (r - s) * kb * gain;
        float m1 = length(warped + sin(5.0 * warped.y * uFrequency - 3.0 * t + 1.0) / 4.0);
        float m = mix(m0, m1, km);
        col.g = 1.0 - exp(-6.0 / exp(6.0 * m));
    }

    // ── Channel B ──
    {
        vec2 s = q - 0.03;
        vec2 r = sin(1.5 * (s.yx * uFrequency) + 2.0 * cos(s * uFrequency));
        float m0 = length(r + sin(5.0 * r.y * uFrequency - 3.0 * t + 2.0) / 4.0);
        float kb = clamp(uWarpStrength, 0.0, 1.0);
        float km = pow(kb, 0.3);
        float gain = 1.0 + max(uWarpStrength - 1.0, 0.0);
        vec2 warped = s + (r - s) * kb * gain;
        float m1 = length(warped + sin(5.0 * warped.y * uFrequency - 3.0 * t + 2.0) / 4.0);
        float m = mix(m0, m1, km);
        col.b = 1.0 - exp(-6.0 / exp(6.0 * m));
    }

    // Dither noise
    if (uNoise > 0.0001) {
        float n = fract(sin(dot(fragCoord + vec2(uTime), vec2(12.9898, 78.233))) * 43758.5453123);
        col += (n - 0.5) * uNoise;
        col = clamp(col, 0.0, 1.0);
    }

    // Transparent output — alpha from max channel (matches reactbits)
    float a = max(max(col.r, col.g), col.b);
    // Premultiplied alpha for Flutter
    fragColor = vec4(col * a, a);
}

// Splatter — Ghostty terminal shader
// Fractal paint splatters drifting behind terminal content
// Based on magic box fractal from Shadertoy sdjGRc

const int MAGIC_BOX_ITERS = 11;
const float MAGIC_BOX_MAGIC = 0.55;

// --- Tuning ---
const float SPLAT_OPACITY = 0.15;      // Overall paint visibility (0.0 - 1.0)
const float SPLAT_FALLOFF = 0.7;       // How far splatters spread before fading
const float SPLAT_CUTOFF = 0.65;       // Hard radius cutoff
const float CENTER_THRESH = 0.0;       // Fractal threshold at center (lower = more solid)
const float EDGE_THRESH = 60.0;        // Fractal threshold at edge (higher = more splattery)
const float DRIFT_SPEED = 0.03;        // Animation speed (fractal morph)
const int NUM_SPLATS = 8;

// Rotation matrix to slice fractal on non-axis-aligned plane
const mat3 M = mat3(
    0.28862355854826727, 0.6997227302779844, 0.6535170557707412,
    0.06997493955670424, 0.6653237235314099, -0.7432683571499161,
    -0.9548821651308448, 0.26025457467376617, 0.14306504491456504
);

// --- Human++ palette ---
vec3 paletteColor(int idx) {
    int i = idx % 5;
    if (i == 0) return vec3(0.906, 0.204, 0.612); // pink
    if (i == 1) return vec3(0.102, 0.816, 0.839); // cyan
    if (i == 2) return vec3(0.596, 0.443, 0.996); // purple
    if (i == 3) return vec3(0.949, 0.651, 0.200); // gold
    return vec3(0.271, 0.541, 0.886);              // blue
}

// --- Fractal core ---
float magicBox(vec3 p) {
    p = 1.0 - abs(1.0 - mod(p, 2.0));
    float lastLength = length(p);
    float tot = 0.0;
    for (int i = 0; i < MAGIC_BOX_ITERS; i++) {
        p = abs(p) / (lastLength * lastLength) - MAGIC_BOX_MAGIC;
        float newLength = length(p);
        tot += abs(newLength - lastLength);
        lastLength = newLength;
    }
    return tot;
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// --- Single splatter ---
vec4 computeSplat(vec2 center, float size, vec3 color, vec2 fragCoord, vec2 fracUV, float seed) {
    vec2 delta = fragCoord - center * iResolution.xy;
    float screenDist = length(delta) / iResolution.y;

    float cutoff = SPLAT_CUTOFF * size;
    if (screenDist > cutoff) return vec4(0.0);

    float falloff = SPLAT_FALLOFF * size;

    // Each splat samples a unique slice of the fractal volume
    vec3 p = 0.3 * M * vec3(fracUV + seed * 17.3, seed * 5.0);
    float result = magicBox(p);

    float threshold = mix(CENTER_THRESH, EDGE_THRESH, screenDist / falloff);

    if (result > threshold) {
        // Soft alpha from fractal density
        float alpha = smoothstep(threshold, threshold + 8.0, result);
        // Fade near the cutoff edge
        alpha *= smoothstep(cutoff, cutoff * 0.6, screenDist);
        return vec4(color, alpha);
    }
    return vec4(0.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    // Fractal UV: uniform aspect scaling + slow circular drift
    vec2 fracUV = fragCoord.xy / iResolution.yy;
    fracUV += vec2(
        sin(iTime * DRIFT_SPEED) * 0.5,
        cos(iTime * DRIFT_SPEED * 0.7) * 0.5
    );

    // Accumulate paint (front-to-back compositing)
    vec3 paint = vec3(0.0);
    float paintA = 0.0;

    for (int i = 0; i < NUM_SPLATS; i++) {
        float fi = float(i);

        // Pseudo-random center and size
        vec2 center = vec2(
            hash(fi * 127.1 + 311.7),
            hash(fi * 269.5 + 183.3)
        );
        float size = 0.5 + 0.6 * hash(fi * 419.2 + 71.9);
        vec3 col = paletteColor(i);

        vec4 splat = computeSplat(center, size, col, fragCoord, fracUV, fi);

        // Layer: new paint only fills unpainted areas
        paint = mix(paint, splat.rgb, splat.a * (1.0 - paintA));
        paintA = paintA + splat.a * (1.0 - paintA);
    }

    // Composite: paint behind terminal content
    // Paint is more visible through dark background, fades under bright text
    float termLuma = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float visibility = SPLAT_OPACITY * (1.0 - termLuma * 0.85);

    fragColor = vec4(mix(terminal.rgb, paint, paintA * visibility), 1.0);
}

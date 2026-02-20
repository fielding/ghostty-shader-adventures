// Cursor Glitch — stackable cursor-localized digital interference
// Stack on any base shader: displaces, tears, and RGB-splits near the cursor.
// When idle, passes through unchanged (zero cost).
//
// Usage (stack after any base shader):
//   custom-shader = /path/to/splatter.glsl
//   custom-shader = /path/to/cursor-glitch.glsl

// --- Tuning ---
const float GLITCH_RADIUS = 0.15;       // Base radius of glitch zone
const float GLITCH_BLOOM = 0.10;        // Extra radius when typing
const float TEAR_STRENGTH = 0.04;       // How far scanlines shift horizontally
const float RGB_SPLIT_MAX = 0.005;      // Max chromatic aberration offset
const float STATIC_DENSITY = 0.03;      // Sparse digital noise density

// --- Noise ---
float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453123);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// --- Cursor ---
vec2 getCursorCenter(vec4 rect) {
    return vec2(rect.x + rect.z * 0.5, rect.y - rect.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 curPos = getCursorCenter(iCurrentCursor);
    float heat = smoothstep(3.0, 0.05, iTime - iTimeCursorChange);

    // Glitch intensity: falls off with distance from cursor, scales with typing
    float curDist = length(fragCoord - curPos) / iResolution.y;
    float radius = GLITCH_RADIUS + GLITCH_BLOOM * heat;
    float intensity = smoothstep(radius, radius * 0.1, curDist) * heat;

    vec2 displaced = uv;

    if (intensity > 0.01) {
        // Scanline tear — coherent per line, changes every ~4 frames
        float scanSeed = float(int(fragCoord.y) * 13 + iFrame / 4);
        float lineHash = hash11(scanSeed);

        if (lineHash < intensity * 0.5) {
            float tearDir = (lineHash < intensity * 0.25) ? 1.0 : -1.0;
            displaced.x += tearDir * intensity * TEAR_STRENGTH * (0.3 + lineHash * 2.0);
        }

        // Block displacement — 8px tall blocks occasionally jump vertically
        float blockSeed = floor(fragCoord.y / 8.0) * 7.13 + float(iFrame / 6);
        float blockHash = hash11(blockSeed);
        if (blockHash < intensity * 0.1) {
            displaced.y += (blockHash * 2.0 - 1.0) * intensity * 0.03;
        }
    }

    displaced = clamp(displaced, 0.0, 1.0);

    // RGB channel separation — offset red/blue horizontally
    float split = intensity * RGB_SPLIT_MAX;
    vec3 color;
    color.r = texture(iChannel0, clamp(displaced + vec2(split, 0.0), 0.0, 1.0)).r;
    color.g = texture(iChannel0, displaced).g;
    color.b = texture(iChannel0, clamp(displaced - vec2(split, 0.0), 0.0, 1.0)).b;

    // Digital static — sparse bright/dark pixels near cursor
    if (intensity > 0.05) {
        float noise = hash21(fragCoord + float(iFrame) * 0.173);
        float threshold = 1.0 - intensity * STATIC_DENSITY;
        if (noise > threshold) {
            float bright = step(0.5, fract(noise * 7.0));
            color = mix(color, vec3(bright), 0.6 * intensity);
        }
    }

    fragColor = vec4(color, 1.0);
}

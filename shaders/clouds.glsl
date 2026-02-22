// Clouds — soft animated clouds drifting behind terminal text
// Ghostty terminal shader inspired by Shadertoy ld3GWS
//
// Layered FBM noise creates slowly drifting cloud formations.
// Cursor proximity brightens nearby clouds. Typing stirs them up.

// --- Tuning ---
const float CLOUD_OPACITY = 0.18;     // How visible clouds are overall
const float CLOUD_SCALE = 3.0;        // Zoom level (smaller = bigger clouds)
const float DRIFT_SPEED = 0.04;       // How fast clouds move
const float TURBULENCE = 0.02;        // Extra stir speed when typing
const float CURSOR_GLOW = 0.12;       // Warm glow near cursor
const float CURSOR_RANGE = 0.2;       // How far cursor brightens clouds

// --- Human++ palette ---
const vec3 COL_PINK   = vec3(0.906, 0.204, 0.612);
const vec3 COL_CYAN   = vec3(0.102, 0.816, 0.839);
const vec3 COL_PURPLE = vec3(0.596, 0.443, 0.996);
const vec3 COL_GOLD   = vec3(0.949, 0.651, 0.200);
const vec3 COL_BLUE   = vec3(0.271, 0.541, 0.886);

// --- Noise ---
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// FBM with configurable octaves
float fbm(vec2 p, int octaves) {
    float v = 0.0, a = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8); // rotate each octave to reduce grid artifacts
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        v += a * vnoise(p);
        p = rot * p * 2.0 + 0.1;
        a *= 0.5;
    }
    return v;
}

// --- Cloud layer ---
// Each layer drifts at a different speed/direction for parallax depth
float cloudLayer(vec2 uv, float time, float speed, float scale, int detail) {
    vec2 drift = vec2(time * speed, time * speed * 0.4);
    float n = fbm((uv + drift) * scale, detail);
    // Shape clouds: push values toward 0 (clear) or 1 (cloudy)
    return smoothstep(0.35, 0.65, n);
}

// --- Cursor helper ---
vec2 getCursorCenter(vec4 rect) {
    return vec2(rect.x + rect.z * 0.5, rect.y - rect.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    // Aspect-correct UV for cloud sampling
    vec2 cloudUV = fragCoord.xy / iResolution.yy;

    // Typing heat
    float timeSinceType = iTime - iTimeCursorChange;
    float heat = smoothstep(3.0, 0.05, timeSinceType);

    // Time with slight acceleration when typing
    float t = iTime * DRIFT_SPEED + heat * TURBULENCE * sin(iTime * 2.0);

    // --- Cloud layers (back to front, different speeds for parallax) ---

    // Deep background layer: large, slow, purple-blue
    float c1 = cloudLayer(cloudUV, iTime, DRIFT_SPEED * 0.5, CLOUD_SCALE * 0.6, 6);
    vec3 col1 = mix(COL_PURPLE, COL_BLUE, 0.5) * c1;

    // Mid layer: medium, moderate speed, cyan-blue
    float c2 = cloudLayer(cloudUV, iTime, DRIFT_SPEED * 0.8, CLOUD_SCALE * 0.9, 5);
    vec3 col2 = mix(COL_CYAN, COL_BLUE, 0.6) * c2;

    // Near layer: smaller detail, faster, pink-gold highlights
    float c3 = cloudLayer(cloudUV, iTime, DRIFT_SPEED * 1.2, CLOUD_SCALE * 1.4, 4);
    vec3 col3 = mix(COL_PINK, COL_GOLD, 0.4) * c3;

    // Combine layers (back to front blending)
    vec3 clouds = col1 * 0.4 + col2 * 0.5 + col3 * 0.3;
    float cloudAlpha = max(max(c1 * 0.4, c2 * 0.5), c3 * 0.3);

    // --- Cursor interaction ---
    vec2 curPos = getCursorCenter(iCurrentCursor);
    vec2 curOffset = (fragCoord - curPos) / iResolution.y;
    float curDist = length(curOffset);

    // Clouds brighten near cursor
    float proximity = 1.0 - smoothstep(0.0, CURSOR_RANGE, curDist);
    clouds *= 1.0 + proximity * heat * 1.5;

    // Subtle warm glow at cursor
    float glow = exp(-curDist * curDist * 80.0) * CURSOR_GLOW * heat;
    vec3 glowCol = mix(COL_GOLD, COL_PINK, sin(iTime * 0.3) * 0.5 + 0.5);

    // --- Composite ---
    float termLuma = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float visibility = CLOUD_OPACITY * (1.0 - termLuma * 0.8);

    vec3 result = mix(terminal.rgb, clouds, cloudAlpha * visibility);
    result += glowCol * glow;

    fragColor = vec4(result, 1.0);
}

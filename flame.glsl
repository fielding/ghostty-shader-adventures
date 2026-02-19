// Flame — cursor-localized 3D raymarched fire
// Ghostty terminal shader inspired by iq's Shadertoy MdX3zr
//
// A volumetric flame rises from the cursor. Typing stokes it,
// idle lets it simmer down to a pilot light. Cursor movement
// makes the flame lean briefly in the opposite direction.

// --- Tuning ---
const float FLAME_RADIUS = 0.28;      // How far flame reaches from cursor (screen fraction)
const float FLAME_SCALE = 0.15;       // World-space size of flame
const int MARCH_STEPS = 50;           // Raymarch quality (30 = fast, 50 = nice, 70 = lush)
const float IDLE_INTENSITY = 0.35;    // Flame size when not typing (0 = off, 1 = full)
const float HEAT_FADE = 3.0;          // Seconds for typing heat to dissipate
const float LEAN_STRENGTH = 0.4;      // How much flame leans on cursor movement
const float GLOW_STRENGTH = 0.12;     // Warm halo around flame base
const float FLAME_BRIGHTNESS = 1.2;   // Overall brightness of the fire

// --- 3D Noise ---
float hash31(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash31(i),               hash31(i + vec3(1,0,0)), u.x),
            mix(hash31(i + vec3(0,1,0)),  hash31(i + vec3(1,1,0)), u.x), u.y),
        mix(mix(hash31(i + vec3(0,0,1)),  hash31(i + vec3(1,0,1)), u.x),
            mix(hash31(i + vec3(0,1,1)),  hash31(i + vec3(1,1,1)), u.x), u.y),
        u.z
    );
}

float fbm3d(vec3 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vnoise3(p);
        p = p * 2.0 + 0.1;
        a *= 0.5;
    }
    return v;
}

// --- Flame volume ---
// Noise SUBTRACTS from the base shape, carving ragged fire edges.
// A contrast curve snaps density toward crisp boundaries.
float flameDensity(vec3 p, float time, float intensity) {
    float y = p.y;
    if (y < -0.3 || y > 2.5) return 0.0;

    // Base cone shape: wide at bottom, tapers to tip
    float baseWidth = 0.35 * intensity;
    float taper = max(0.05, 1.0 - y * 0.45);
    float width = baseWidth * taper;
    float horiz = length(p.xz);

    // Sharper cone edge (narrower smoothstep band)
    float base = smoothstep(width, width * 0.02, horiz);
    base *= smoothstep(-0.15, 0.05, y);
    base *= 1.0 - smoothstep(0.3 * intensity, 1.4 * intensity, y);

    // Large turbulence — carves shape, stronger at tips
    vec3 np = p * vec3(3.0, 2.0, 3.0);
    np.y -= time * 3.5;
    np.xz += vec2(sin(time * 0.7), cos(time * 0.9)) * 0.2;
    float turb = fbm3d(np) * (0.4 + y * 0.4);

    // Medium detail — flickering tongues (higher freq)
    vec3 mp = p * vec3(6.0, 4.5, 6.0);
    mp.y -= time * 6.0;
    float med = vnoise3(mp) * 0.2 * (0.5 + y * 0.5);

    // Fine crackle (high freq, fast scroll)
    vec3 fp = p * vec3(12.0, 9.0, 12.0);
    fp.y -= time * 10.0;
    float fine = vnoise3(fp) * 0.08;

    // Noise subtracts from base = ragged edges, tongues, gaps
    float d = base - turb - med - fine;

    // Contrast curve: sharpen toward crisp fire edges
    d = smoothstep(0.0, 0.12, d);

    return clamp(d * intensity, 0.0, 1.0);
}

// --- Fire color ---
// Color is driven by BOTH height and local density.
// Dense regions = hotter = brighter. Tips = cooler = redder.
vec3 flameColor(float density, float y, float intensity) {
    vec3 core  = vec3(1.0, 0.95, 0.8);
    vec3 inner = vec3(1.0, 0.8, 0.3);
    vec3 mid   = vec3(1.0, 0.4, 0.05);
    vec3 outer = vec3(0.7, 0.12, 0.01);
    vec3 smoke = vec3(0.25, 0.04, 0.0);

    // Height drives base color
    float t = clamp(y / (1.4 * intensity), 0.0, 1.0);
    vec3 col = core;
    col = mix(col, inner, smoothstep(0.0,  0.1,  t));
    col = mix(col, mid,   smoothstep(0.1,  0.3,  t));
    col = mix(col, outer, smoothstep(0.3,  0.6,  t));
    col = mix(col, smoke, smoothstep(0.6,  1.0,  t));

    // Density pushes toward hotter colors (dense = bright core)
    col = mix(col, core, density * 0.4);

    return col;
}

// --- Cursor helpers ---
vec2 getCursorCenter(vec4 rect) {
    return vec2(rect.x + rect.z * 0.5, rect.y - rect.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    // Cursor positions (pixels)
    vec2 curPos  = getCursorCenter(iCurrentCursor);
    vec2 prevPos = getCursorCenter(iPreviousCursor);

    // Typing heat
    float timeSinceType = iTime - iTimeCursorChange;
    float heat = smoothstep(HEAT_FADE, 0.05, timeSinceType);
    float intensity = IDLE_INTENSITY + (1.0 - IDLE_INTENSITY) * heat;
    float radius = FLAME_RADIUS * intensity;

    // Screen-space offset from cursor
    vec2 offset = (fragCoord - curPos) / iResolution.y;
    float dist = length(offset);

    // Early out — most pixels skip the raymarch entirely
    if (dist > radius) {
        fragColor = terminal;
        return;
    }

    // Flame-local coordinates
    // Ghostty's y-axis points DOWN on screen, so flip for flame to rise upward
    vec2 flameXY = offset / FLAME_SCALE;
    flameXY.y = -flameXY.y;

    // Cursor movement makes flame lean opposite direction
    vec2 moveDelta = (curPos - prevPos) / iResolution.y;
    float moveMag = length(moveDelta);
    if (moveMag > 0.001) {
        float lean = min(moveMag * 5.0, LEAN_STRENGTH) * exp(-timeSinceType * 3.0);
        flameXY.x -= normalize(moveDelta).x * lean / FLAME_SCALE;
    }

    // Raymarch through flame volume (front to back along z)
    float stepSize = 2.0 / float(MARCH_STEPS);
    float marchZ = 0.0;

    // Accumulate emitted light and absorption (volumetric rendering)
    vec3 emission = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < MARCH_STEPS; i++) {
        if (transmittance < 0.05) break;

        vec3 p = vec3(flameXY, -1.0 + marchZ);
        float d = flameDensity(p, iTime, intensity);

        if (d > 0.01) {
            vec3 fc = flameColor(d, p.y, intensity);

            // Fire emits light proportional to density
            emission += fc * d * stepSize * transmittance * 6.0;
            // And absorbs a little (so you can't see through dense fire)
            transmittance *= exp(-d * stepSize * 2.0);
        }

        marchZ += stepSize;
    }

    // Soft edge fade
    float edgeFade = smoothstep(radius, radius * 0.4, dist);

    // Warm glow halo at cursor base
    float glow = exp(-dist * dist / (0.005 * intensity)) * GLOW_STRENGTH * heat;

    // Composite: fire is additive (it emits light)
    vec3 result = terminal.rgb * (transmittance + (1.0 - transmittance) * 0.3);
    result += emission * edgeFade * FLAME_BRIGHTNESS;
    result += vec3(1.0, 0.55, 0.15) * glow;

    fragColor = vec4(result, 1.0);
}

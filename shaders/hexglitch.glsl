// Hex Glitch — hexagonal interference with CRT glitch effects
// Ported from Shadertoy lfscD7 for Ghostty terminal
//
// Hexagonal tiling with ripple interference creates morphing Moiré patterns
// that rotate and shift. CRT-style glitch displacement adds digital chaos.

// ─── Tuning ─────────────────────────────────────────────────────────────────

const float PATTERN_OPACITY = 0.20;        // Overall hex pattern visibility
const float MORPH_SPEED = 0.15;            // Speed of pattern morphing
const float GLITCH_FREQ = 0.15;            // How often glitch bands appear
const float RING_RADIUS = 0.06;            // Inversion ring base radius
const float RING_BLOOM = 0.04;             // Extra ring radius when typing
const float VIGNETTE_STRENGTH = 0.3;       // Edge darkening

// ─── Human++ palette ────────────────────────────────────────────────────────

const vec3 COL_PINK   = vec3(0.906, 0.204, 0.612);
const vec3 COL_CYAN   = vec3(0.102, 0.816, 0.839);
const vec3 COL_PURPLE = vec3(0.596, 0.443, 0.996);
const vec3 COL_GOLD   = vec3(0.949, 0.651, 0.200);
const vec3 COL_BLUE   = vec3(0.271, 0.541, 0.886);

// ─── Math ───────────────────────────────────────────────────────────────────

#define kPi    3.14159265359
#define kTwoPi 6.28318530718

float sqr(float a)       { return a * a; }
float saturate(float a)  { return clamp(a, 0.0, 1.0); }
vec3  saturate(vec3 a)   { return clamp(a, 0.0, 1.0); }
float sin01(float a)     { return 0.5 * sin(a) + 0.5; }
float cos01(float a)     { return 0.5 * cos(a) + 0.5; }
float toRad(float deg)   { return kTwoPi * deg / 360.0; }
float cwiseMax(vec3 v)   { return max(v.x, max(v.y, v.z)); }

float SmoothStep3(float x) { return x * x * (3.0 - 2.0 * x); }

float PaddedSmoothStep(float x, float a, float b) {
    return SmoothStep3(clamp(x * (a + b + 1.0) - a, 0.0, 1.0));
}
float PaddedSmoothStep(float x, float a) { return PaddedSmoothStep(x, a, a); }

float KickDrop(float t, vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
    if (t < p1.x)
        return mix(p0.y, p1.y, max(0.0, exp(-sqr((t - p1.x) * 2.146 / (p1.x - p0.x))) - 0.01) / 0.99);
    else if (t < p2.x)
        return mix(p1.y, p2.y, (t - p1.x) / (p2.x - p1.x));
    else
        return mix(p3.y, p2.y, max(0.0, exp(-sqr((t - p2.x) * 2.146 / (p3.x - p2.x))) - 0.01) / 0.99);
}

// ─── Hash (FNV) ─────────────────────────────────────────────────────────────

uint HashCombine(uint a, uint b) {
    return (((a << (31u - (b & 31u))) | (a >> (b & 31u)))) ^
           ((b << (a & 31u)) | (b >> (31u - (a & 31u))));
}

uint HashOf(uint i) {
    uint h = (0x811c9dc5u ^ (i & 0xffu)) * 0x01000193u;
    h = (h ^ ((i >> 8u)  & 0xffu)) * 0x01000193u;
    h = (h ^ ((i >> 16u) & 0xffu)) * 0x01000193u;
    h = (h ^ ((i >> 24u) & 0xffu)) * 0x01000193u;
    return h;
}

uint HashOf(uint a, uint b)                 { return HashCombine(HashOf(a), HashOf(b)); }
uint HashOf(uint a, uint b, uint c)         { return HashCombine(HashCombine(HashOf(a), HashOf(b)), HashOf(c)); }
uint HashOf(uint a, uint b, uint c, uint d) { return HashCombine(HashCombine(HashOf(a), HashOf(b)), HashCombine(HashOf(c), HashOf(d))); }

float HashToFloat(uint i) { return float(i) / float(0xffffffffu); }

// ─── PCG Random ─────────────────────────────────────────────────────────────

uvec4 rngSeed;

uvec4 PCGAdvance() {
    rngSeed = rngSeed * 1664525u + 1013904223u;
    rngSeed.x += rngSeed.y * rngSeed.w;
    rngSeed.y += rngSeed.z * rngSeed.x;
    rngSeed.z += rngSeed.x * rngSeed.y;
    rngSeed.w += rngSeed.y * rngSeed.z;
    rngSeed ^= rngSeed >> 16u;
    rngSeed.x += rngSeed.y * rngSeed.w;
    rngSeed.y += rngSeed.z * rngSeed.x;
    rngSeed.z += rngSeed.x * rngSeed.y;
    rngSeed.w += rngSeed.y * rngSeed.z;
    return rngSeed;
}

vec4 Rand() { return vec4(PCGAdvance()) / float(0xffffffffu); }

void PCGInitialise(uint seed) { rngSeed = uvec4(20219u, 7243u, 12547u, 28573u) * seed; }

uint RadicalInverse(uint i) {
    i = ((i & 0xffffu) << 16u) | (i >> 16u);
    i = ((i & 0x00ff00ffu) << 8u)  | ((i & 0xff00ff00u) >> 8u);
    i = ((i & 0x0f0f0f0fu) << 4u)  | ((i & 0xf0f0f0f0u) >> 4u);
    i = ((i & 0x33333333u) << 2u)  | ((i & 0xccccccccu) >> 2u);
    i = ((i & 0x55555555u) << 1u)  | ((i & 0xaaaaaaaau) >> 1u);
    return i;
}

float HaltonBase2(uint i) { return float(RadicalInverse(i)) / float(0xffffffffu); }

// ─── Ordered Dither ─────────────────────────────────────────────────────────

const mat4 kOrderedDither = mat4(
    vec4(0., 8., 2., 10.), vec4(12., 4., 14., 6.),
    vec4(3., 11., 1., 9.), vec4(15., 7., 13., 5.)
);

float OrderedDither(ivec2 p) {
    return (kOrderedDither[p.x & 3][p.y & 3] + 1.0) / 17.0;
}

// ─── Hexagonal Tiling ───────────────────────────────────────────────────────

#define kHexRatio vec2(1.5, 0.8660254037844387)
#define kBaryScale 0.5773502691896257

vec3 Cartesian2DToBarycentric(vec2 p) {
    return vec3(p, 0.0) * mat3(
        vec3(0.0, 1.0 / 0.8660254037844387, 0.0),
        vec3(1.0, kBaryScale, 0.0),
        vec3(-1.0, kBaryScale, 0.0)
    );
}

vec2 HexTile(in vec2 uv, out vec3 bary, out ivec2 ij) {
    vec2 uvClip = mod(uv + kHexRatio, 2.0 * kHexRatio) - kHexRatio;
    ij = ivec2((uv + kHexRatio) / (2.0 * kHexRatio)) * 2;
    if (uv.x + kHexRatio.x <= 0.0) ij.x -= 2;
    if (uv.y + kHexRatio.y <= 0.0) ij.y -= 2;

    bary = Cartesian2DToBarycentric(uvClip);
    if (bary.x > 0.0) {
        if (bary.z > 1.0)      { bary += vec3(-1, 1, -2); ij += ivec2(-1, 1); }
        else if (bary.y > 1.0) { bary += vec3(-1, -2, 1); ij += ivec2(1, 1); }
    } else {
        if (bary.y < -1.0)     { bary += vec3(1, 2, -1); ij += ivec2(-1, -1); }
        else if (bary.z < -1.0){ bary += vec3(1, -1, 2); ij += ivec2(1, -1); }
    }

    return vec2(bary.y * kBaryScale - bary.z * kBaryScale, bary.x);
}

// ─── Transforms ─────────────────────────────────────────────────────────────

vec2 ScreenToWorld(vec2 p, vec2 res) {
    return (p - res * 0.5) / res.y;
}

mat3 ViewMatrix(float rot, float sca) {
    float c = cos(rot) / sca, s = sin(rot) / sca;
    return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(1.0));
}

// ─── Color ──────────────────────────────────────────────────────────────────

vec3 Hue(float phi) {
    float c = 6.0 * phi;
    int i = int(c);
    vec3 c0 = vec3(((i + 4) / 3) & 1, ((i + 2) / 3) & 1, (i / 3) & 1);
    vec3 c1 = vec3(((i + 5) / 3) & 1, ((i + 3) / 3) & 1, ((i + 1) / 3) & 1);
    return mix(c0, c1, c - float(i));
}

vec3 HSVToRGB(vec3 hsv) { return mix(vec3(0.0), mix(vec3(1.0), Hue(hsv.x), hsv.y), hsv.z); }

vec3 RGBToHSV(vec3 rgb) {
    vec3 hsv;
    hsv.z = max(rgb.x, max(rgb.y, rgb.z));
    float chroma = hsv.z - min(rgb.x, min(rgb.y, rgb.z));
    hsv.y = (hsv.z < 1e-10) ? 0.0 : chroma / hsv.z;
    if (chroma < 1e-10)        hsv.x = 0.0;
    else if (hsv.z == rgb.x)   hsv.x = (1.0 / 6.0) * (rgb.y - rgb.z) / chroma;
    else if (hsv.z == rgb.y)   hsv.x = (1.0 / 6.0) * (2.0 + (rgb.z - rgb.x) / chroma);
    else                       hsv.x = (1.0 / 6.0) * (4.0 + (rgb.x - rgb.y) / chroma);
    hsv.x = fract(hsv.x + 1.0);
    return hsv;
}

vec3 Overlay(vec3 a, vec3 b) {
    return vec3(
        (a.x < 0.5) ? (2.0 * a.x * b.x) : (1.0 - 2.0 * (1.0 - a.x) * (1.0 - b.x)),
        (a.y < 0.5) ? (2.0 * a.y * b.y) : (1.0 - 2.0 * (1.0 - a.y) * (1.0 - b.y)),
        (a.z < 0.5) ? (2.0 * a.z * b.z) : (1.0 - 2.0 * (1.0 - a.z) * (1.0 - b.z))
    );
}

vec3 paletteColor(float t) {
    t = fract(t);
    if (t < 0.2)      return mix(COL_CYAN, COL_BLUE, t * 5.0);
    else if (t < 0.4) return mix(COL_BLUE, COL_PURPLE, (t - 0.2) * 5.0);
    else if (t < 0.6) return mix(COL_PURPLE, COL_PINK, (t - 0.4) * 5.0);
    else if (t < 0.8) return mix(COL_PINK, COL_GOLD, (t - 0.6) * 5.0);
    else               return mix(COL_GOLD, COL_CYAN, (t - 0.8) * 5.0);
}

// ─── Core hex pattern ───────────────────────────────────────────────────────

vec3 HexRender(vec2 uvScreen, vec2 res, bool isDisplaced, vec2 cursorPos, float heat, out float blend) {
    #define kTurns 7
    #define kNumRipples 5
    #define kRippleDelay (float(kNumRipples) / float(kTurns))
    #define kMaxIter 2

    // Per-pixel random values (replaces texture-based Rand)
    PCGInitialise(HashOf(uint(uvScreen.x), uint(uvScreen.y), uint(iFrame)));
    vec4 xi = Rand();
    uint hash = HashOf(98796523u, uint(uvScreen.x), uint(uvScreen.y));
    xi.y = HaltonBase2(hash);
    xi.x = xi.y;

    // Time with per-pixel motion blur offset
    float mblur = isDisplaced ? 100.0 : 10.0;
    float time = (iTime + xi.y * mblur / 60.0) * MORPH_SPEED;

    // Phase and interval control the animation state
    float phase = fract(time);
    int interval = (int(time) & 1) << 1;
    float morph, warpedTime;

    if (phase < 0.85) {
        float y = (interval == 0) ? uvScreen.y : (res.y - uvScreen.y);
        warpedTime = (phase / 0.85) - 0.2 * sqrt(y / res.y) - 0.1;
        phase = fract(warpedTime);
        morph = 1.0 - PaddedSmoothStep(sin01(kTwoPi * phase), 0.0, 0.4);
        blend = float(interval / 2) * 0.5;
        if (interval == 2) warpedTime *= 0.5;
    } else {
        time -= 0.8 * MORPH_SPEED * xi.y * mblur / 60.0;
        warpedTime = time;
        phase = (fract(time) - 0.85) / 0.15;
        morph = 1.0;
        blend = (KickDrop(phase, vec2(0.0), vec2(0.2, -0.1), vec2(0.3, -0.1), vec2(0.7, 1.0))
                 + float(interval / 2)) * 0.5;
        interval++;
    }

    float beta = abs(2.0 * max(0.0, blend) - 1.0);
    float expMorph = pow(morph, 0.3);
    float kThickness = mix(0.5, 0.4, morph);
    float kExponent = mix(0.05, 0.55, morph);
    float kScale = mix(2.6, 1.1, expMorph);

    // View transform: rotation keyed to blend, fixed zoom
    mat3 M = ViewMatrix(blend * kTwoPi, 0.35);
    vec2 uvView = ScreenToWorld(uvScreen, res);
    int invert = 0;

    // Chromatic aberration (subtle radial distortion)
    uvView /= 1.0 + 0.05 * length(uvView) * xi.z;
    uvView = (vec3(uvView, 1.0) * M).xy;

    // Warp space for the pattern
    vec2 uvWarp = uvView;
    uvWarp.y *= mix(1.0, 0.1, sqr(1.0 - morph) * xi.y * saturate(sqr(0.5 * (1.0 + uvView.y))));

    float theta = toRad(30.0) * beta;
    mat2 r = mat2(cos(theta), -sin(theta), sin(theta), cos(theta));
    uvWarp = r * uvWarp;

    // Iterate: each pass tiles, checks sub-hexagons, computes ripples, then zooms in
    for (int iterIdx = 0; iterIdx < kMaxIter; ++iterIdx) {
        vec3 bary; ivec2 ij;
        HexTile(uvWarp, bary, ij);

        if (!isDisplaced && ij != ivec2(0)) break;

        // Sub-hexagon subdivision — creates checkerboard fill within hexes
        int subdiv = 1 + int(exp(-sqr(10.0 * mix(-1.0, 1.0, phase))) * 100.0);
        float thetaSub = kTwoPi * (floor(cos01(kTwoPi * phase) * 12.0) / 6.0);

        HexTile(
            uvWarp * (0.1 + float(subdiv))
            - kHexRatio.y * vec2(sin(thetaSub), cos(thetaSub))
              * floor(0.5 + sin01(kTwoPi * phase) * 2.0) / 2.0,
            bary, ij
        );

        uint hexHash = HashOf(uint(phase * 6.0), uint(subdiv), uint(ij.x), uint(ij.y));
        if (hexHash % 2u == 0u) {
            float alpha = PaddedSmoothStep(sin01(phase * 20.0), 0.2, 0.75);
            float dist = mix(cwiseMax(abs(bary)), length(uvView) * 2.5, 1.0 - alpha);
            float hashSum = bary[int(hexHash % 3u)] + bary[int((hexHash + 1u) % 3u)];

            if (dist > 1.0 - 0.02 * float(subdiv)) invert ^= 1;
            else if (fract(20.0 / float(subdiv) * hashSum) < 0.5) invert ^= 1;
            if (iterIdx == 0) break;
        }

        // Ripple interference — concentric waves from multiple sources create Moiré
        float sigma = 0.0, sigmaW = 0.0;
        for (int j = 0; j < kTurns; ++j) {
            float thetaR = kTwoPi * float(j) / float(kTurns);
            for (int i = 0; i < kNumRipples; ++i) {
                float l = length(uvWarp - vec2(cos(thetaR), sin(thetaR))) * 0.5;
                float w = log2(1.0 / (l + 1e-10));
                sigma += fract(l - pow(
                    fract((float(j) + float(i) / kRippleDelay) / float(kTurns) + warpedTime),
                    kExponent
                )) * w;
                sigmaW += w;
            }
        }
        invert ^= int((sigma / sigmaW) > kThickness);

        // Transform for next iteration: rotate, translate, scale
        theta = kTwoPi * (floor(cos01(kTwoPi * -phase) * 30.0) / 6.0);
        uvWarp = r * (uvWarp + vec2(cos(theta), sin(theta)) * 0.5);
        uvWarp *= kScale;
    }

    // Inversion ring around cursor
    float curDist = length(uvScreen - cursorPos) / res.y;
    float ringRadius = RING_RADIUS + RING_BLOOM * heat;
    float ringWidth = 0.008 + 0.004 * heat;
    float ring = smoothstep(ringRadius - ringWidth, ringRadius, curDist)
               - smoothstep(ringRadius, ringRadius + ringWidth, curDist);
    if (ring > 0.5) invert ^= 1;

    // Final color: black/white with palette bleed during transitions
    vec3 result = vec3(float(invert != 0));
    return mix(1.0 - result, result * mix(vec3(1.0), paletteColor(xi.x), sqr(beta)), beta);
}

// ─── CRT Glitch ─────────────────────────────────────────────────────────────

bool Interfere(inout vec2 xy, vec2 res) {
    float frameHash = HashToFloat(HashOf(uint(iFrame / 10)));
    bool isDisplaced = false;

    // Static: occasional scanline jitter (CRT PAL interference)
    float interP = 0.01, disp = res.x * 0.01;
    if (frameHash < 0.1) {
        interP = 0.5;
        disp = 0.02 * res.x;
    }
    PCGInitialise(HashOf(uint(xy.y / 2.0), uint(iFrame / 2)));
    vec4 xi = Rand();
    if (xi.x < interP) {
        float mag = mix(-1.0, 1.0, xi.y);
        xy.x -= disp * sign(mag) * sqr(abs(mag));
    }

    // Vertical band displacement
    if (frameHash > 1.0 - GLITCH_FREQ * 0.47) {
        float dX = HashToFloat(HashOf(8783u, uint(iFrame / 10)));
        float dY = HashToFloat(HashOf(364719u, uint(iFrame / 12)));
        if (xy.y < dX * res.y) {
            xy.y -= mix(-1.0, 1.0, dY) * res.y * 0.2;
            isDisplaced = true;
        }
    }
    // Horizontal band displacement
    else if (frameHash > 1.0 - GLITCH_FREQ) {
        float dX = HashToFloat(HashOf(147251u, uint(iFrame / 9)));
        float dY = HashToFloat(HashOf(287512u, uint(iFrame / 11)));
        float dZ = HashToFloat(HashOf(8756123u, uint(iFrame / 7)));
        if (xy.y > dX * res.y && xy.y < (dX + 0.1 * dZ) * res.y) {
            xy.x -= mix(-1.0, 1.0, dY) * res.x * 0.5;
            isDisplaced = true;
        }
    }

    return isDisplaced;
}

// ─── Cursor ─────────────────────────────────────────────────────────────────

vec2 getCursorCenter(vec4 rect) {
    return vec2(rect.x + rect.z * 0.5, rect.y - rect.w * 0.5);
}

// ─── Main ───────────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Glitch displacement (affects both terminal and hex pattern)
    vec2 xy = fragCoord;
    bool isDisplaced = Interfere(xy, iResolution.xy);

    // Read terminal at (possibly displaced) position
    vec2 termUV = clamp(xy / iResolution.xy, 0.0, 1.0);
    vec4 terminal = texture(iChannel0, termUV);

    // Ordered dither for posterization in glitch regions
    ivec2 xyDith = ivec2(xy) / max(1, int(HashOf(
        uint(iTime + sin(iTime) * 1.5), uint(xy.x / 128.0), uint(xy.y / 128.0)
    ) & 127u));
    float jpegDmg = OrderedDither(xyDith);

    // Cursor state
    vec2 curPos = getCursorCenter(iCurrentCursor);
    float heat = smoothstep(3.0, 0.05, iTime - iTimeCursorChange);

    // Render hex interference pattern
    float blend;
    vec3 hex = HexRender(xy, iResolution.xy, isDisplaced, curPos, heat, blend);

    // Posterize displaced regions (JPEG damage effect)
    if (isDisplaced) {
        hex *= 5.0;
        hex.x += (fract(hex.x) > jpegDmg) ? 1.0 : 0.0;
        hex.y += (fract(hex.y) > jpegDmg) ? 1.0 : 0.0;
        hex.z += (fract(hex.z) > jpegDmg) ? 1.0 : 0.0;
        hex = floor(hex) / 5.0;
    }

    // Color grading: overlay tint + HSV hue shift + gamma
    hex = mix(hex, Overlay(hex, vec3(0.15, 0.29, 0.39)), blend);
    vec3 hsv = RGBToHSV(hex);
    hsv.x += -sin((hsv.x + 0.05) * kTwoPi) * 0.07;
    hex = HSVToRGB(hsv);
    hex = saturate(hex);
    hex = pow(hex, vec3(0.8));
    hex = mix(vec3(0.1), vec3(0.9), hex);

    // Vignette
    vec2 vuv = fragCoord / iResolution.xy;
    vuv.x = (vuv.x - 0.5) * (iResolution.x / iResolution.y) + 0.5;
    float vig = mix(1.0, max(0.0, 1.0 - pow(length(vuv - 0.5) * 1.414 * 0.6, 3.0)), VIGNETTE_STRENGTH);
    hex *= vig;

    // Composite with terminal
    float termLuma = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float vis = PATTERN_OPACITY * (1.0 - termLuma * 0.85);
    vec3 result = mix(terminal.rgb, hex, vis);

    fragColor = vec4(result, 1.0);
}

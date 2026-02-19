// JAM - typing-speed-reactive electricity shader v2
// CRANKED: thicker bolts, more branches, screen shake, particle sparks, faster response

const float HEAT_RAMP_FAST = 0.03;    // faster response to rapid typing
const float HEAT_RAMP_SLOW = 0.4;     // quicker decay awareness
const float ARC_DURATION = 1.4;       // arcs linger less, snappier
const float MAX_ARC_THICKNESS = 0.014; // THICC bolts
const float MIN_ARC_THICKNESS = 0.003;
const float GLOW_MULTIPLIER = 5.0;    // bigger glow halos
const float BRANCH_THRESHOLD = 0.15;  // branches appear sooner
const float EDGE_SPARK_THRESHOLD = 0.4;
const float SCREEN_FLASH_THRESHOLD = 0.7;
const float SHAKE_THRESHOLD = 0.6;
const float TAIL_EXTENSION = 1.5;
const float SPARK_COUNT = 12.0;

const vec3 COL_PINK   = vec3(0.906, 0.204, 0.612);
const vec3 COL_CYAN   = vec3(0.102, 0.816, 0.839);
const vec3 COL_PURPLE = vec3(0.596, 0.443, 0.996);
const vec3 COL_GOLD   = vec3(0.949, 0.651, 0.200);
const vec3 COL_BLUE   = vec3(0.271, 0.541, 0.886);
const vec3 COL_WHITE  = vec3(0.973, 0.965, 0.949);

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

float fbm4(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 6; i++) {
        v += a * vnoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec2 px2norm(vec2 value, float isPos) {
    return (value * 2.0 - (iResolution.xy * isPos)) / iResolution.y;
}

vec2 getCursorCenter(vec4 rect) {
    return vec2(rect.x + rect.z * 0.5, rect.y - rect.w * 0.5);
}

float blend01(float t) {
    float s = t * t;
    return s / (2.0 * (s - t) + 1.0);
}

float electricArc(vec2 p, vec2 a, vec2 b, float tm, float intensity) {
    vec2 ab = b - a;
    float len = length(ab);
    if (len < 0.001) return 999.0;
    vec2 dir = ab / len;
    vec2 perp = vec2(-dir.y, dir.x);
    float t = clamp(dot(p - a, dir) / len, 0.0, 1.0);
    vec2 proj = a + dir * t * len;
    float envelope = sin(t * 3.14159);
    // More jagged: higher frequency noise, more displacement
    float disp = (fbm4(vec2(t * 15.0, tm * 10.0)) - 0.5) * 0.18 * intensity * envelope;
    // Add secondary high-freq jitter for realism
    disp += (vnoise(vec2(t * 40.0, tm * 25.0)) - 0.5) * 0.04 * intensity * envelope;
    return length(p - (proj + perp * disp));
}

float branchBolt(vec2 p, vec2 a, vec2 b, float tm, float seed) {
    vec2 ab = b - a;
    float len = length(ab);
    if (len < 0.001) return 999.0;
    vec2 dir = ab / len;
    vec2 perp = vec2(-dir.y, dir.x);
    float t = clamp(dot(p - a, dir) / len, 0.0, 1.0);
    vec2 proj = a + dir * t * len;
    float disp = (fbm4(vec2(t * 20.0 + seed * 7.0, tm * 14.0 + seed * 3.0)) - 0.5)
                 * 0.10 * sin(t * 3.14159);
    disp += (vnoise(vec2(t * 50.0 + seed * 13.0, tm * 30.0)) - 0.5) * 0.03 * sin(t * 3.14159);
    return length(p - (proj + perp * disp));
}

float edgeSpark(vec2 p, float tm, float seed) {
    float edgePos = fract(seed * 7.13 + tm * 0.4);
    float side = floor(fract(seed * 3.71) * 4.0);
    float sparkLen = 0.06 + 0.12 * fract(seed * 11.3);
    float aspect = iResolution.x / iResolution.y;
    vec2 sA;
    vec2 sB;
    if (side < 1.0) {
        sA = vec2(edgePos * 2.0 - 1.0, aspect);
        sB = sA - vec2(0.0, sparkLen);
    } else if (side < 2.0) {
        sA = vec2(edgePos * 2.0 - 1.0, -aspect);
        sB = sA + vec2(0.0, sparkLen);
    } else if (side < 3.0) {
        sA = vec2(-aspect, edgePos * 2.0 - 1.0);
        sB = sA + vec2(sparkLen, 0.0);
    } else {
        sA = vec2(aspect, edgePos * 2.0 - 1.0);
        sB = sA - vec2(sparkLen, 0.0);
    }
    return branchBolt(p, sA, sB, tm * 18.0, seed);
}

// Particle spark: small bright dot flying away from cursor
float particleSpark(vec2 p, vec2 origin, float tm, float seed) {
    float life = fract(seed * 3.17 + tm * 0.8);
    float age = life;
    // Random direction
    float angle = seed * 6.2831 + seed * seed * 4.0;
    float speed = 0.15 + 0.25 * fract(seed * 5.31);
    vec2 vel = vec2(cos(angle), sin(angle)) * speed;
    // Gravity-ish: slight downward pull
    vel.y -= age * 0.1;
    vec2 pos = origin + vel * age;
    float d = length(p - pos);
    float brightness = (1.0 - age) * (1.0 - age); // fade out
    float size = 0.003 * (1.0 - age * 0.7);
    return brightness * smoothstep(size, size * 0.2, d);
}

vec3 getArcColor(float tm) {
    float phase = fract(tm * 0.5);
    if (phase < 0.2)      return mix(COL_CYAN, COL_BLUE, phase * 5.0);
    else if (phase < 0.4) return mix(COL_BLUE, COL_PURPLE, (phase - 0.2) * 5.0);
    else if (phase < 0.6) return mix(COL_PURPLE, COL_PINK, (phase - 0.4) * 5.0);
    else if (phase < 0.8) return mix(COL_PINK, COL_GOLD, (phase - 0.6) * 5.0);
    else                  return mix(COL_GOLD, COL_CYAN, (phase - 0.8) * 5.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // --- Compute heat early for screen shake ---
    float timeSinceType = iTime - iTimeCursorChange;
    float heat = smoothstep(HEAT_RAMP_SLOW, HEAT_RAMP_FAST, timeSinceType);

    // --- Screen shake at high heat ---
    if (heat > SHAKE_THRESHOLD) {
        float shakeAmt = smoothstep(SHAKE_THRESHOLD, 1.0, heat) * 0.004;
        uv.x += sin(iTime * 90.0) * shakeAmt * (vnoise(vec2(iTime * 50.0, 0.0)) - 0.5) * 2.0;
        uv.y += cos(iTime * 110.0) * shakeAmt * (vnoise(vec2(0.0, iTime * 60.0)) - 0.5) * 2.0;
        uv = clamp(uv, 0.0, 1.0);
    }

    fragColor = texture(iChannel0, uv);
    vec2 vu = px2norm(fragCoord, 1.0);

    vec4 cc = vec4(px2norm(iCurrentCursor.xy, 1.0), px2norm(iCurrentCursor.zw, 0.0));
    vec4 cp = vec4(px2norm(iPreviousCursor.xy, 1.0), px2norm(iPreviousCursor.zw, 0.0));
    vec2 curPos = getCursorCenter(cc);
    vec2 prevPos = getCursorCenter(cp);
    vec2 tailEnd = prevPos + (prevPos - curPos) * TAIL_EXTENSION;

    float progress = blend01(clamp(timeSinceType / ARC_DURATION, 0.0, 1.0));
    float fade = pow(1.0 - progress, 3.0);
    float tailLen = length(tailEnd - curPos);

    float thickness = mix(MIN_ARC_THICKNESS, MAX_ARC_THICKNESS, heat);
    // Aggressive pulsation
    thickness *= 1.0 + 0.5 * sin(iTime * 40.0) * heat;

    vec3 arcColor = getArcColor(iTime);
    vec3 glowColor = mix(arcColor, COL_WHITE, 0.4);
    vec3 coreColor = mix(arcColor, COL_WHITE, 0.8); // bright white-hot core

    // --- Main arc ---
    float mainDist = electricArc(vu, curPos, tailEnd, iTime, 0.5 + heat * 0.5);
    float mainAlpha = (1.0 - smoothstep(thickness * 0.2, thickness, mainDist)) * fade;
    float mainCore = (1.0 - smoothstep(0.0, thickness * 0.3, mainDist)) * fade;
    float mainGlow = (1.0 - smoothstep(thickness, thickness * GLOW_MULTIPLIER, mainDist)) * fade;

    // White-hot core + colored body + soft glow
    fragColor.rgb = mix(fragColor.rgb, arcColor, mainAlpha * 0.9);
    fragColor.rgb = mix(fragColor.rgb, coreColor, mainCore * 0.8);
    fragColor.rgb += glowColor * mainGlow * 0.2 * heat;

    // --- Second arc (offset, creates a "double bolt" look) ---
    if (heat > 0.2 && tailLen > 0.001) {
        float arc2Dist = electricArc(vu, curPos, tailEnd, iTime + 100.0, 0.4 + heat * 0.4);
        float arc2Thick = thickness * 0.6;
        float arc2Alpha = (1.0 - smoothstep(arc2Thick * 0.2, arc2Thick, arc2Dist)) * fade * 0.5;
        fragColor.rgb = mix(fragColor.rgb, glowColor, arc2Alpha);
    }

    // --- Branch arcs ---
    if (heat > BRANCH_THRESHOLD && tailLen > 0.001) {
        float bi = smoothstep(BRANCH_THRESHOLD, 0.7, heat);
        int nb = int(2.0 + bi * 6.0); // up to 8 branches
        for (int i = 0; i < 8; i++) {
            if (i >= nb) break;
            float sd = float(i) * 1.37;
            float bt = fract(sd * 0.618 + iTime * 0.6);
            vec2 bStart = mix(curPos, tailEnd, bt);
            vec2 mdir = tailEnd - curPos;
            float mlen = length(mdir);
            if (mlen > 0.001) {
                mdir = mdir / mlen;
                vec2 bPerp = vec2(-mdir.y, mdir.x);
                float bSide = (fract(sd * 3.14) > 0.5) ? 1.0 : -1.0;
                float bReach = 0.04 + 0.10 * fract(sd * 2.7) * bi; // longer branches
                vec2 bEnd = bStart + bPerp * bSide * bReach;
                float bDist = branchBolt(vu, bStart, bEnd, iTime, sd);
                float bThick = thickness * 0.45;
                float bAlpha = (1.0 - smoothstep(bThick * 0.2, bThick, bDist)) * fade * bi;
                float bCore = (1.0 - smoothstep(0.0, bThick * 0.3, bDist)) * fade * bi;
                fragColor.rgb = mix(fragColor.rgb, arcColor, bAlpha * 0.7);
                fragColor.rgb = mix(fragColor.rgb, coreColor, bCore * 0.4);
            }
        }
    }

    // --- Particle sparks flying from cursor ---
    if (heat > 0.1) {
        float sparkIntensity = smoothstep(0.1, 0.8, heat);
        int numSparks = int(SPARK_COUNT * sparkIntensity);
        for (int i = 0; i < 12; i++) {
            if (i >= numSparks) break;
            float sd = float(i) * 2.13;
            float spark = particleSpark(vu, curPos, iTime, sd) * sparkIntensity * fade;
            vec3 sparkCol = mix(arcColor, COL_WHITE, 0.7);
            fragColor.rgb += sparkCol * spark * 1.5;
        }
    }

    // --- Edge sparks ---
    if (heat > EDGE_SPARK_THRESHOLD) {
        float si = smoothstep(EDGE_SPARK_THRESHOLD, 1.0, heat);
        for (int i = 0; i < 10; i++) {
            float sd = float(i) * 2.31 + floor(iTime * 5.0);
            float sDist = edgeSpark(vu, iTime, sd);
            float sThick = 0.004 * si;
            float sAlpha = (1.0 - smoothstep(sThick * 0.2, sThick, sDist)) * si * 0.7;
            float sCore = (1.0 - smoothstep(0.0, sThick * 0.3, sDist)) * si * 0.4;
            float sGlow = (1.0 - smoothstep(sThick, sThick * 4.0, sDist)) * si * 0.2;
            vec3 sCol = mix(COL_CYAN, COL_WHITE, 0.5);
            fragColor.rgb = mix(fragColor.rgb, sCol, sAlpha);
            fragColor.rgb = mix(fragColor.rgb, COL_WHITE, sCore);
            fragColor.rgb += sCol * sGlow;
        }
    }

    // --- Screen flash + vignette pulse ---
    if (heat > SCREEN_FLASH_THRESHOLD) {
        float fi = smoothstep(SCREEN_FLASH_THRESHOLD, 1.0, heat);
        // Flash
        float flash = fi * 0.06 * (0.5 + 0.5 * sin(iTime * 25.0));
        fragColor.rgb += arcColor * flash;
        // Vignette brightening at edges (electric corona)
        float vignette = 1.0 - length(uv - 0.5) * 1.2;
        float corona = (1.0 - vignette) * fi * 0.08;
        fragColor.rgb += arcColor * corona;
    }

    // --- Cursor glow (pulsing, brighter) ---
    float cursorDist = length(vu - curPos);
    float cGlowBase = exp(-cursorDist * cursorDist * 60.0);
    float cGlowPulse = 0.15 + 0.35 * heat + 0.1 * sin(iTime * 15.0) * heat;
    fragColor.rgb += arcColor * cGlowBase * cGlowPulse;
    // Hot white center
    float cCore = exp(-cursorDist * cursorDist * 300.0) * heat * 0.4;
    fragColor.rgb += COL_WHITE * cCore;

    fragColor.a = 1.0;
}

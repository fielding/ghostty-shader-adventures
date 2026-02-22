// JAM - Three-mode shader
//
// NORMAL:     printf '\e]12;#F8F6F2\a'  (subtle — everyday coding)
// HEATING UP: printf '\e]12;#FF4400\a'  (full electric)
// ON FIRE:    printf '\e]12;#0066FF\a'  (blue flames + max electric)

const float HEAT_RAMP_FAST = 0.05;
const float HEAT_RAMP_SLOW = 3.0;
const float ARC_DURATION = 2.5;
const float TAIL_EXTENSION = 1.5;

const vec3 COL_PINK   = vec3(0.906, 0.204, 0.612);
const vec3 COL_CYAN   = vec3(0.102, 0.816, 0.839);
const vec3 COL_PURPLE = vec3(0.596, 0.443, 0.996);
const vec3 COL_GOLD   = vec3(0.949, 0.651, 0.200);
const vec3 COL_BLUE   = vec3(0.271, 0.541, 0.886);
const vec3 COL_WHITE  = vec3(0.973, 0.965, 0.949);

const vec3 COL_BFLAME_DEEP   = vec3(0.02, 0.05, 0.4);
const vec3 COL_BFLAME_MID    = vec3(0.05, 0.25, 0.85);
const vec3 COL_BFLAME_BRIGHT = vec3(0.2, 0.5, 1.0);
const vec3 COL_BFLAME_HOT    = vec3(0.55, 0.8, 1.0);
const vec3 COL_BFLAME_CORE   = vec3(0.85, 0.93, 1.0);

const vec3 DEFAULT_CURSOR = vec3(0.973, 0.965, 0.949);

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

float fbm3(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// --- Helpers ---
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

// --- Electric ---
float electricArc(vec2 p, vec2 a, vec2 b, float tm, float intensity) {
    vec2 ab = b - a;
    float len = length(ab);
    if (len < 0.001) return 999.0;
    vec2 dir = ab / len;
    vec2 perp = vec2(-dir.y, dir.x);
    float t = clamp(dot(p - a, dir) / len, 0.0, 1.0);
    vec2 proj = a + dir * t * len;
    float env = sin(t * 3.14159);
    float disp = (fbm3(vec2(t * 15.0, tm * 10.0)) - 0.5) * 0.18 * intensity * env;
    disp += (vnoise(vec2(t * 40.0, tm * 25.0)) - 0.5) * 0.04 * intensity * env;
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
    float disp = (fbm3(vec2(t * 20.0 + seed * 7.0, tm * 14.0 + seed * 3.0)) - 0.5)
                 * 0.10 * sin(t * 3.14159);
    return length(p - (proj + perp * disp));
}

float particleSpark(vec2 p, vec2 origin, float tm, float seed) {
    float life = fract(seed * 3.17 + tm * 0.8);
    float angle = seed * 6.2831 + seed * seed * 4.0;
    float speed = 0.15 + 0.25 * fract(seed * 5.31);
    vec2 vel = vec2(cos(angle), sin(angle)) * speed;
    vel.y -= life * 0.1;
    vec2 pos = origin + vel * life;
    float d = length(p - pos);
    float brightness = (1.0 - life) * (1.0 - life);
    float size = 0.003 * (1.0 - life * 0.7);
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

// --- Fire ---
float fireShape(vec2 p, vec2 origin, float tm, float height, float width) {
    vec2 rel = p - origin;
    float upY = -rel.y;
    float yNorm = clamp(upY / height, 0.0, 1.0);
    float envelope = (1.0 - yNorm) * width * (1.0 - yNorm * yNorm * 0.5);
    float noiseVal = fbm3(vec2(rel.x * 8.0 / width, yNorm * 4.0 - tm * 3.0) + tm * 0.5);
    float shape = envelope * noiseVal;
    float flame = smoothstep(shape, shape * 0.3, abs(rel.x));
    flame *= smoothstep(-0.005, 0.01, upY);
    flame *= 1.0 - yNorm * yNorm;
    return flame;
}

vec3 blueFireColor(float intensity, float yNorm) {
    float t = yNorm * (1.0 - intensity * 0.3);
    if (t < 0.12) return mix(COL_BFLAME_CORE, COL_BFLAME_HOT, t / 0.12);
    else if (t < 0.3) return mix(COL_BFLAME_HOT, COL_BFLAME_BRIGHT, (t - 0.12) / 0.18);
    else if (t < 0.6) return mix(COL_BFLAME_BRIGHT, COL_BFLAME_MID, (t - 0.3) / 0.3);
    else return mix(COL_BFLAME_MID, COL_BFLAME_DEEP, (t - 0.6) / 0.4);
}

float fireEmber(vec2 p, vec2 origin, float tm, float seed) {
    float life = fract(seed * 3.17 + tm * 0.35);
    float angle = seed * 6.2831 + sin(tm * 2.0 + seed * 5.0) * 0.5;
    float speed = 0.04 + 0.06 * fract(seed * 5.31);
    vec2 vel = vec2(cos(angle) * speed * 0.3, -speed);
    vel.x += sin(tm * 3.0 + seed * 7.0) * 0.02;
    vec2 pos = origin + vel * life;
    float d = length(p - pos);
    float brightness = (1.0 - life) * (1.0 - life);
    float flicker = 0.7 + 0.3 * sin(tm * 20.0 + seed * 13.0);
    float size = 0.003 * (1.0 - life * 0.5);
    return brightness * flicker * smoothstep(size, size * 0.1, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float timeSinceType = iTime - iTimeCursorChange;
    float heat = smoothstep(HEAT_RAMP_SLOW, HEAT_RAMP_FAST, timeSinceType);

    // === MODE DETECTION ===
    float colorDist = length(iCurrentCursorColor.rgb - DEFAULT_CURSOR);
    float isNotDefault = smoothstep(0.4, 0.8, colorDist);
    float warmth = iCurrentCursorColor.r - iCurrentCursorColor.b;
    float heatingUp = isNotDefault * smoothstep(0.0, 0.3, warmth);
    float onFire = isNotDefault * smoothstep(0.0, 0.3, -warmth);
    // 0 = normal/subtle, 0.5 = heating up, 1.0 = on fire
    float intensity = clamp(heatingUp * 0.5 + onFire, 0.0, 1.0);

    // === SCREEN SHAKE (heating + fire) ===
    if (intensity > 0.3 && heat > 0.3) {
        float shakeAmt = heat * intensity * 0.005;
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

    // === ARC PARAMS BY MODE ===
    // Normal: subtle thin arcs | Heating: full v2 | Fire: max + blue
    float thickMax = mix(0.005, 0.016, intensity);  // thin normal, fat fire
    float thickness = mix(0.002, thickMax, heat);
    thickness *= 1.0 + 0.4 * sin(iTime * 40.0) * heat * max(0.3, intensity);

    vec3 arcColor = mix(getArcColor(iTime), COL_BFLAME_BRIGHT, onFire * 0.7);
    vec3 glowColor = mix(arcColor, COL_WHITE, 0.4);
    vec3 coreColor = mix(arcColor, COL_WHITE, 0.8);

    // Opacity scales by mode: subtle in normal, full in heated
    float arcOpacity = 0.35 + 0.65 * intensity;

    // =========================================
    // ELECTRIC ARCS
    // =========================================

    // Main arc (always, but subtle in normal)
    float mainDist = electricArc(vu, curPos, tailEnd, iTime, 0.5 + heat * 0.5);
    float mainAlpha = (1.0 - smoothstep(thickness * 0.2, thickness, mainDist)) * fade;
    float mainCore = (1.0 - smoothstep(0.0, thickness * 0.3, mainDist)) * fade;
    float mainGlow = (1.0 - smoothstep(thickness, thickness * 5.0, mainDist)) * fade;

    fragColor.rgb = mix(fragColor.rgb, arcColor, mainAlpha * arcOpacity);
    fragColor.rgb = mix(fragColor.rgb, coreColor, mainCore * arcOpacity * 0.8);
    fragColor.rgb += glowColor * mainGlow * 0.08 * heat * arcOpacity;

    // Double bolt (heating + fire)
    if (intensity > 0.3 && heat > 0.2 && tailLen > 0.001) {
        float arc2Dist = electricArc(vu, curPos, tailEnd, iTime + 100.0, 0.4 + heat * 0.4);
        float arc2Thick = thickness * 0.6;
        float arc2Alpha = (1.0 - smoothstep(arc2Thick * 0.2, arc2Thick, arc2Dist)) * fade * 0.5;
        fragColor.rgb = mix(fragColor.rgb, glowColor, arc2Alpha);
    }

    // Branches: 0 normal, 4 heating, 8 fire
    int maxBranch = int(intensity * 8.0);
    if (maxBranch > 0 && heat > 0.15 && tailLen > 0.001) {
        float bi = smoothstep(0.15, 0.7, heat);
        int nb = int(1.0 + bi * float(maxBranch));
        for (int i = 0; i < 8; i++) {
            if (i >= nb) break;
            float sd = float(i) * 1.37;
            float bt = fract(sd * 0.618 + iTime * 0.6);
            vec2 bStart = mix(curPos, tailEnd, bt);
            vec2 mdir = tailEnd - curPos;
            float mlen = length(mdir);
            if (mlen > 0.001) {
                mdir /= mlen;
                vec2 bPerp = vec2(-mdir.y, mdir.x);
                float bSide = (fract(sd * 3.14) > 0.5) ? 1.0 : -1.0;
                float bReach = 0.04 + 0.10 * fract(sd * 2.7) * bi;
                vec2 bEnd = bStart + bPerp * bSide * bReach;
                float bDist = branchBolt(vu, bStart, bEnd, iTime, sd);
                float bThick = thickness * 0.45;
                float bAlpha = (1.0 - smoothstep(bThick * 0.2, bThick, bDist)) * fade * bi;
                fragColor.rgb = mix(fragColor.rgb, arcColor, bAlpha * 0.7);
            }
        }
    }

    // Particle sparks: 2 normal, 6 heating, 10 fire
    {
        int ns = int(2.0 + 8.0 * intensity);
        float si = smoothstep(0.1, 0.6, heat);
        for (int i = 0; i < 10; i++) {
            if (i >= ns) break;
            float sd = float(i) * 2.13;
            float spark = particleSpark(vu, curPos, iTime, sd) * si * fade;
            vec3 sparkCol = mix(mix(arcColor, COL_WHITE, 0.7), COL_BFLAME_HOT, onFire);
            fragColor.rgb += sparkCol * spark * (0.5 + intensity);
        }
    }

    // Edge sparks (heating + fire only)
    if (intensity > 0.3 && heat > 0.4) {
        float si = smoothstep(0.4, 1.0, heat) * intensity;
        int ne = int(3.0 + 3.0 * intensity);
        for (int i = 0; i < 6; i++) {
            if (i >= ne) break;
            float sd = float(i) * 2.31 + floor(iTime * 5.0);
            float aspect = iResolution.x / iResolution.y;
            float edgePos = fract(sd * 7.13 + iTime * 0.4);
            vec2 sA = vec2(edgePos * 2.0 - 1.0, aspect);
            vec2 sB = sA - vec2(0.0, 0.06 + 0.1 * fract(sd * 11.3));
            float sDist = branchBolt(vu, sA, sB, iTime * 18.0, sd);
            float sThick = 0.004 * si;
            float sAlpha = (1.0 - smoothstep(sThick * 0.2, sThick, sDist)) * si * 0.5;
            vec3 sCol = mix(mix(COL_CYAN, COL_WHITE, 0.5), COL_BFLAME_BRIGHT, onFire);
            fragColor.rgb = mix(fragColor.rgb, sCol, sAlpha);
        }
    }

    // Screen flash + corona (heating + fire)
    if (intensity > 0.3 && heat > 0.6) {
        float fi = smoothstep(0.6, 1.0, heat) * intensity;
        fragColor.rgb += arcColor * fi * 0.04 * (0.5 + 0.5 * sin(iTime * 25.0));
        float vig = 1.0 - length(uv - 0.5) * 1.2;
        fragColor.rgb += arcColor * (1.0 - vig) * fi * 0.05;
    }

    // === CURSOR GLOW (always on, scales with mode) ===
    float cursorDist = length(vu - curPos);
    float flicker = 0.85 + 0.15 * sin(iTime * 8.0 + vnoise(vec2(iTime * 5.0, 0.0)) * 6.28);
    // Normal: subtle warm glow | Heated: strong glow
    float baseGlow = mix(0.06, 0.2, intensity);
    float heatGlow = mix(0.1, 0.3, intensity) * heat;
    float cGlow = exp(-cursorDist * cursorDist * 60.0) * (baseGlow + heatGlow) * flicker;
    fragColor.rgb += arcColor * cGlow;
    // Hot white center
    fragColor.rgb += COL_WHITE * exp(-cursorDist * cursorDist * 300.0) * (0.03 + heat * 0.3);

    // === AMBIENT IDLE SPARKS (always, subtle) ===
    {
        float idleStr = max(0.2, heat) * (0.3 + 0.7 * max(0.3, intensity));
        for (int i = 0; i < 3; i++) {
            float sd = float(i + 50) * 2.71;
            float life = fract(sd * 3.17 + iTime * 0.25);
            float angle = sd * 6.2831 + sin(iTime * 1.5 + sd * 3.0) * 1.0;
            float speed = 0.025 + 0.035 * fract(sd * 5.31);
            vec2 pos = curPos + vec2(cos(angle), sin(angle)) * speed * life;
            float d = length(vu - pos);
            float brightness = (1.0 - life) * (1.0 - life) * idleStr;
            float sf = 0.6 + 0.4 * sin(iTime * 15.0 + sd * 9.0);
            float spark = brightness * sf * smoothstep(0.002, 0.0002, d);
            fragColor.rgb += arcColor * spark * 0.6;
        }
    }

    // =========================================
    // ON FIRE: BLUE FLAMES
    // =========================================
    if (onFire > 0.01) {
        float fh = heat * onFire;

        // Cursor flame
        float flame = fireShape(vu, curPos, iTime, 0.10 + 0.14 * fh, 0.025 + 0.03 * fh);
        float yRel = clamp((curPos.y - vu.y) / (0.10 + 0.14 * fh), 0.0, 1.0);
        fragColor.rgb = mix(fragColor.rgb, blueFireColor(fh, yRel), flame * 0.85 * onFire);

        // Core flame
        float core = fireShape(vu, curPos, iTime * 1.3 + 10.0, 0.05 + 0.07 * fh, 0.01 + 0.012 * fh);
        fragColor.rgb = mix(fragColor.rgb, COL_BFLAME_CORE, core * 0.5 * onFire);

        // Flames from bottom edge
        float bottomY = 1.0 - uv.y;
        float edgeFlame = fbm3(vec2(uv.x * 6.0, bottomY * 3.0 - iTime * 2.0) + iTime * 0.3);
        edgeFlame *= smoothstep(0.3, 0.0, bottomY) * onFire;
        fragColor.rgb = mix(fragColor.rgb, blueFireColor(fh, 1.0 - bottomY * 3.0), edgeFlame * 0.4);

        // Blue embers
        for (int i = 0; i < 6; i++) {
            float sd = float(i + 30) * 1.71;
            float e = fireEmber(vu, curPos, iTime, sd) * onFire;
            fragColor.rgb += mix(COL_BFLAME_BRIGHT, COL_BFLAME_HOT, fract(sd * 2.3)) * e * 1.2;
        }

        // Blue halo + corona
        fragColor.rgb += COL_BFLAME_MID * exp(-cursorDist * cursorDist * 20.0) * onFire * 0.2;
        float vig = 1.0 - length(uv - 0.5) * 1.2;
        fragColor.rgb += COL_BFLAME_MID * (1.0 - vig) * onFire * 0.1;
    }

    fragColor.a = 1.0;
}

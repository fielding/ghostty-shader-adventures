# Ghostty shader reference

Ghostty custom shaders are fragment shaders implementing `void mainImage(out vec4 fragColor, in vec2 fragCoord)`. The terminal screen is available as `texture(iChannel0, uv)`.

## Available uniforms

| Uniform | Type | Description |
|---------|------|-------------|
| `iChannel0` | sampler2D | Terminal screen texture (or previous shader's output when stacking) |
| `iResolution` | vec3 | Screen resolution in pixels |
| `iTime` | float | Seconds since shader started |
| `iTimeDelta` | float | Time since last frame |
| `iFrame` | int | Frame count |
| `iCurrentCursor` | vec4 | Current cursor rect (x, y, width, height in pixels) |
| `iPreviousCursor` | vec4 | Previous cursor position |
| `iCurrentCursorColor` | vec4 | Cursor color (can be used as a control signal) |
| `iTimeCursorChange` | float | Timestamp of last cursor change |

## Coordinate system

- `fragCoord` is in pixel coordinates
- Ghostty's y-axis points **down** on screen (positive y = lower on screen). This is important when positioning effects relative to the cursor — use `flameXY.y = -flameXY.y` if you want +y to mean "up on screen"
- `iCurrentCursor.y` is the top edge of the cursor glyph, `.w` extends downward
- Cursor center: `vec2(iCurrentCursor.x + iCurrentCursor.z * 0.5, iCurrentCursor.y - iCurrentCursor.w * 0.5)`

## Stacking shaders

Ghostty supports multiple `custom-shader` lines. Each shader's output becomes the next shader's `iChannel0` input, creating a processing pipeline:

```
custom-shader = /path/to/splatter.glsl
custom-shader = /path/to/cursor-glitch.glsl
```

This works on both macOS (Metal) and Linux (OpenGL, [fixed in #5037](https://github.com/ghostty-org/ghostty/issues/4729)).

## Porting from Shadertoy

- Shadertoy's `iChannel0` is usually a texture/buffer input; in Ghostty it's always the terminal screen
- Multi-pass Shadertoy shaders (Buffer A/B/C/D) can potentially be ported using Ghostty's shader stacking, with each pass as a separate `.glsl` file
- Replace `textureLod`/`textureLodOffset` with `texture` for compatibility
- Standalone Shadertoy scenes need compositing with terminal content (blend, overlay, or background placement)
- No external texture inputs — replace texture-based noise with procedural noise functions

See the [Ghostty docs](https://ghostty.org/docs/config/reference#custom-shader) for the full config reference.

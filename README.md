# ghostty-shader-adventures

Custom fragment shaders for [Ghostty](https://ghostty.org) terminal. These are post-processing shaders that run on every frame, transforming the terminal output on the GPU.

## Shaders

### splatter.glsl

Fractal paint splatters using the [magic box fractal](https://www.shadertoy.com/view/sdjGRc) technique. Colorful, organic paint stains drift and morph behind terminal text.

**Interactive features:**
- Cursor acts as a paintbrush — a splatter follows it, blooming larger when typing and fading when idle
- Previous cursor position leaves a fading trail splatter
- Ambient background splatters glow when the cursor passes near them
- Soft colored halo around the cursor pulses with typing activity
- Colors cycle smoothly through the palette

**Note:** Cursor interactivity depends on the terminal client updating cursor uniforms. Works in standard shell sessions and some TUI apps (e.g. Codex), but not all (e.g. Claude Code uses alternate screen handling).

### splatter-original.glsl

The non-interactive version of the paint splatter shader. Static ambient splatters with slow fractal drift animation. Good baseline if you want the aesthetic without cursor reactivity.

### clouds.glsl

Soft animated clouds drifting behind terminal text. Three cloud layers at different depths create a parallax effect. Colors from the Human++ palette — purple/blue deep clouds, cyan mid layer, pink/gold highlights.

**Interactive features:**
- Clouds brighten when cursor passes near them
- Subtle warm glow at cursor position when typing
- Typing activity slightly stirs the clouds

Probably the most subtle/daily-driver-friendly shader in the collection.

### flame.glsl

**Work in progress.** Cursor-localized 3D raymarched fire inspired by [iq's flame shader](https://www.shadertoy.com/view/MdX3zr). A volumetric flame rises from the cursor, stoked by typing activity.

Features: 3D FBM noise volume, cursor-following, typing heat reactivity, flame lean on cursor movement. Still needs work on the density/shape — currently looks more like a candy corn than fire. The coordinate system (Ghostty's y-axis points down) has been a source of bugs. Needs more iteration on the noise carving to get proper ragged fire edges.

### jam.glsl

Three-mode electric arc system with particle effects, controlled via cursor color. Designed for a workflow where external scripts set the cursor color to shift intensity:

| Mode | Trigger | Effect |
|------|---------|--------|
| Normal | Default cursor color | Subtle thin arcs, gentle cursor glow, ambient sparks |
| Heating Up | `printf '\e]12;#FF4400\a'` | Full electric — thick bolts, branches, screen shake, sparks |
| On Fire | `printf '\e]12;#0066FF\a'` | Blue flames from cursor and screen edges, embers, max electric |

Features: electric arcs with FBM noise paths, branching bolts, particle sparks, cursor glow, screen shake, edge lightning, blue fire with volumetric flame shapes.

### jam_electric_v2.glsl

Earlier iteration of the electric arc shader. Single-mode (no cursor color control), always reactive to typing speed. Snappier response, thicker bolts, more aggressive screen shake. A good pick if you want the electric effect without the multi-mode complexity.

### fxaa.glsl

**Experimental, not committed.** NVIDIA FXAA 3.11 by Timothy Lottes, stripped from ~900 lines to ~130. Applies fast approximate anti-aliasing to the terminal output. Uses green channel as luma proxy. May cause strange rendering behavior in some contexts — kept as a local experiment. Could be useful as a final pass when stacking multiple shaders.

## Usage

In your Ghostty config (`~/.config/ghostty/config` or `~/Library/Application Support/com.mitchellh.ghostty/config`):

```
custom-shader = /path/to/ghostty-shader-adventures/clouds.glsl
custom-shader-animation = true
```

### Stacking shaders

Ghostty supports multiple `custom-shader` lines. Each shader's output becomes the next shader's `iChannel0` input, creating a processing pipeline:

```
custom-shader = /path/to/splatter.glsl
custom-shader = /path/to/fxaa.glsl
```

This works on both macOS (Metal) and Linux (OpenGL, [fixed in #5037](https://github.com/ghostty-org/ghostty/issues/4729)). This opens the door to modular shader composition — base effects + post-processing passes.

## Palette

The shaders use colors from the [Human++](https://github.com/fielding/human-plus-plus) theme:

- **Pink** `#E7348C` — `vec3(0.906, 0.204, 0.612)`
- **Cyan** `#1AD0D6` — `vec3(0.102, 0.816, 0.839)`
- **Purple** `#9871FE` — `vec3(0.596, 0.443, 0.996)`
- **Gold** `#F2A633` — `vec3(0.949, 0.651, 0.200)`
- **Blue** `#458AE2` — `vec3(0.271, 0.541, 0.886)`

Swap these out in the `paletteColor()` function to match your own theme.

## Ghostty shader reference

Ghostty custom shaders are fragment shaders implementing `void mainImage(out vec4 fragColor, in vec2 fragCoord)`. The terminal screen is available as `texture(iChannel0, uv)`.

### Available uniforms

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

### Coordinate system notes

- `fragCoord` is in pixel coordinates
- Ghostty's y-axis points **down** on screen (positive y = lower on screen). This is important when positioning effects relative to the cursor — use `flameXY.y = -flameXY.y` if you want +y to mean "up on screen"
- `iCurrentCursor.y` is the top edge of the cursor glyph, `.w` extends downward
- Cursor center: `vec2(iCurrentCursor.x + iCurrentCursor.z * 0.5, iCurrentCursor.y - iCurrentCursor.w * 0.5)`

### Porting from Shadertoy

- Shadertoy's `iChannel0` is usually a texture/buffer input; in Ghostty it's always the terminal screen
- Multi-pass Shadertoy shaders (Buffer A/B/C/D) can potentially be ported using Ghostty's shader stacking, with each pass as a separate `.glsl` file
- Replace `textureLod`/`textureLodOffset` with `texture` for compatibility
- Standalone Shadertoy scenes need compositing with terminal content (blend, overlay, or background placement)
- No external texture inputs — replace texture-based noise with procedural noise functions

See the [Ghostty docs](https://ghostty.org/docs/config/reference#custom-shader) for the full config reference.

## Current state

- **Active daily driver:** `clouds.glsl` (pointed to from Ghostty config)
- **Polished:** `splatter.glsl`, `clouds.glsl`, `jam.glsl`
- **WIP:** `flame.glsl` (needs shape/direction fixes)
- **Experimental:** `fxaa.glsl` (local only, not committed)
- **Todo:** Star Nest (cosmic nebula), sci-fi HUD overlay, bloom post-processing pass

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

## Usage

In your Ghostty config (`~/.config/ghostty/config` or `~/Library/Application Support/com.mitchellh.ghostty/config`):

```
custom-shader = /path/to/ghostty-shader-adventures/splatter.glsl
custom-shader-animation = true
```

## Palette

The shaders use colors from the [Human++](https://github.com/fielding/human-plus-plus) theme:

- **Pink** `#E7348C` — `vec3(0.906, 0.204, 0.612)`
- **Cyan** `#1AD0D6` — `vec3(0.102, 0.816, 0.839)`
- **Purple** `#9871FE` — `vec3(0.596, 0.443, 0.996)`
- **Gold** `#F2A633` — `vec3(0.949, 0.651, 0.200)`
- **Blue** `#458AE2` — `vec3(0.271, 0.541, 0.886)`

Swap these out in the `paletteColor()` function to match your own theme.

## Ghostty shader basics

Ghostty custom shaders are single-pass fragment shaders. Each frame, `mainImage` runs per-pixel and can read the terminal output via `texture(iChannel0, uv)`. Available uniforms include screen resolution, time, cursor position/color, and frame count. See the [Ghostty docs](https://ghostty.org/docs/config/reference#custom-shader) for the full list.

Shaders adapted from Shadertoy need compositing with the terminal texture (Shadertoy shaders typically render standalone scenes) and can't use multi-pass buffers or external texture inputs.

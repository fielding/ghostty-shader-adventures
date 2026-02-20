# ghostty-shader-adventures

Custom fragment shaders for [Ghostty](https://ghostty.org) terminal. Post-processing effects that run on every frame, transforming terminal output on the GPU.

All shaders use colors from the [Human++](https://github.com/fielding/human-plus-plus) palette — swap out the color constants to match your own theme.

## Shaders

<!-- TODO: add gifs/videos for each shader -->

| Shader | Description |
|--------|-------------|
| **[splatter.glsl](splatter.glsl)** | Fractal paint splatters ([magic box fractal](https://www.shadertoy.com/view/sdjGRc)). Cursor acts as a paintbrush — splatters bloom when typing, trail when moving, ambient splatters glow on proximity. |
| **[clouds.glsl](clouds.glsl)** | Three-layer parallax clouds with FBM noise. Subtle, daily-driver-friendly. Clouds brighten near cursor, typing stirs them gently. |
| **[hexglitch.glsl](hexglitch.glsl)** | Hexagonal Moiré interference with CRT glitch effects (ported from [Shadertoy lfscD7](https://www.shadertoy.com/view/lfscD7)). Morphing ripple patterns, scanline jitter, JPEG damage, inversion ring around cursor. |
| **[jam.glsl](jam.glsl)** | Three-mode electric arc system. Cursor color controls intensity — normal, heating up (`#FF4400`), on fire (`#0066FF`). Bolts, branches, sparks, screen shake, blue flames. |
| **[jam_electric_v2.glsl](jam_electric_v2.glsl)** | Single-mode electric arcs, always reactive to typing speed. Snappier, thicker bolts, more aggressive shake. |
| **[cursor-glitch.glsl](cursor-glitch.glsl)** | **Stackable.** Cursor-localized digital interference — scanline tears, block displacement, RGB split, digital static. Stack on any base shader. Zero cost when idle. |
| **[splatter-original.glsl](splatter-original.glsl)** | Static (non-interactive) version of the paint splatter shader. |

## Usage

In your Ghostty config:

```
custom-shader = /path/to/ghostty-shader-adventures/splatter.glsl
custom-shader-animation = true
```

Shaders can be stacked — each shader's output feeds into the next as `iChannel0`:

```
custom-shader = /path/to/hexglitch.glsl
custom-shader = /path/to/cursor-glitch.glsl
```

Cursor interactivity works in standard shell sessions and some TUI apps but not all (e.g. Claude Code uses alternate screen handling that doesn't update cursor uniforms).

## Reference

See [GHOSTTY_SHADERS.md](GHOSTTY_SHADERS.md) for the full shader authoring reference — available uniforms, coordinate system, stacking details, and Shadertoy porting notes.

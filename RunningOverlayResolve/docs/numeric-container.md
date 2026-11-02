# Numeric Container Controls

Each numeric slot has independent background, border, glow and minimum-size
controls. This increment covers 16 N2 fields plus the supporting Background
Opacity control (17 controls, counting each RGBA picker as one). For the Mac
field mapping and broader design, see the
[numeric container style specification](numeric-container-style-spec.md).
The narrower scope below takes precedence over that specification's proposed
rotation, alignment and blur controls for this increment.

## Controls

Lengths use design points on a 1280-point reference width. Fusion stores these
as width-normalized values: divide the table's length values by 1280. Colors
include alpha; color channels and opacity range from 0 to 1.

| Control | Default | Range | Effect |
|---|---|---|---|
| Background | Off | Off / On | Enables the rounded background fill and its additional padding. |
| Background Color | Black, alpha 1 | RGBA, each 0–1 | Sets fill color; alpha multiplies Background Opacity. |
| Background Opacity | 0.22 | 0–1 | Sets fill opacity independently of border and content. Supporting control, outside the 16 N2 fields. |
| Background Radius | 6 pt | 0–64 pt | Sets the shared rounded frame radius, limited by the frame dimensions. |
| Background Padding X | 10 pt | 0–80 pt | Adds horizontal space outside the existing content frame when Background is on. |
| Background Padding Y | 6 pt | 0–80 pt | Adds vertical space outside the existing content frame when Background is on. |
| Background Fade Out | Off | Off / On | Enables the approximate edge feather on the fill only. |
| Background Fade Amount | 0.22 | 0–1; effective maximum 0.85 | Controls how far the fill fades inward from its edge. |
| Border | Off | Off / On | Draws a rounded outline, including when Background is off. |
| Border Color | White, alpha 1 | RGBA, each 0–1 | Sets outline color and color alpha. |
| Border Opacity | 0.22 | 0–1 | Multiplies border color alpha independently of fill opacity. |
| Border Width | 1 pt | 0.5–12 pt | Sets outline thickness around the frame boundary. |
| Glow | Off | Off / On | Enables glow beneath the assembled visible container and content. |
| Glow Color | White, alpha 1 | RGBA, each 0–1 | Sets glow tint and alpha independently of text shadow. |
| Glow Intensity | 0 | 0–1 | Controls glow strength and spread; zero produces no glow. |
| Minimum Width | 0 pt | 0–720 pt | Expands the frame horizontally without shrinking or moving content. |
| Minimum Height | 0 pt | 0–360 pt | Expands the frame vertically without shrinking or moving content. |

## Layout and effects

The existing 10×6 design-point content inset is retained, including with
Background off. Enabling Background adds its padding outside the current
content; it does not move the value, label, unit or icon. Minimum Width and
Minimum Height expand the frame to the right and downward from the existing
top-left anchor, keeping the content position fixed. They apply
with Background both on and off; background padding is additional.

Draw order is background fill, border, glow beneath the content, content, then
the existing text-shadow pass. Glow is an underlay derived from the assembled
visible fill, border and content. Text shadow retains its separate controls.
The border follows the same rounded frame but is not faded with the fill.

Fade Out approximates a feather with nested rounded bands and smoothstep alpha
transitions from the outer edge toward the solid interior. The effective amount
is capped at 0.85; feather width is half the shorter frame dimension times that
amount. Zero amount uses a single solid fill. This is not a true alpha mask;
corners and antialiasing can differ from the Mac renderer.

## Compatibility and deferred controls

Absent inputs use compatibility defaults: Background, Border and Glow are off,
and minimum sizes are zero. These defaults preserve old projects' appearance
and placement, including the legacy inset. All controls are independent per
numeric slot; changing one slot does not change another slot or the separate
Solid Color border.

This increment intentionally omits:

- **Rotation:** the Mac numeric renderer has no established rotation behavior
  or anchor. Whole-container rotation and direction need a separate design and
  host validation.
- **Value text alignment:** the Mac numeric renderer forces leading alignment;
  Center/End would be a Resolve extension requiring separate layout behavior.
  Existing label/unit attachment alignment remains available.
- **Backdrop blur:** the Mac uses material that samples the underlying video.
  A fill-only Fuse shape cannot reproduce that; blurring a solid fill or glow
  is not equivalent.

## Validation

From the repository root, run the focused Node/Lua renderer suite:

```sh
node --test RunningOverlayResolve/test/numeric-renderer.test.js
```

Resolve host rendering for these container controls is unverified. Inspector
behavior, save/reopen compatibility, preview/Deliver appearance, fade corners,
effect stacking and dimensions at different output sizes still need host checks.

# Solid Color Border

Last updated: 2026-11-01

## Purpose

The **Solid Color** decor element (`DECOR_SOLID_METRIC`) draws a filled
rectangle, rounded rectangle or circle with no activity data. This increment
adds the border controls the Mac app exposes on the same element, so the
container can be styled beyond its fill.

## Inputs

All four controls are hidden unless a slot's metric is **Solid Color**.

| Label | Suffix | Default | Range |
| --- | --- | --- | --- |
| Border | `Border` | `0` (off) | checkbox |
| Border Width | `BorderWidth` | `1 / 1280` frame width | `0.0001` – `0.02` |
| Border Color | `BorderColor` + `R`/`G`/`B`/`A` | white (`1, 1, 1, 1`) | `0` – `1` per component |
| Border Opacity | `BorderOpacity` | `0.22` | `0` – `1` |

Input keys follow the existing slot convention:

| Slot | Border | Width | Color | Opacity |
| --- | --- | --- | --- | --- |
| Primary | `DecorBorder` | `DecorBorderWidth` | `DecorBorderColorR/G/B/A` | `DecorBorderOpacity` |
| Widget 5 | `Widget5DecorBorder` | `Widget5DecorBorderWidth` | `Widget5DecorBorderColorR/G/B/A` | `Widget5DecorBorderOpacity` |
| Widget 16 | `Widget16DecorBorder` | `Widget16DecorBorderWidth` | `Widget16DecorBorderColorR/G/B/A` | `Widget16DecorBorderOpacity` |

`Border Width` is a fraction of frame width, like the other geometry fields in
this Fuse. At the 1280-point reference it matches the Mac's one design point.
The drawn thickness is never less than one output pixel.

## Mac Reference

`Sources/RunningOverlay/Overlay/OverlayElement.swift` stores `borderEnabled`
(default `false`), `borderColor` (white), `borderOpacity` (`0.22`) and
`borderWidth` (one design point) on the overlay style. The Resolve defaults
match those fields.

Fusion shapes are fill-only, so the border is a thin filled band sampled along
the shape path by `rounded_outline`; it is not a stroked path. Its color is
`Border Color` at `Border Opacity`, independently of the fill.

## Shape Behavior

The border follows the selected **Shape**:

- **Rectangle** – square corners (radius `0`).
- **Rounded Rectangle** – radius is `min(Corner Radius, width / 2, height / 2)`.
- **Circle** – the element collapses to the shorter side and the radius is half
  that side, producing a full circular band.

The outline uses the same center and size as the fill, so it traces the fill's
edge and extends outward by half the border width. Nothing else clips it; the
element has no background mask or crop in this Fuse. The outline is drawn as
another entry in the same `parts` list, so it goes through `draw_part` and
honors the shared quality setting.

## Still Pending

- Mac effects on Solid Color (glow, shadow and any other effect layers) are not
  implemented for this element.
- Host rendering in Resolve (panel visibility, preview and Deliver) has not been
  checked for this increment.

## Validation

```sh
cd RunningOverlayResolve && node --test test/numeric-renderer.test.js
```

The focused suite covers the default-off fill, the outline alpha and color, and
the rectangle, rounded rectangle and circle radii.

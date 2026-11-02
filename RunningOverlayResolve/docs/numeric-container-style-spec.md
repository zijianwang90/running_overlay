# Numeric Container and Effects Specification

> **Implementation status (2026-11-02, v26).** Sixteen of the 19 fields are
> implemented for every numeric slot: background (enabled, color, opacity,
> radius, padding X/Y, fade out and amount), border, glow and minimum
> width/height. `rotationDegrees`, `textAlignment` and `backgroundBlurRadius`
> are intentionally not exposed; see [Numeric Container Controls](numeric-container.md)
> for the reasons and the user-facing behavior. The legacy 10×6 inset is
> retained and background padding expands outside it, resolving the open
> question below in favor of compatibility.
>
> N3 heart-rate-zone color following was implemented separately in v27 for the
> Heart Rate and HR Zone metrics; see
> [Heart Rate Zone Coloring](hr-zone-coloring.md). This specification does not
> cover it.

## Scope

Implement the 19 N2 shared numeric container and effects fields identified in the [parity audit](module-parity-audit.md#shared-references). This applies to numeric widgets and their individual slots. N1 text presets and N3 heart-rate-zone color following are separate follow-ups; do not implement them here. Numeric Mac layouts currently force the minimal preset (`Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:22`).

## Mac model and renderer

Paths below are repository-relative. `OverlayElement.swift:768-817` declares the fields; defaults are in `OverlayElement.swift:936-966`. The ranges in the table distinguish project setter clamps from decoding: absent a stated decode clamp, the decoder preserves the stored value. Types `Double` are floating point; colors are `OverlayColor`. Booleans and the alignment enum have no numeric clamp. Setter clamps are in `Sources/RunningOverlay/Project/ProjectDocument.swift:2759-2772`, `:2825-2922`, and the glow setters. Numeric layout is in `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:19-73`, `:2132-2148`; the view is `Sources/RunningOverlay/UI/PreviewCanvasView.swift:1412-1445`, `:1980-2111`.

| Field | Type; Mac default | Mac clamp | Application |
|---|---|---|---|
| `backgroundEnabled` | Bool; true | — | Minimal view conditionally pads and fills (`PreviewCanvasView.swift:1423-1445`). |
| `backgroundColor` | OverlayColor; black | — | Fill color (`PreviewCanvasView.swift:1433-1441`). |
| `backgroundRadius` | Double; 6 | setter 0–64; decode unbounded | Canvas-scaled rounded shape (`OverlayRenderModel.swift:2140-2147`). |
| `backgroundPaddingX` | Double; 10 | setter 0–80; decode unbounded | Canvas-scaled horizontal padding only with background (`OverlayRenderModel.swift:2145`; `PreviewCanvasView.swift:1426`). |
| `backgroundPaddingY` | Double; 6 | setter 0–80; decode unbounded | Canvas-scaled vertical padding only with background (`OverlayRenderModel.swift:2146`; `PreviewCanvasView.swift:1427`). |
| `backgroundFadeOutEnabled` | Bool; false | — | Passed to fill mask (`PreviewCanvasView.swift:1439`). |
| `backgroundFadeOutAmount` | Double; 0.22 | setter/decode 0–1; mask caps at 0.85 | Feather mask (`OverlayFeatheredBackground.swift:34-52`; `OverlayFeatherMaskRenderer.swift:6-15`). |
| `backgroundBlurRadius` | Double; 0 | setter 0–40; decode ≥0 | Canvas-scaled material strength, not a Gaussian fill blur (`OverlayRenderModel.swift:62`; `OverlayFeatheredBackground.swift:26-32`). |
| `borderEnabled` | Bool; false | — | Generic border independent of background (`PreviewCanvasView.swift:294-299`, `:1416`). |
| `borderColor` | OverlayColor; white | — | Generic border stroke (`PreviewCanvasView.swift:298`). |
| `borderOpacity` | Double; 0.22 | setter/decode 0–1 | Multiplies border color opacity (`PreviewCanvasView.swift:298`). |
| `borderWidth` | Double; 1 | setter/decode 0.5–12 | Stroke width, not scaled in that modifier (`PreviewCanvasView.swift:298`). |
| `glowEnabled` | Bool; false | — | Gates two group shadows (`PreviewCanvasView.swift:267-276`, `:1417`). |
| `glowColor` | OverlayColor; white | — | Color for both shadows (`PreviewCanvasView.swift:270-274`). |
| `glowIntensity` | Double; 0 | setter/decode 0–1 | Opacity factors 0.72 and 0.35; radii 18 and 34 times intensity (`PreviewCanvasView.swift:267-276`). |
| `rotationDegrees` | Double; 0 | setter/decode unbounded | Stored but no application to numeric renderer found; no Mac numeric rotation anchor is established. |
| `textAlignment` | `OverlayTextAlignment`; leading | leading / center / trailing | Numeric layout explicitly forces value alignment to leading (`OverlayRenderModel.swift:65-67`), despite stored value. Label and unit have separate alignment fields. |
| `numericMinWidth` | Double; 0 | initializer/setter/decode 0–720 | Canvas- and element-scaled minimum (`OverlayRenderModel.swift:57`; `PreviewCanvasView.swift:1413`, `:1425`). |
| `numericMinHeight` | Double; 0 | initializer/setter/decode 0–360 | Canvas- and element-scaled minimum (`OverlayRenderModel.swift:58`; `PreviewCanvasView.swift:1413`, `:1425`). |

Mac background fill additionally uses the separate, pre-existing `backgroundOpacity` field, default 0.22 (`OverlayElement.swift:718`, `:900`; `PreviewCanvasView.swift:1437`). Expose it as an N2 supporting control for a usable fill, without counting it as an N2 field. `OverlayColor` carries color components; preserve color alpha when converting. `OverlayStyle.default` has background **on**, whereas Resolve compatibility defaults below intentionally have it off. Inspector radius offers 0–32 even though the setter accepts 0–64 (`NumericOverlayDetailView.swift:664-672`).

## Fuse input contract

Add these to `text_options(key, numeric)` and its per-slot result. Each ID is `key .. suffix`: primary has `key = ""`; the legacy slots use `Pace`, `Distance`, `Elapsed`; slots 5–16 use `Widget5` … `Widget16` (`RunningOverlayNumeric.fuse:1751-1773`). For example, primary `NumericBackgroundEnabled` and `Widget5NumericBackgroundEnabled` have the same label on their respective pages. Keep all inputs in the numeric visibility group. Check the entire Fuse for ID and `IC_ControlGroup` collisions before allocating; proposed color groups 43, 44 and 45 must be rechecked against concurrent changes and validated in the host. Use `color_in` component IDs 0–3 and suffixes R/G/B/A (`RunningOverlayNumeric.fuse:1231-1238`). Numeric lengths below are design values converted consistently with existing 1280-reference normalized controls; do not blindly multiply Mac padding/radius by element scale, which the Mac minimal metrics do not do.

| Label | Suffix | Control; initial value / range |
|---|---|---|
| Background | `NumericBackgroundEnabled` | Checkbox; 0 |
| Background Color | `NumericBackgroundColorR/G/B/A` | RGBA group 43; 0,0,0,1 |
| Background Opacity | `NumericBackgroundOpacity` | Slider; 0.22, 0–1 |
| Background Radius | `NumericBackgroundRadius` | Slider; 6/1280, 0–64/1280 |
| Background Padding X | `NumericBackgroundPaddingX` | Slider; 10/1280, 0–80/1280 |
| Background Padding Y | `NumericBackgroundPaddingY` | Slider; 6/1280, 0–80/1280 |
| Background Fade Out | `NumericBackgroundFadeOutEnabled` | Checkbox; 0 |
| Background Fade Amount | `NumericBackgroundFadeOutAmount` | Slider; 0.22, 0–1 |
| Background Blur | `NumericBackgroundBlurRadius` | Slider; 0, 0–40/1280; currently unsupported in rendering, see below |
| Border | `NumericBorderEnabled` | Checkbox; 0 |
| Border Color | `NumericBorderColorR/G/B/A` | RGBA group 44; 1,1,1,1 |
| Border Opacity | `NumericBorderOpacity` | Slider; 0.22, 0–1 |
| Border Width | `NumericBorderWidth` | Slider; 1/1280, 0.5/1280–12/1280 |
| Glow | `NumericGlowEnabled` | Checkbox; 0 |
| Glow Color | `NumericGlowColorR/G/B/A` | RGBA group 45; 1,1,1,1 |
| Glow Intensity | `NumericGlowIntensity` | Slider; 0, 0–1 |
| Rotation | `NumericRotationDegrees` | Slider; 0 degrees; proposed UI range −180–180, preserve equivalent full-turn angles |
| Value Alignment | `NumericTextAlignment` | Combo Start/Center/End; 0 |
| Minimum Width | `NumericMinWidth` | Slider; 0, 0–720/1280 |
| Minimum Height | `NumericMinHeight` | Slider; 0, 0–360/1280 |

The rotation and alignment controls are proposed Resolve extensions, not observed Mac numeric behavior. Keep them neutral by default. Clamp input values at render time to the stated domains; color channels and opacity to 0–1. Input ranges in normalized units require host checks at multiple frame sizes, especially border width, because Mac's generic stroke is not canvas-scaled.

## Geometry and compositing

1. Build the value, visible unit and label using existing attachment semantics; include the icon's actual layout box when enabled. Use the union of the final layout boxes, including spacing, rather than glyph ink alone. Current `render_widget` builds parts and bounds at `RunningOverlayNumeric.fuse:1973-2015`; icon bounds need explicit inclusion.
2. With natural content size `(w,h)`, set the inner frame to `(max(w,minWidth), max(h,minHeight))`, pin content top-left, and when background is enabled add `(2*paddingX, 2*paddingY)` outside that frame. When background is off, Mac adds no background padding. The outer minimum frame also applies regardless of background. The Mac uses `context.scaled` for padding and radius but `context.scaled(value * element.scale)` for minimum size (`OverlayRenderModel.swift:55-59`, `:2140-2147`). Convert template values accordingly. Position is the unrotated top-left of the resulting frame; translate all parts together so left/top attachments do not escape that anchor.
3. Draw the rounded fill before text and icon. Border is an independent rounded-rectangle stroke centered on the outer frame boundary, even with fill disabled; trace the same radius, keeping its width independent of fill alpha. `OverlayGenericBorder` is applied after the frame (`PreviewCanvasView.swift:1413-1417`). Use filled outline geometry if the pipeline cannot stroke directly. Do not feather the border with the background.
4. For fade, approximate the Mac mask with nested rounded filled bands clipped to the outer rounded rectangle. Let `f = min(max(amount,0),0.85)` and feather width `min(width,height)*0.5*f`; use monotonically increasing alpha from zero at the outer edge to full fill alpha at the inner boundary, with smoothstep interpolation. Draw inner bands over outer ones using alpha compositing that yields the intended target alpha, not cumulative opacity. At zero fade use a single fill. This approximates the signed-distance mask in `OverlayFeatherMaskRenderer.swift:8-46`; corners and antialiasing require visual verification.
5. Background blur remains unsupported: Mac overlays ultra-thin material behind its colored fill, with material opacity `clamp(blurRadius/24,0,1)` (`OverlayFeatheredBackground.swift:26-32`); a fill-only shape cannot sample and blur the underlying video. Preserve the control value, document its no-op in the Inspector, and do not claim parity or substitute a blurred solid shape. The Fuse's existing image blur for glow/shadow does not reproduce backdrop material.
6. Proposed rotation applies to the whole assembled frame, including fill, border, icon, text and their effects, around the center of the unrotated outer frame. Positive angles should match Fusion's visual direction, explicitly verified in host. Transform all geometry or composite an intermediate image consistently; do not rotate only shapes while leaving text or effects behind. This is a Resolve design choice: Mac source provides no numeric rotation anchor.
7. Proposed value alignment changes the value within its own available row; leave label, unit and icon alignment independent. Default Start preserves today's appearance. Since Mac forces numeric value alignment leading, Center/End are a Resolve extension until Mac behavior changes.

For group glow, use the existing `glow_layers` and `draw_layers` (`RunningOverlayNumeric.fuse:948-980`) on the assembled visible fill, border, text and icon silhouette, including each part's alpha and glow color alpha. Apply the two glow layers, then the existing layered shadow of the resulting group, then foreground content, matching the modifier order at `PreviewCanvasView.swift:253-276`, `:1413-1417` as closely as the pipeline permits. Verify group shadow/glow interaction: independently drawing shadows of only original parts may omit the shadow of the glow.

## Defaults, migration and interaction

Existing Resolve projects must reopen with background, border and glow off, rotation zero and Start alignment, preserving existing placement and appearance. The current Fuse offsets content by fixed 10/1280 and 6/1280 even without a background (`RunningOverlayNumeric.fuse:1975-1981`); removing that offset on upgrade would shift old projects. Preserve this legacy placement explicitly, including when all new inputs have defaults. Decide and test how to reconcile that legacy inset with Mac's no-padding-when-off geometry before switching any existing project to a new layout path. Mac's `backgroundEnabled = true` is a model default, not the migration default.

When creating a new slot, seed available template N2 style fields once along with supporting background opacity, converting design values and colors consistently; never re-seed an existing slot during data or widget-list resync. If a template does not supply a field, use the compatibility control default. Preserve independently edited and animated inputs. Template values can differ from `OverlayStyle.default`; do not silently treat all Mac templates as default style.

Text shadow and glow use separate controls and colors; compose them in the group order above. The icon, label and unit participate in bounds and rotate with the container; their existing independent attachment controls remain intact. The Solid Color decor border has its own `DecorBorder...` inputs and renderer (`RunningOverlayNumeric.fuse:1525-1545`, `:2989-3011`); never share its state, group IDs or rendering decisions with numeric border controls.

## Tests to add

- Lua renderer tests: absent/new inputs keep existing projects visually and positionally unchanged; background off/on and asymmetric padding; frame union for every icon/label/unit side; fade zero and increasing feather; fill alpha and color alpha; border follows the same rounded frame with background both on and off; glow disabled and intensity zero yield no glow, and nonzero glow respects part and color alpha; rotated text, icon, border and fill share the frame-center anchor; min width/height expand before padding and do not shrink content; two slots maintain independent values and styling.
- Exercise non-unit element scale, different output dimensions and color opacity; compare representative synthetic renders with Mac where applicable. Test background blur's explicit no-op and retained input value.
- If template seeding changes, add Node/template tests for one-time creation seeding, missing fields, primary/legacy/WidgetN IDs, resync preservation of edits and animations, and old project migration. Run the relevant existing renderer and template suites and verify Inspector visibility, save/reopen, preview and Deliver in Resolve.

## Open questions

- Mac persists rotation but the numeric rendering path does not apply it. Should Resolve expose the proposed center-anchored rotation now, or match the Mac's current no-op? Positive-angle direction and transformed effect bounds require host validation.
- How should existing Resolve's unconditional 10×6 inset be preserved while new background-off layouts follow Mac's no-padding behavior, especially for previously saved positions and templates? A migration discriminator or deliberately retained legacy inset needs a compatibility decision and tests.
- Does the host preserve unique color-control groups across all pages and hidden control groups with the proposed indices? Check after concurrent edits. The exact visual result of stacked group glow and shadow, and normalization of border width at different output sizes, also requires rendered comparison.

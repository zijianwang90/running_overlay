# App Store Screenshot Template

Last updated: 2026-07-14

Running Overlay Studio uses one deterministic marketing layout for Mac App
Store screenshots. The visual direction follows the restrained dark-grid
presentation used by [DataLayer Studio 0.3.0](https://github.com/leeeboo/DataLayer-Studio/tree/main/assets/appstore/v0.3.0),
while using Running Overlay Studio's own telemetry background, product copy,
screenshots, and accent palette.

## Deliverables

- Device type: `APP_DESKTOP`.
- Working output: `desktop`, 1440 × 900 PNG.
- App Store Connect output: `desktop@2x`, 2880 × 1800 PNG.
- Color mode: RGB, with no alpha channel.
- Current locale: `en-US`.
- One source screenshot and one feature message per image.
- Keep the complete app workspace inside the screenshot card. Do not crop UI
  edges, dialogs, timeline controls, or the toolbar.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
accept 1440 × 900 and 2880 × 1800 as 16:10 Mac screenshot sizes. This template
keeps both, with the 2x set treated as the upload master.

The current three-image story is:

1. Batch media import and one-click FIT-time alignment.
2. Overlay design and real-time preview.
3. Transparent alpha-channel MOV export.

## Copy Standard

Use a short benefit-led headline, followed by one plain-language sentence.
Headlines should stay under roughly 36 characters when possible. Subtitles
should describe the visible workflow, avoid unsupported superlatives, and fit
on one line at 2880 px.

The approved en-US copy lives in
`AppStore/Screenshots/template.json`. Change localization copy there rather
than editing pixels in an image editor.

## Layout Standard

- Canvas: 16:10, with a dark navy telemetry/grid background.
- Headline: upper left, Avenir Next Demi Bold, off-white.
- Subtitle: directly below, Avenir Next Regular, muted cyan.
- Accent: one short cyan rule below the copy.
- Brand: the production App Icon plus a two-line `Running Overlay Studio`
  identity lockup in the upper right. Do not add a capsule, border, or button
  treatment around the brand. Apply the manifest's antialiased rounded Alpha
  mask while compositing the icon so opaque corner pixels never appear as a
  black square; do not modify the production App Icon asset itself.
- Product image: centered at 2400 × 1350 within the 2x canvas, with a subtle
  cool border, 26 px corner radius, and soft shadow.
- Safety: retain at least 40 px around the screenshot card and keep headline
  and brand regions separate.

The shared background is
`AppStore/Screenshots/template/telemetry-background.png`. It was generated for
this repository with OpenAI image generation using a no-text prompt for a dark
telemetry grid, cyan route contours, a lower-center glow, and sparse orange
accents. Text and app UI are always composited deterministically by the script;
do not ask an image model to redraw either.

## Generate And Review

Place approved 16:9 source captures under
`AppStore/Screenshots/sources/<locale>/`, update the manifest, then run:

```sh
python3 scripts/generate-appstore-screenshots.py
```

The script rejects non-16:9 input, exports both scales, and verifies exact
dimensions and the absence of alpha. It converts embedded wide-gamut source
profiles to sRGB before resizing, then embeds the sRGB profile in every output
to prevent UI accent colors from drifting. Pillow is the only Python
dependency.

Before upload, review every 2x image at full size and verify:

- all product text and controls remain legible and unaltered;
- no private paths, activity files, GPS traces, credentials, or personal data
  are visible;
- the marketing statement matches the visible screen and current behavior;
- the order tells a coherent import → design → export story;
- App Store Connect accepts the `desktop@2x` files.

Screenshot updates require focused human visual review. Do not replace approved
outputs solely because a generative model produced a different aesthetic.

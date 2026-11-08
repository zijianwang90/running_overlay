---
name: overlay-component-authoring
description: Create, modify and debug Running Overlay Studio declarative overlay components (.rocomponent or ros.component JSON). Use for sports data cards, metric overlays, lap lists, trends, generated Inspector parameters, or requests to turn an overlay design into an importable component. Validate and render with the product CLI, then provide the component and reproducible commands.
compatibility: Running Overlay Studio CLI; Skia build for PNG rendering. Repository docs are required for the current protocol vocabulary.
---

# Overlay Component Authoring

Deliver an importable component and evidence that it validates and renders.
Use the app's declarative format so preview, export and generated Inspector
controls use the same definition.

## Find the contract

When working in the repository, start with `docs/overlay-components/authoring.md`.
Read `docs/overlay-components/spec-v0.1.md` and the relevant definitions in
`docs/overlay-components/schema/ros-component-0.1.schema.json` before authoring.
These files are canonical; do not infer protocol features from similarly named
UI frameworks. Outside the repository, locate these docs or request the
current protocol and CLI before claiming validation.

Use the examples in `docs/overlay-components/examples/` as starting points:
`metric-card` for scalar metrics and auto layout, `hr-pill` for a time series,
`lap-splits` for a list. The bundled `numeric.json` is a larger reference.
Do not read Swift sources unless investigating a host implementation defect.

## Author

Infer reasonable defaults from the requested design. Ask only for missing
choices that materially change the result. Explain an unsupported feature
before proposing a protocol change.

- Choose a non-`studio.` ID, semantic version and explicit license. Preserve
  author-provided licensing; do not assign a license to third-party assets.
- Use `metric(id, unit...)` for formatted values/units/labels, raw bindings for
  arithmetic, and `coalesce` or conditions for missing sensors.
- Keep time in activity elapsed seconds. Do not substitute video or project
  timeline seconds.
- Prefer content-sized text/stacks for variable values; use fixed frames for
  bounded graphics. Content sizing cannot reference its own width/height.
- Expose requested appearance/content controls as typed `params` with defaults,
  labels and limits. Do not invent Inspector views or mutate Swift code.
- Keep repeats bounded and unnested. Use only documented nodes, signal paths,
  builtins and color syntax. Components have no scripts or network access.
- Package declared PNG/JPEG assets with provenance. Do not bundle fonts,
  private FIT files, GPS traces or source video.

## Validate and render

Run the existing product binary (`.build/debug/RunningOverlay` in the repo):

```sh
.build/debug/RunningOverlay --component-validate path/to/component.json
.build/debug/RunningOverlay --component-render path/to/component.json \
  --component-activity Tests/RunningOverlayTests/Fixtures/Activities/synthetic-component-run.fit \
  --component-at 30 --component-params path/to/params.json \
  --component-output /tmp/component.png
```

Build first if necessary. Rendering needs Skia; use the repository's SDK setup
instructions. Without Skia, run validation and explicitly report that rendering
was unavailable. Never describe an unexecuted command as passing.

Parameter overrides are a JSON object. The author CLI rejects unknown IDs,
wrong types and invalid ranges/options. Fix JSON-pointer validation errors and
runtime diagnostics, rerun, then inspect the PNG. Check empty activity and at
least two populated times; exercise a long label or a meaningful parameter
variation. The synthetic fixture lasts 60 seconds and contains three laps.
Use a missing-data fallback that remains legible without an activity file.

Use `scripts/component-gallery.sh` to check public examples. Store generated
PNGs in a temporary/output directory outside tracked source assets.

## Deliver

Provide the JSON/package path, parameter override example, exact validation
and rendering commands, results actually observed, and limitations. State which
parameters are editable. Explain importing through Overlay Pool → Components,
adding from My Components, and checking undo/redo plus save/reopen in the app.
A CLI PNG does not prove those app interactions or video export were tested.

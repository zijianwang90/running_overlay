# ADR 0015: Local FxPlug Diagnostic Carrier

Date: 2026-11-05

## Status

Accepted for a local SDK/host spike. Production distribution, color management,
retimed playback semantics and the final reusable rendering target are
unverified.
Extends [ADR 0014](0014-native-editor-plugin-contracts.md).

## Context

The developer now has Apple's FxPlug SDK and Motion. A native out-of-process
probe must establish that a real SDK-conforming effect can read an embedded
activity/template package, call the existing Skia code, and return an image.
Reimplementing overlays or linking the Studio editor into the service would
undermine the renderer boundary.

## Decision

- Build a separate diagnostic wrapper app with one FxPlug `.pluginkit` service.
  Its metadata and protocol conformance follow the installed SDK. The service
  is sandboxed, signed ad hoc, and embeds the SDK's runtime frameworks locally.
  Neither proprietary SDK sources nor generated binaries enter Git.
- The build script compiles the existing data models and Skia files directly
  into the service. It excludes Studio's entry point, `ProjectDocument`, editor
  UI, MOV exporter and weather HTTP client. Rendering-only SwiftUI icon helpers,
  preference models and MapKit model/provider definitions remain source
  dependencies. This is verified source sharing, not yet the final framework
  or a claim that every dependency is UI/framework independent.
- `SkiaMetalRenderSession` is the persistent overlay-plane renderer used by
  the writer adapter and plugin adapter. Each instance owns a GPU context and
  serializes its frames. Callers supply a same-device full-frame BGRA8 texture;
  GPU completion precedes surface detachment and return to the caller.
- The diagnostic service embeds an explicitly supplied synthetic `.roplugin`.
  The native Inspector exposes its template selection and correction. This
  does not implement arbitrary activity selection, file access/bookmarks,
  missing-resource relocation or template editing.
- The service composites the Skia overlay over the host input with a small
  authored Metal shader. This is host adaptation, not another overlay
  renderer. Full-frame input/output and normal-speed input are the spike scope;
  tiling, HDR/working-space conversion and color acceptance remain gates.
- The probe uses `FxImageTile.mediaTime` as a diagnostic source-time hypothesis
  with an explicit zero source/activity anchor plus correction. Do not claim
  trim/split/move/retime accuracy until real-host tests establish the mapping.
  No fallback converts the render callback time into activity time silently.
- Kernel caching is bounded. Cold setup can enter MainActor to prepare assets;
  hot rendering uses the cached serial session. No real-time performance claim
  follows from compilation or the sandboxed self-test.
- A diagnostic carrier was authored in Motion after the host recognized the
  service. It remains a local test artifact and must not be registered as a
  production effect or committed without asset/distribution review.
- FCP 12.4 discovery, Motion 6.4 Inspector editing, normal-speed source
  following after a blade/timeline gap, parameter save/restart and ProRes export
  were observed locally. Retiming, reverse/freeze, multicam, compound clips,
  mixed frame rates, color/alpha acceptance and distribution remain gates.

## Consequences

- The native binary proves linkage of the same renderer without Studio's UI.
- A sandboxed self-test validates packaged resources, SDK/framework loading
  and actual Metal pixels. The separate local FCP/Motion checks establish the
  diagnostic host path for the tested normal-speed case.
- The diagnostic identifiers remain distinct from a future production plugin.
- Full rendering-target extraction, portable render preferences, offline
  resources, file selection and distribution are still required.
- Timing, alpha/color, SDK redistribution and human-reviewed Motion assets
  require focused review under `AGENTS.md` before merge/distribution.

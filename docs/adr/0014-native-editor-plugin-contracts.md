# ADR 0014: Shared Contracts For Native Editor Plugins

Date: 2026-11-05

## Status

Accepted for the shared data/time contracts, developer frame probe and local
FxPlug diagnostic. Production rendering extraction, broader host compatibility
and distribution remain unverified.
Extends ADR 0013; amends ADR 0009's prohibition on host rendering to permit
hosts to call the same renderer implementation.

## Context

Layers 0/1 already produce render jobs and editor timelines. Native effects
need arbitrary frame seeking, persistent selection, and alignment that follows
source content after trimming or moving a clip. Paths to private FIT files
and implicit conversions of host callback time cannot meet these needs.

Final Cut Pro is the first native-effect target, followed by Resolve. Premiere
is deferred; existing alpha movies remain the CapCut interchange path.
Template authoring stays in Studio; the native Inspector needs only a data
package, template selection, and time correction. No Electron window or
second renderer is introduced.

## Decision

1. `OverlayPluginCore` is an independently buildable Swift library using
   Foundation and CryptoKit, without UI, app executable, or editor SDK
   dependencies. It owns transport and time conversion. Domain decoding and
   Skia rendering remain in Studio until extracted and verified separately.
   Native Xcode compiles the same core sources via the project generator;
   SwiftPM imports the library.
2. A versioned `.roplugin` JSON file embeds an activity snapshot and named
   template documents. Payloads have SHA-256 digests and schema versions.
   Original FIT/video URLs, bookmarks and credentials are not transport inputs.
   Snapshot dates use milliseconds since Unix epoch to retain subseconds;
   template encoding remains compatible with `.rotemplate`. These are data
   files, not executable plugins. Readers reject unsupported schemas, changed
   payloads, invalid template selections and renderer mismatches.
3. A normal-speed Effect stores a rational original-media source anchor, an
   activity-elapsed anchor, and a correction in seconds. Sampling is stateless:

   `activityElapsed = activityAnchor + (mediaSourceTime - sourceAnchor) + correction`

   Positive correction advances activity. Outside `[0, activityDuration]`
   means transparent output, never a held boundary metric. Host adapters must
   explicitly convert input/template/timeline time to original-media source
   time. The core API intentionally has no timeline-placement parameter.
4. The first frame probe accepts numeric overlays and solid-color decor only.
   Maps, weather, embedded assets and other modules fail explicitly until
   offline dependencies and shared sessions are ready. Transport can carry
   other native templates; packaging does not certify render readiness.
5. The probe explicitly calls the existing Skia PNG export path, without a
   SwiftUI fallback. The local FxPlug diagnostic also renders a full-frame host
   Metal texture, but this does not certify tiling, HDR/color transforms,
   concurrent instances or real-time performance. Layer 0/1 export behavior
   remains available.
6. Effect and eventual long Title/Generator carriers have separate timing
   semantics. Retiming, reverse playback and frozen frames require separate
   host verification. Backward scrubbing remains a supported request order.
7. Use Apple's FxPlug SDK and an authored Motion template for the FCP adapter.
   Do not commit proprietary SDKs, fabricate registration/template files,
   install into editor directories, or claim signed/App Store acceptance
   before distribution validation.

## Consequences

- Core contracts can be tested without an editor SDK and reused by Resolve.
- Digests detect changed payloads; they do not authenticate authors.
- Fonts are not embedded; installed/bundled font availability still matters.
- App preferences (such as heart-rate zones and display timezone) are not yet
  part of the snapshot; extracting their render context is a host-integration
  gate. The frame probe uses the current Studio process's preferences.
- Maps/weather and user-resource preparation remain subsequent milestones.
- Normal-speed split/gap source following and parameter save/restart have been
  verified in the local diagnostic. Retiming, reverse/freeze, multicam,
  compound clips, mixed frame rates, full GPU safety/performance, color/alpha,
  signing and distribution remain explicit gates. Timing and format changes
  require focused human review under `AGENTS.md`.

## References

- [Apple: Understanding time in FxPlug](https://developer.apple.com/documentation/professional-video-applications/understanding-time-in-fxplug)
- [Apple: Preparing plug-ins for use in Final Cut Pro](https://developer.apple.com/documentation/professional-video-applications/preparing-plug-ins-for-use-in-final-cut-pro)
- [Developer workflow and remaining gates](../development/native-editor-plugins.md)

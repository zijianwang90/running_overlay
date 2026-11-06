# Native Editor Plugins

## Current Scope

The local native-plugin branch includes Layers 0/1 and an executable first
slice of Layer 2: shared data/time contracts, package preparation, a Skia
frame probe and a locally registered FxPlug diagnostic. No production
FCP/Resolve effect ships yet. FCP comes first, Resolve next, Premiere is
deferred, and CapCut retains alpha movie interchange. See
[ADR 0014](../adr/0014-native-editor-plugin-contracts.md).

```sh
swift build --target OverlayPluginCore
./scripts/test.sh Plugin
```

The library has no UI/editor SDK dependencies. Studio owns domain decoding.
`SkiaMetalRenderSession` now provides a persistent context shared by the export
writer adapter and plugin frame adapter. The native diagnostic compiles the
same rendering/model sources without the editor shell. Extracting a final
public rendering framework remains a subsequent milestone.

## Prepare Data

Use an existing [Layer 0 job](export.md), with activity/template paths relative
to the job file if desired. Preparation uses only its activity, template and
canvas; it does not render spans, create the movie output folder or cache MOVs.

```sh
swift run RunningOverlay --prepare-plugin-package job.json \
  --plugin-output run.roplugin
```

The destination parent must exist. An existing package is never silently
replaced. The single JSON file embeds activity and template documents, so their
original files are not needed afterward. Loading checks envelope/domain
versions, canvas, unique template IDs, hashes, activity ordering, template
metadata and renderer compatibility. Limits are 64 MiB and 128 templates.
The service accepts multiple templates; the command packages the job's single
selected template. Activity snapshots inside the package use milliseconds
since Unix epoch, retaining subsecond timestamps.

Packages include activity data (including coordinates when present) and
template content. Treat them as user data; never commit real packages. No
source video, media URL, bookmark or credential is copied.

## Probe A Frame

Use a numeric template or solid-color decor for this first spike. Built-in
presets containing route maps are transportable but fail frame rendering
explicitly until resource preparation is implemented. Fonts are not embedded.
The snapshot does not yet carry application preferences such as heart-rate
zone thresholds or the display timezone. The frame probe uses the current
Studio process's preferences; cross-process/cross-machine pixel equivalence
for those dependent styles needs an explicit render-context contract before
host integration. Prefer plain elapsed-time/heart-rate metrics for this probe.

With the product environment from the [Skia SDK guide](skia-sdk.md):

```sh
swift run RunningOverlay --plugin-frame run.roplugin \
  --plugin-output frame.png \
  --plugin-source-value 300 --plugin-source-timescale 30 \
  --plugin-anchor-value 0 --plugin-anchor-timescale 30 \
  --plugin-activity-anchor 120 --plugin-offset 0.5
```

This maps original-media source `10s` to activity elapsed `130.5s`. Positive
offset advances the activity. For 29.97 fps use 1001-tick frames in a 30000
timescale, without rounding to integer fps. All anchors are explicit, even
zero. Optional `--plugin-template UUID` selects an embedded template; otherwise
the first is selected. Missing IDs fail rather than selecting another template.
Unknown/repeated options and combined headless modes are rejected.

The command explicitly requires Skia, fails in SDK-free builds, and writes a
transparent PNG through the Studio calibration-export pipeline without opening
an editor window. The CLI reports out-of-activity requests as errors; the core
returns nil so a future host can composite transparency. Normal-speed Effects
are the first host scope. Backward scrubbing is supported as a request order;
retiming/reverse/freeze playback remain unverified.

This is a correctness probe, not a real-time performance claim. Setup creates
one persistent session; hot calls reuse its context and preloaded assets.
Frame rendering has no actor hop or package decoding. The serial session
validates texture dimensions, format/usage and device, completes GPU writes,
and detaches the borrowed surface before returning. The current shared texture
interface is full-frame BGRA8; host tiling/working-space/HDR handling remains
outside that interface.

Probe repeated/out-of-order requests in one process and context:

```sh
swift run RunningOverlay --plugin-frames run.roplugin \
  --plugin-output probe-frames \
  --plugin-source-values 30,150,30,-1 --plugin-source-timescale 30 \
  --plugin-anchor-value 0 --plugin-anchor-timescale 30 \
  --plugin-activity-anchor 0
```

This writes `frame-000.png` through `frame-003.png` in request order. The last
frame clears to transparent rather than retaining the preceding metrics. The
destination directory must not exist; the sequence is limited to 256 frames.
PNG conversion runs outside the native render callback. Single-frame mode
retains its explicit out-of-activity error for debugging.

## Build The Local FxPlug Diagnostic

With Apple's installed SDK, product Skia SDK and a prepared **synthetic**
numeric-only package:

```sh
python3 scripts/build-fxplug-spike.py --skia-dir "$SKIA_DIR" \
  --package run.roplugin --output build/fxplug-local
```

The arm64 developer build produces `Running Overlay FxPlug Diagnostic.app`
containing a sandboxed `.pluginkit` service. It embeds the installed FxPlug /
PluginManager runtime frameworks, Skia notices and the supplied demo data;
then verifies signatures and runs a native packaged Metal self-test. It does
not install or register the effect. Set `FXPLUG_SDK_DIR` or
`FXPLUG_FRAMEWORK_DIR` only when the SDK installation uses a different path.
Xcode's Metal Toolchain is required to compile the compositor shader.

The native controls expose the bundled diagnostic activity, template and
correction. No arbitrary file selector is implemented yet. The compositor
accepts native BGRA8 / RGBA16F / RGBA32F output while drawing the overlay into
a private BGRA8 plane; that does not certify color transforms or HDR. In local
FCP 12.4 testing, `FxImageTile.mediaTime` followed original source media at
normal speed after a blade and a three-second timeline gap. It remained
source-relative after the effect parameters were saved and FCP restarted. This
does not establish retiming, reverse playback, freeze frames, multicam,
compound clips or frame-rate mismatch behavior. See
[ADR 0015](../adr/0015-fxplug-diagnostic-carrier.md) for the source boundary,
cache and distribution limits.

## FCP Gates

1. **Contracts/frame probe:** this slice. Verify rational anchors, portability
   and parity with direct Skia frames.
2. **FxPlug/Motion spike:** the SDK/Motion registration, native Inspector,
   Motion carrier, sandboxed Metal rendering, normal-speed source following,
   parameter save/restart and ProRes export have been verified locally in
   Motion 6.4 and FCP 12.4. Arbitrary package/file selection and relocation
   remain unimplemented. Retiming, reverse/freeze, multicam, compound clips,
   mixed frame rates, full tiling, HDR/color transforms, signing and
   distribution remain unverified.
3. **Shared rendering target:** extract sampling/layout/drawing and resources
   without `ProjectDocument` or editor views. Preserve one Skia implementation;
   snapshot render preferences and validate multiple instances, concurrent and
   out-of-order frame requests.
4. **Native Inspector/resources:** package/template/correction, missing-file
   relocation, maps/weather/fonts/user assets and version diagnostics.
5. **Acceptance/distribution:** trim/split/move/duplicate/undo/redo/restart,
   FPS/alpha/color and signing/install/uninstall. Define a separate timing
   contract before long Title/Generator carriers.

Obtain the SDK from [Apple Developer Downloads](https://developer.apple.com/download/all/?q=FxPlug).
Apple controls SDK installation/access. Do not vendor it or record developer
paths. An FxPlug effect needs a Motion template to enter FCP:
[Apple preparation guide](https://developer.apple.com/documentation/professional-video-applications/preparing-plug-ins-for-use-in-final-cut-pro).
Host input/template/timeline time differ:
[Apple time model](https://developer.apple.com/documentation/professional-video-applications/understanding-time-in-fxplug).

## Resolve And Later Hosts

After FCP verifies the shared renderer/time boundary, add a Resolve adapter
using the same package and alignment. Port useful capture-time/clock-model
behavior from the frozen prototype with tests; do not merge its separate
JS/Fuse renderer. Choose the carrier/distribution method after SDK and sandbox
verification. A script bridge reusing Layer 0 is not a live native effect.

## Verification

Run `./scripts/check.sh` and `./scripts/visual-test.sh`. Product verification
sets `SKIA_DIR`, `SKIA_GPU=1` and `SKIA_GRAPHITE=1` with an awake display, as
described in [Testing](../testing.md).

`PluginTimeMappingTests` covers subframes, corrections, seek order, concurrency,
persistence, bounds and invalid times. It cannot establish which FCP API
returns the right original-media time. `PluginDevelopmentTests` covers domain
validation, data portability, headless routing and resource errors. With Skia
it compares package frames against direct Studio pixels, including repeated
frames after backward seeks. No new media or snapshot fixtures are required.
`PluginMetalRenderSessionTests` additionally exercises real persistent Metal
contexts through Ganesh/Graphite, invalid targets/times, transparent clears,
borrowed-texture release, background concurrent calls and separate instances.

Local FCP verification used a synthetic 1280×720/30 fps source and the bundled
synthetic diagnostic package. It covered Effects Browser discovery, native
parameters, a 10-second correction, source 5 s plus a 10-second correction
showing activity 15 s, a blade and source seek, a three-second timeline gap,
save/restart persistence, and a 15-second ProRes export. The exported 9-second
pixel frame retained the source background and transparently composited the
overlay at activity 16 s.

Focused human review is required for the data/time contract, host timing,
alpha/color and the Motion asset under `AGENTS.md`. Wider real-host and
distribution gates remain open.

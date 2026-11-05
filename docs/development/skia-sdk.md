# Experimental Skia SDK and GPU Backends

The target product dependency is the pinned source-built m159 package,
containing Ganesh and Graphite Metal. The earlier m152 Ganesh package remains
compatible for regression comparisons. SDK-free builds are developer/CI builds. Skia-enabled builds now default to Skia, and the dual-backend
SDK defaults to Graphite (ADR 0011). This guide covers the SDK archive, not a distributable app bundle.

## Pinned Source and Recipe

- Upstream: <https://skia.googlesource.com/skia.git>
- Candidate: m159, commit `1bbd9b972a4667a98fb16b8441444b2282fed0ac`.
- Baseline: m152, commit `0873ec164a06966b90ae0d43ef783cfb180084ae`.
- Recipe: [`experimental-args.gn`](../../scripts/skia/experimental-args.gn).
- Builder: [`build-skia-experimental.py`](../../scripts/build-skia-experimental.py).

On macOS arm64 with Xcode command-line tools, Python 3, git, and curl:

```sh
python3 scripts/build-skia-experimental.py \
  --source /tmp/overlay-skia-source \
  --output /tmp/overlay-skia-sdk \
  --jobs 8
```

The source checkout must be at the pinned commit without tracked changes. The
output must not exist. The script fetches pinned GN/Ninja tools through TLS,
checks their archive hashes, and builds a Release component dylib. The recipe
retains CPU raster, CoreText, Ganesh, Graphite and native Metal; it excludes
Dawn, Vulkan, external codecs, HarfBuzz, ICU, PDF, SVG, skottie and
PartitionAlloc. The app already supplies decoded BGRA images and CoreText
shaping. Consequently this is a workload-specific build, not a drop-in general
Skia distribution or a pure version-only comparison with the baseline prebuilt.

The SDK contains headers/private source headers, `lib/libskia.dylib`, the exact
GN arguments, a build manifest (commit, compiler/SDK/tool versions and hashes),
Skia/skcms notices, a tar.gz, and its SHA-256 checksum. Source/build directories
and artifacts stay outside the repository. The dylib uses
`@rpath/libskia.dylib`; its linked dependencies are system libraries/frameworks.
The upstream GN arm64 toolchain targets macOS 11; the application still requires
macOS 15. The SDK is built on the current development SDK and still needs
validation on the oldest supported macOS before distribution.

## Selecting an Engine

Point `SKIA_DIR` at the unpacked SDK directory, then:

```sh
SKIA_DIR=/path/to/unpacked-sdk SKIA_GPU=1 SKIA_GRAPHITE=1 \
  RUNNING_OVERLAY_RENDERER=skia RUNNING_OVERLAY_SKIA_BACKEND=graphite \
  swift run RunningOverlay
```

- `SKIA_GRAPHITE=1` compiles the Graphite bridge and requires the dual-backend
  SDK. It does not select the runtime engine.
- `RUNNING_OVERLAY_SKIA_BACKEND=ganesh|graphite` selects the engine when a GPU
  context is created; Graphite is the default when compiled, otherwise Ganesh. Both hosts use the same engine.
- `RUNNING_OVERLAY_RENDERER=skia` is optional in Debug; Skia-enabled builds
  default to Skia and Release ignores the SwiftUI override. The preview header
  comparison toggle remains Debug-only and local to preview.
- Selecting Graphite in a Ganesh-only build fails to create a context; it never
  silently substitutes Ganesh. The existing m152 SDK still works without
  `SKIA_GRAPHITE`.

The C bridge owns Graphite Context/Recorder/surface lifetimes. It snaps and
inserts recordings before submitting on the host's Metal queue. Preview
presentation follows submission on that queue; export synchronizes before the
writer reads a buffer. CPU readback uses Graphite's asynchronous read API plus
a synchronous submission. GPU upload/submission errors fail export rather than
silently delivering partial frames.

Graphite requires an explicit image provider. Each recorder has its own LRU
for raster-image uploads, capped at 128 entries and 64 MiB of estimated image
storage (including a conservative mip allowance); this is not a hard cap on
all GPU memory. Providers are never shared across contexts or queues. This
preserves map snapshots, SF Symbols and masks that Graphite otherwise drops.

## Verification and Performance

```sh
SKIA_DIR=/path/to/unpacked-sdk SKIA_GPU=1 SKIA_GRAPHITE=1 \
  RUNNING_OVERLAY_SKIA_BACKEND=graphite ./scripts/check.sh

SKIA_DIR=/path/to/unpacked-sdk SKIA_GPU=1 SKIA_GRAPHITE=1 \
  RUNNING_OVERLAY_SKIA_BACKEND=ganesh \
  ./scripts/test.sh 'Skia.*GPUParityTests|SkiaBackendSelectionTests|SkiaProductionExportTests'

python3 scripts/benchmark-skia-backends.py \
  --baseline /path/to/m152-sdk \
  --candidate /path/to/m159-sdk \
  --output /tmp/overlay-engine-benchmark
```

The benchmark builds the same Release app against each SDK, preserves both
executables, and compares m152 Ganesh, m159 Ganesh and m159 Graphite serially.
It uses synthetic FIT plus Easy Run, 1080p/4K, both codecs, 30 fps/5 Hz layer
data, five five-second clips, three trials, and a short discarded warmup.
Backend order rotates between trials. JSON includes every run and median
export/render/writer-wait/process times. Export profiles must report Release,
`skiaMetal`, and identical output/sample counts; that render-path name denotes
the Metal host for either engine. No private media or live MapKit data is used.

Keep version/backend experiments separate from export scheduling changes.
Neither a new milestone nor Graphite implies faster rendering. Review complete
pixels first, then render time and total encoded-export time separately.
The maintainer accepted the Graphite sample and authorized the Skia product
cutover. Oldest-OS validation, Developer ID/App Store signing and distribution
review remain release gates. Local ad-hoc app packaging is supported.

Measured results for the initial candidate are recorded in the
[2026-11-03 evaluation](../benchmarks/2026-11-03-skia-engines.md). That matrix
found no demonstrated total-export speedup. The subsequent adoption decision
in ADR 0011 is based on visual acceptance and sufficient throughput, not an
engine-version speedup claim.

## Xcode and CI Integration

Native Xcode builds default to the product configuration. Supply
`SKIA_DIR=/path/to/unpacked-sdk ARCHS=arm64` as build settings when building or
archiving `RunningOverlay`. The project generator includes the C++/Objective-C++
bridge and its explicit Clang module without recording the SDK's local path.
Use `SKIA_ENABLED=NO` only for SDK-free editor development.

`scripts/validate-skia-sdk.py SDK_DIRECTORY` checks the pinned source commit,
recipe, builder and dylib hash before packaging. Both app packaging paths copy
the exact SDK notices into `Resources/Legal/Skia`; native Xcode signs the embedded
dylib before its final app-signing phase. See the [release guide](release.md)
for unsigned archive commands and local versus distribution signing.

The shared `.github/actions/setup-skia` action builds the SDK from pinned source
on a cache miss. CI's `skia-product` check aggregates parallel Graphite tests,
native archive, and SwiftPM packaging jobs; release tags use the same setup. No SDK download
URL, repository secret or committed binary is required. Remote Actions results
and real-certificate distribution acceptance must still be checked before shipping.

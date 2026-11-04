# Skia Engine Evaluation — 2026-11-03

Historical engine-only evaluation. The subsequent maintainer-approved
[ADR 0011](../adr/0011-skia-product-renderer.md) selects Graphite/Skia defaults
based on visual acceptance and sufficient throughput. The recommendations below
record the earlier experiment; they are not the current cutover policy.

The source-built m159 SDK works with Ganesh and Graphite Metal, but this
experiment does not establish an export throughput improvement over m152.
Keep m152 Ganesh as the current development baseline and both newer paths
opt-in. No shipping dependency or default renderer is changed.

## Method

- Apple M3, macOS 27.2; the same Release application source for all variants.
- Baseline: m152 `0873ec164a06966b90ae0d43ef783cfb180084ae`; candidate: m159
  `1bbd9b972a4667a98fb16b8441444b2282fed0ac`, with Ganesh and Graphite Metal.
- Synthetic FIT plus bundled Easy Run, with only reference resolution changed
  for 4K; no private media, GPS trace, network map tiles or weather requests.
- 1080p/4K, ProRes 4444/HEVC alpha; five five-second clips, 30 fps, 5 Hz
  layer data: 750 encoded frames and 125 unique rendered samples per trial.
- Three fresh-process trials per case/backend, short discarded warmup, rotating
  serial order. No other builds or test suites ran during measured exports.
- Total below is the sum of segment export durations. Render includes texture
  wrapping, draw command generation and synchronous GPU completion. Process
  startup/context/asset work is separately recorded in the raw JSON.
- The candidate is a workload-specific minimal build, not the same third-party
  prebuilt recipe. Do not attribute every difference solely to Skia version.

## Results

Median export time in seconds (lower is better):

| Output | m152 Ganesh | m159 Ganesh | m159 Graphite |
|---|---:|---:|---:|
| 1080p ProRes | 1.413 | 1.409 | 1.423 |
| 4K ProRes | 3.029 | 3.017 | 2.995 |
| 1080p HEVC alpha | 5.164 | 5.171 | 5.178 |
| 4K HEVC alpha | 17.158 | 17.146 | 17.164 |

Total median differences are within roughly 1.2%. For 4K ProRes, the apparent
Graphite improvement overlaps ordinary trial variation: m152 trials span
2.995–3.068 s and Graphite trials span 2.983–3.088 s. Three trials on one Mac
are insufficient to claim a stable speedup.

Graphite render-plus-GPU-sync time is slightly higher in this workload:
4K ProRes medians are 1.103 s for m152 Ganesh, 1.111 s for m159 Ganesh, and
1.169 s for m159 Graphite. HEVC is dominated by encoder backpressure; 4K
writer wait alone is about 13.6 s out of 17.2 s. Upgrading the engine does
not remove that encoder bottleneck.

## Correctness and Limits

The initial Graphite bridge dropped raster-backed maps/icons because Graphite
requires an explicit image provider. A per-recorder bounded LRU upload provider
fixed the missing content. The existing GPU parity thresholds were retained;
all 14 focused backend/GPU-parity/production-export tests passed, including
map snapshot upload and both codec decodes. Full compatibility checks are
recorded in the monthly project log.

Automated parity is not human approval of every preset. Oldest-supported-macOS
validation, app bundling/signing and focused human visual/license review remain
before adopting the experimental SDK. Current gains do not justify a default
cutover for speed. A more useful next experiment is export-host scheduling
(for example, the existing spike's ping-pong contexts), measured separately
against this fixed production pipeline.

See the [SDK guide](../development/skia-sdk.md) for rebuild and benchmark
commands and the [raw measurements](2026-11-03-skia-engines.json) for all 36
trials, medians, SDK/binary hashes and the application-tree hash. The recorded
source commit is the branch base; the measured tree includes the uncommitted
production-export and engine experiment changes.

The generated SDK archive and videos remain outside the repository.

# Bounded Skia Pipeline Experiment — 2026-11-03

## Decision

Keep the serial production host. One-sample prefetch helps 1080p ProRes but
has no consistent benefit across the required suite. Remove its production
implementation rather than keep a task group, an extra pixel buffer and more
cancellation/ownership states. The maintainer explicitly prioritized sufficient
speed and product cutover over further optimization. Do not begin a dual-context
or deeper-queue experiment without a new demonstrated product bottleneck.

## Method

Same Apple M3 and m159 source-built Graphite SDK as the engine evaluation.
One Release binary, synthetic FIT plus bundled Easy Run; 1080p/4K, ProRes 4444
and HEVC alpha, 30 fps/5 Hz Layer Data. Each trial exports five five-second
clips (750 encoded frames, 125 unique samples). Three serial trials per mode,
rotating order, fresh processes and a discarded warmup for each case/mode.
No concurrent builds or tests during measurement. Each profile is checked for
Release, `skiaMetal`, frame count and unique-sample count.

The experimental host rendered at most one future unique sample in a structured
child task, using the same locked context. GPU writes completed before encoder
append; buffers were never rewritten after handoff. Structured task lifetime
ended before the segment/destination lifecycle. Tests decoded both codecs with
serial/prefetch, verified advancing elapsed-time text, alpha, ordering, timestamps,
reuse, progress and cancellation before measurement.

## Results

Median total export seconds; lower is better:

| Output | Serial | One-sample prefetch |
|---|---:|---:|
| 1080p ProRes 4444 | 1.526 | 1.284 |
| 4K ProRes 4444 | 3.045 | 3.139 |
| 1080p HEVC alpha | 5.219 | 5.209 |
| 4K HEVC alpha | 17.203 | 17.220 |

All serial cases already finish the 25-second input faster than real time.
This is sufficient for the current development cutover, not a universal speed
promise for every Mac, preset or Layer Data cadence. The 4K ProRes medians do
not support accepting added scheduling complexity. HEVC stays encoder-bound.
With overlapping work, writer-wait time includes concurrent render work, so
phase durations cannot be added to obtain wall time.

## Reproduction And Limits

The experiment extended `scripts/benchmark-skia-backends.py` locally with a
`--pipeline-only` serial/prefetch comparison on the candidate SDK. After rejecting
prefetch, both the production implementation and that temporary command mode
were removed. Raw trials, binary/source-tree hashes and settings remain in
[the measurement record](2026-11-03-skia-pipeline.json). The local benchmark
artifact directory retains the executable, resources, SDK-independent experiment
source copies, the temporary runner and exported clips outside Git. These are
an experimental record, not a currently supported product option.

No new snapshots, media, private activity or GPS data are committed. This
experiment does not change codecs, time conversions or the project schema.
See [ADR 0011](../adr/0011-skia-product-renderer.md) for the product decision.

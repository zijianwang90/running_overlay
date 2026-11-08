#!/usr/bin/env bash
# Reproduce the public component authoring examples without private inputs.
set -euo pipefail
cd "$(dirname "$0")/.."
binary="${1:-.build/debug/RunningOverlay}"
output="${2:-${TMPDIR:-/tmp}/running-overlay-component-gallery}"
fixture="Tests/RunningOverlayTests/Fixtures/Activities/synthetic-component-run.fit"
mkdir -p "$output"
for name in metric-card hr-pill lap-splits; do
  package="docs/overlay-components/examples/$name.rocomponent.json"
  "$binary" --component-validate "$package"
  "$binary" --component-render "$package" --component-output "$output/$name-empty.png"
  for seconds in 0 30 60; do
    "$binary" --component-render "$package" \
      --component-activity "$fixture" --component-at "$seconds" \
      --component-params "docs/overlay-components/examples/params/$name.json" \
      --component-output "$output/$name-$seconds.png"
  done
done
printf 'Gallery PNGs: %s\n' "$output"

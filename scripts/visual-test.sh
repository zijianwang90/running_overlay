#!/usr/bin/env bash
set -euo pipefail

export VISUAL_SNAPSHOT_DIR="${VISUAL_SNAPSHOT_DIR:-$PWD/Tests/RunningOverlayTests/Fixtures/VisualSnapshots}"
swift test --filter VisualRegressionTests

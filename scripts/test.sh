#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  swift test --filter "$1"
else
  swift test
fi

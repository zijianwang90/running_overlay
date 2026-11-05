#!/usr/bin/env bash
set -euo pipefail

python3 scripts/tests/test_validate_skia_sdk.py
python3 scripts/tests/test_skia_ci_scope.py
swift build
swift test "$@"
./scripts/generate-xcode-project.rb
git diff --exit-code -- RunningOverlay.xcodeproj
xcodebuild -project RunningOverlay.xcodeproj -list >/dev/null
./scripts/check-doc-links.rb

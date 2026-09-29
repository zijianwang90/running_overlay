#!/usr/bin/env bash
set -euo pipefail

swift build
swift test
npm --prefix RunningOverlayResolve run check
./scripts/generate-xcode-project.rb
git diff --exit-code -- RunningOverlay.xcodeproj
xcodebuild -project RunningOverlay.xcodeproj -list >/dev/null
./scripts/check-doc-links.rb

#!/usr/bin/env bash
set -euo pipefail

swift build
swift test
./scripts/generate-xcode-project.rb
git diff --exit-code -- RunningOverlay.xcodeproj
xcodebuild -project RunningOverlay.xcodeproj -list >/dev/null
./scripts/check-doc-links.rb

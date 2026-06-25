#!/usr/bin/env bash
set -euo pipefail

repo_search() {
  local insensitive=false
  if [[ "${1:-}" == "-i" ]]; then
    insensitive=true
    shift
  fi
  local pattern=$1
  shift
  if command -v rg >/dev/null 2>&1; then
    if $insensitive; then
      rg -n -i "$pattern" "$@"
    else
      rg -n "$pattern" "$@"
    fi
  else
    if $insensitive; then
      grep -R -n -i -E "$pattern" "$@"
    else
      grep -R -n -E "$pattern" "$@"
    fi
  fi
}

repo_query() {
  local pattern=$1
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -q "$pattern" "$@"
  else
    grep -q -E "$pattern" "$@"
  fi
}

required_files=(
  AGENTS.md
  LICENSE
  COMMERCIAL-LICENSE.md
  TRADEMARKS.md
  CLA.md
  README.md
  CONTRIBUTING.md
  PRIVACY.md
  SECURITY.md
  SUPPORT.md
  MAINTAINERS.md
  CODE_OF_CONDUCT.md
  THIRD_PARTY_NOTICES.md
  docs/index.md
  docs/assets-and-licenses.md
  docs/source-available-readiness.md
  docs/development/overview.md
  docs/development/app-and-import.md
  docs/development/timeline.md
  docs/development/overlays-and-preview.md
  docs/development/persistence.md
  docs/development/export.md
  docs/development/release.md
  docs/development/quality.md
  docs/app-store-readiness.md
  docs/project-log/2026-06.md
  docs/testing.md
  RunningOverlay.xcodeproj/project.pbxproj
  RunningOverlay.xcodeproj/xcshareddata/xcschemes/RunningOverlay.xcscheme
  AppStore/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png
  scripts/generate-xcode-project.rb
  .github/workflows/ci.yml
  .github/dependabot.yml
  .github/CODEOWNERS
  .github/ISSUE_TEMPLATE/documentation.yml
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required publication file: $file" >&2
    exit 1
  fi
done

if [[ $(wc -l < docs/development.md) -gt 150 ]]; then
  echo "docs/development.md must remain a routing index, not a monolithic guide." >&2
  exit 1
fi

if [[ $(wc -l < docs/project-log.md) -gt 150 ]]; then
  echo "docs/project-log.md must remain an archive index, not a monolithic log." >&2
  exit 1
fi

while IFS= read -r archive; do
  if [[ $(wc -l < "$archive") -gt 1500 ]]; then
    echo "Project-log archive exceeds 1,500 lines and must be split: $archive" >&2
    exit 1
  fi
done < <(find docs/project-log -type f -name '*.md' | sort)

required_ignore_patterns=(
  '^\.env$'
  '^\.env\.\*$'
  '^\*\.fit$'
  '^\*\.gpx$'
  '^\*\.tcx$'
  '^\*\.mov$'
  '^\*\.mp4$'
  '^\*\.p8$'
  '^\*\.p12$'
  '^\*\.pem$'
  '^\*\.key$'
  '^\*\.mobileprovision$'
)

for pattern in "${required_ignore_patterns[@]}"; do
  if ! grep -qE "$pattern" .gitignore; then
    echo "Missing sensitive-data .gitignore rule: $pattern" >&2
    exit 1
  fi
done

while IFS= read -r path; do
  case "$path" in
    Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.fit)
      ;;
    .env.example)
      ;;
    *.fit|*.FIT|*.gpx|*.GPX|*.tcx|*.TCX|*.mov|*.MOV|*.mp4|*.MP4|*.m4v|*.M4V|*.avi|*.AVI|*.mkv|*.MKV|*.zip)
      echo "Tracked private or generated media/activity artifact: $path" >&2
      exit 1
      ;;
    .env|.env.*|*.cer|*.certSigningRequest|*.crt|*.csr|*.der|*.key|*.pem|*.p8|*.p12|*.mobileprovision|*.provisionprofile)
      echo "Tracked credential or signing artifact: $path" >&2
      exit 1
      ;;
  esac
done < <(git ls-files)

if git grep -n -I -E '/Users/[^/]+/|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' -- \
  ':!scripts/publication-audit.sh'; then
  echo "Machine-specific path or private key marker detected." >&2
  exit 1
fi

if find Sources Tests -type f \( -name '*.ttf' -o -name '*.otf' \) -print -quit | grep -q .; then
  echo "Bundled font detected. Add explicit license provenance before publication." >&2
  exit 1
fi

if repo_search 'URLSession|URLRequest|CLGeocoder|CLLocationManager|api\.openweathermap\.org|archive-api\.open-meteo\.com' Sources >/dev/null; then
  if ! repo_query 'Open-Meteo|OpenWeather|geocoding services' PRIVACY.md; then
    echo "PRIVACY.md must document current weather and geocoding network behavior." >&2
    exit 1
  fi
fi

if repo_search -i 'Sentry|Firebase|Crashlytics|analytics|telemetry upload' Sources Package.swift >/dev/null; then
  if ! repo_query 'analytics|telemetry|crash-reporting' PRIVACY.md; then
    echo "PRIVACY.md must document analytics, telemetry, or crash-reporting behavior." >&2
    exit 1
  fi
fi

repo_query 'macOS Keychain' PRIVACY.md || {
  echo "PRIVACY.md must document credential storage." >&2
  exit 1
}

repo_query '@zijianwang90' .github/CODEOWNERS || {
  echo "CODEOWNERS must name the repository maintainer." >&2
  exit 1
}

repo_query '^# PolyForm Shield License 1\.0\.0$' LICENSE || {
  echo "LICENSE must contain PolyForm Shield License 1.0.0." >&2
  exit 1
}

repo_query '^Required Notice: Copyright 2026 Zijian Wang\.$' LICENSE || {
  echo "LICENSE must identify the project copyright owner." >&2
  exit 1
}

repo_query 'Contributor License Agreement' .github/pull_request_template.md || {
  echo "Pull requests must require CLA affirmation." >&2
  exit 1
}

if repo_search 'MIT License|repository MIT license|under MIT' \
  README.md CONTRIBUTING.md LICENSE docs/assets-and-licenses.md \
  docs/contributing.md docs/source-available-readiness.md; then
  echo "Active licensing documentation still references MIT." >&2
  exit 1
fi

repo_query 'package-ecosystem: "github-actions"' .github/dependabot.yml || {
  echo "Dependabot must monitor GitHub Actions." >&2
  exit 1
}

repo_query 'package-ecosystem: "swift"' .github/dependabot.yml || {
  echo "Dependabot must monitor Swift packages." >&2
  exit 1
}

echo "Source-publication repository audit passed."

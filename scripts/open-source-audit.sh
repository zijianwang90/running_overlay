#!/usr/bin/env bash
set -euo pipefail

required_files=(
  AGENTS.md
  LICENSE
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
  docs/open-source-readiness.md
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
  .github/workflows/ci.yml
  .github/dependabot.yml
  .github/CODEOWNERS
  .github/ISSUE_TEMPLATE/documentation.yml
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required open-source file: $file" >&2
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
  ':!scripts/open-source-audit.sh'; then
  echo "Machine-specific path or private key marker detected." >&2
  exit 1
fi

if find Sources Tests -type f \( -name '*.ttf' -o -name '*.otf' \) -print -quit | grep -q .; then
  echo "Bundled font detected. Add explicit license provenance before publication." >&2
  exit 1
fi

if rg -n 'URLSession|URLRequest|CLGeocoder|CLLocationManager|api\.openweathermap\.org|archive-api\.open-meteo\.com' Sources >/dev/null; then
  if ! rg -q 'Open-Meteo|OpenWeather|macOS location and geocoding' PRIVACY.md; then
    echo "PRIVACY.md must document current weather and location network behavior." >&2
    exit 1
  fi
fi

if rg -n -i 'Sentry|Firebase|Crashlytics|analytics|telemetry upload' Sources Package.swift >/dev/null; then
  if ! rg -q 'analytics|telemetry|crash-reporting' PRIVACY.md; then
    echo "PRIVACY.md must document analytics, telemetry, or crash-reporting behavior." >&2
    exit 1
  fi
fi

rg -q 'macOS Keychain' PRIVACY.md || {
  echo "PRIVACY.md must document credential storage." >&2
  exit 1
}

rg -q '@zijianwang90' .github/CODEOWNERS || {
  echo "CODEOWNERS must name the repository maintainer." >&2
  exit 1
}

rg -q 'package-ecosystem: "github-actions"' .github/dependabot.yml || {
  echo "Dependabot must monitor GitHub Actions." >&2
  exit 1
}

rg -q 'package-ecosystem: "swift"' .github/dependabot.yml || {
  echo "Dependabot must monitor Swift packages." >&2
  exit 1
}

echo "Open-source repository audit passed."

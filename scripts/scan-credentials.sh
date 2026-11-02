#!/usr/bin/env bash
# Scans the files that can ship for real provider credentials.
#
# Usage:
#   scripts/scan-credentials.sh              Scan the publication roots.
#   scripts/scan-credentials.sh --scan-file PATH
#   scripts/scan-credentials.sh --self-test
#
# Exits 0 when no credential is found, 1 when one is found, and 2 on a usage
# error. Findings name the file, line, and credential kind. Matches are
# redacted: the credential value itself is never printed.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)

# kind::pattern pairs. Keep the patterns as literals: the scan must not flag
# the `validToken` regex or the `access_token` parameter name that appear in
# the Mapbox client. The assignment pattern requires a quoted value so a
# variable reference such as `apiKey: openWeatherAPIKey` is not a finding.
credential_patterns=(
  'Mapbox public token::pk\.[A-Za-z0-9._-]{20,}'
  'Mapbox secret token::sk\.[A-Za-z0-9._-]{20,}'
  'AWS access key ID::AKIA[0-9A-Z]{16}'
  'GitHub token::gh[pousr]_[A-Za-z0-9]{20,}'
  'GitHub fine-grained token::github_pat_[A-Za-z0-9_]{20,}'
  'Slack token::xox[baprs]-[A-Za-z0-9-]{10,}'
  'PEM private key::-----BEGIN [A-Z ]*PRIVATE KEY-----'
  "credential assignment::(client_secret|CLIENT_SECRET|clientSecret|ClientSecret|api_key|API_KEY|apiKey|ApiKey|apikey|APIKEY)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9_./+=-]{16,}[\"']"
)

usage() {
  cat >&2 <<'EOF'
usage: scan-credentials.sh [--scan-file PATH | --self-test]

  (no arguments)      Scan tracked source and packaged plugin output.
  --scan-file PATH    Scan one file. Used by the audit self-test.
  --self-test         Verify a planted fake token fails and a clean file passes.
EOF
}

is_placeholder() {
  local value=$1
  case "$value" in
    *'$'*|*'{'*|*'}'*|*'<'*|*'>'*|*'%'*|*\**)
      return 0
      ;;
  esac
  local lowered
  lowered=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
  case "$lowered" in
    *your*|*example*|*placeholder*|*dummy*|*sample*|*changeme*|*redacted*|*xxxx*|*todo*|*notreal*)
      return 0
      ;;
  esac
  return 1
}

# scan_files PATH... prints one redacted finding per match and returns 1 when
# any credential was found.
scan_files() {
  local files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then
    return 0
  fi

  local failures=0
  local entry kind pattern hits hit path rest line value subject
  for entry in "${credential_patterns[@]}"; do
    kind=${entry%%::*}
    pattern=${entry#*::}
    hits=$(grep -I -H -n -o -E -- "$pattern" "${files[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then
      continue
    fi
    while IFS= read -r hit; do
      if [[ -z "$hit" ]]; then
        continue
      fi
      path=${hit%%:*}
      rest=${hit#*:}
      line=${rest%%:*}
      value=${rest#*:}

      # For an assignment, filter and redact the value, not the key name, so a
      # key such as OPENWEATHER_API_KEY cannot hide a real value.
      subject=$value
      case "$kind" in
        *assignment*)
          subject=${subject#*[:=]}
          case "$subject" in
            *\"*)
              subject=${subject#*\"}
              subject=${subject%%\"*}
              ;;
            *\'*)
              subject=${subject#*\'}
              subject=${subject%%\'*}
              ;;
          esac
          ;;
      esac

      if is_placeholder "$subject"; then
        continue
      fi
      failures=$((failures + 1))
      printf 'Credential detected (%s): %s:%s (redacted: %s...)\n' \
        "$kind" "$path" "$line" "${subject:0:4}" >&2
    done <<< "$hits"
  done

  if [[ $failures -gt 0 ]]; then
    return 1
  fi
  return 0
}

run_publication_scan() {
  local roots=()
  local path
  local files=()

  for path in Sources RunningOverlayResolve/src RunningOverlayResolve/workflow-plugin \
    RunningOverlayResolve/fusion scripts; do
    if [[ -d "$repo_root/$path" ]]; then
      roots+=("$repo_root/$path")
    fi
  done
  if [[ -f "$repo_root/Package.swift" ]]; then
    roots+=("$repo_root/Package.swift")
  fi
  while IFS= read -r -d '' path; do
    roots+=("$path")
  done < <(find "$repo_root" \
    \( -path "$repo_root/.git" -o -path "$repo_root/.build" -o -path "$repo_root/build" \) -prune -o \
    -name '*.entitlements' -print0)

  # Packaged output exists only after a build or assemble step. Scan it when
  # present so a token cannot reach a shipped bundle through build output.
  for path in RunningOverlayResolve/workflow-plugin/lib RunningOverlayResolve/dist build/AppStore; do
    if [[ -d "$repo_root/$path" ]]; then
      roots+=("$repo_root/$path")
    fi
  done

  # The scanner's own pattern literals and the audit script's exclusion are not
  # credentials. Exclude those two files explicitly rather than widening the
  # placeholder allowlist.
  while IFS= read -r -d '' path; do
    files+=("$path")
  done < <(find "${roots[@]}" -type f \
    ! -path "$repo_root/scripts/scan-credentials.sh" \
    ! -path "$repo_root/scripts/publication-audit.sh" -print0)

  scan_files "${files[@]}"
}

run_self_test() {
  local tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/running-overlay-credential-scan.XXXXXX")
  # Expand the path now: the local goes out of scope before the EXIT trap runs.
  trap "rm -rf '$tmp'" EXIT

  local clean="$tmp/clean.js"
  local planted="$tmp/planted.js"
  local status=0
  local output=""

  cat > "$clean" <<'EOF'
const mapboxToken = process.env.MAPBOX_TOKEN;
const apiKey = "YOUR_API_KEY_HERE";
const url = "https://example.com/?access_token=not-a-real-token";
EOF

  cat > "$planted" <<'EOF'
const mapboxToken = "pk.eyJ1IjoiY29kZXgtc2VsZi10ZXN0In0.abcdefghijklmnopqrstuvwxyz0123456789";
EOF

  if ! scan_files "$clean" >/dev/null 2>&1; then
    echo "Credential scan self-test failed: the clean file was flagged." >&2
    status=1
  fi

  if output=$(scan_files "$planted" 2>&1); then
    echo "Credential scan self-test failed: the planted Mapbox token was not detected." >&2
    status=1
  fi

  if [[ "$output" != *"Mapbox public token"* ]]; then
    echo "Credential scan self-test failed: the finding did not name the credential kind." >&2
    status=1
  fi

  if [[ "$output" == *"abcdefghijklmnopqrstuvwxyz0123456789"* ]]; then
    echo "Credential scan self-test failed: the credential value was printed." >&2
    status=1
  fi

  if [[ $status -ne 0 ]]; then
    return 1
  fi
  echo "Credential scan self-test passed."
}

case "${1:-}" in
  "")
    run_publication_scan
    ;;
  --scan-file)
    if [[ $# -ne 2 ]]; then
      usage
      exit 2
    fi
    if [[ ! -f "$2" ]]; then
      echo "scan-credentials: no such file: $2" >&2
      exit 2
    fi
    scan_files "$2"
    ;;
  --self-test)
    if [[ $# -ne 1 ]]; then
      usage
      exit 2
    fi
    run_self_test
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

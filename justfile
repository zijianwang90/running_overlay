set shell := ["bash", "-euo", "pipefail", "-c"]

build:
    swift build

run:
    swift run RunningOverlay

test:
    ./scripts/test.sh

test-one filter:
    ./scripts/test.sh "{{filter}}"

check:
    ./scripts/check.sh

visual-test:
    ./scripts/visual-test.sh

docs-check:
    ./scripts/check-doc-links.rb

update-snapshots:
    UPDATE_VISUAL_SNAPSHOTS=1 ./scripts/visual-test.sh

audit:
    ./scripts/open-source-audit.sh

#!/usr/bin/env python3
"""Decide whether a pull request needs the Skia product checks."""

import subprocess
import sys


def requires_skia(paths: list[str]) -> bool:
    """Only explicitly known non-runtime files can bypass product checks."""
    safe_files = {"AGENTS.md", ".github/CODEOWNERS", ".github/pull_request_template.md"}
    safe_prefixes = ("docs/", ".github/ISSUE_TEMPLATE/")
    return not paths or any(
        path not in safe_files and not path.startswith(safe_prefixes) for path in paths
    )


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("Usage: skia-ci-scope.py BASE_SHA HEAD_SHA")
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", "-z", "--no-renames", f"{sys.argv[1]}...{sys.argv[2]}"]
    )
    paths = [path.decode("utf-8", errors="surrogateescape") for path in changed.split(b"\0") if path]
    print("true" if requires_skia(paths) else "false")


if __name__ == "__main__":
    main()

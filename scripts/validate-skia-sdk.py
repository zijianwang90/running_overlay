#!/usr/bin/env python3
"""Validate the pinned product SDK identity, build recipe and binary digest."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys


def validate(sdk):
    scripts = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location("skia_builder", scripts / "build-skia-experimental.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    manifest = json.loads((sdk / "build-manifest.json").read_text())
    expected = {
        "skia_commit": builder.COMMIT,
        "platform": "macos-arm64",
        "gpu_backends": ["Ganesh Metal", "Graphite Metal"],
        "args_sha256": builder.digest(scripts / "skia/experimental-args.gn"),
        "builder_sha256": builder.digest(scripts / "build-skia-experimental.py"),
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            raise ValueError("Skia SDK does not match pinned " + key)
    binary = sdk / "lib/libskia.dylib"
    if manifest.get("binaries", {}).get("lib/libskia.dylib") != hashlib.sha256(binary.read_bytes()).hexdigest():
        raise ValueError("Skia SDK binary digest mismatch")
    for relative in ["LICENSE", "THIRD_PARTY_NOTICES.txt", "licenses/skcms-LICENSE", "include/core/SkCanvas.h"]:
        if not (sdk / relative).is_file():
            raise ValueError("Missing SDK file: " + relative)
    print("Pinned Skia SDK validation passed.", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate-skia-sdk.py SDK_DIRECTORY")
    validate(Path(sys.argv[1]))

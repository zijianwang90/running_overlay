#!/usr/bin/env python3
"""Build a pinned, opt-in macOS arm64 Ganesh + Graphite Metal SDK.

Artifacts stay outside the repository. This does not replace the shipping SDK
or publish anything. Requires Xcode command-line tools, git, curl and Python 3.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import zipfile


COMMIT = "1bbd9b972a4667a98fb16b8441444b2282fed0ac"
UPSTREAM = "https://skia.googlesource.com/skia.git"
TOOLS = {
    "gn": (
        "gn/gn/mac-arm64/+/git_revision:b2afae122eeb6ce09c52d63f67dc53fc517dbdc8",
        "cbb260f2cf999f7d74da96b3828a061299c6337354dd6db642e778828576025c",
        "bin/gn",
    ),
    "ninja": (
        "infra/3pp/tools/ninja/mac-arm64/+/version:2@1.12.1.chromium.4",
        "c5e9b4ffab3b2edefbc41849fc81f116c8d047b258906becc061be9ecaf04afd",
        "third_party/ninja/ninja",
    ),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture(*command, cwd=None):
    return subprocess.check_output(command, cwd=cwd, text=True).strip()


def run(*command, cwd=None):
    subprocess.run(command, cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Pinned checkout (created if absent)")
    parser.add_argument("--output", type=Path, required=True, help="New directory for SDK + tar.gz")
    parser.add_argument("--jobs", type=int, default=min(os.cpu_count() or 1, 8))
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("This experimental recipe supports macOS arm64 only")
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    source = args.source.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if output.exists():
        parser.error("--output must not exist; existing artifacts are never overwritten")
    if source == output or source in output.parents or output in source.parents:
        parser.error("--source and --output must be separate directory trees")
    recipe = Path(__file__).resolve().parent / "skia/experimental-args.gn"
    if not source.exists():
        source.mkdir(parents=True)
        run("git", "init", str(source))
        run("git", "remote", "add", "origin", UPSTREAM, cwd=source)
        run("git", "fetch", "--depth", "1", "origin", COMMIT, cwd=source)
        run("git", "checkout", "--detach", "FETCH_HEAD", cwd=source)
    if capture("git", "rev-parse", "HEAD", cwd=source) != COMMIT:
        parser.error("Source checkout does not match the pinned commit")
    run("git", "diff", "--exit-code", "HEAD", cwd=source)

    # Use curl's platform trust store. Do not disable TLS verification to work
    # around Python installations with an incomplete certificate store.
    with tempfile.TemporaryDirectory(prefix="running-overlay-skia-tools-") as temporary:
        for name, (url, expected, relative) in TOOLS.items():
            archive = Path(temporary) / (name + ".zip")
            run("curl", "-fL", "--retry", "2", "--max-time", "120",
                "https://chrome-infra-packages.appspot.com/dl/" + url, "-o", str(archive))
            if digest(archive) != expected:
                raise RuntimeError("Checksum mismatch for pinned tool: " + name)
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(archive) as contents:
                target.write_bytes(contents.read(name))
            target.chmod(0o755)

    build = source / "out/RunningOverlay"
    build.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(recipe, build / "args.gn")
    run(str(source / "bin/gn"), "gen", str(build), cwd=source)
    run(str(source / "third_party/ninja/ninja"), "-C", str(build), "-j", str(args.jobs), "skia")

    output.mkdir(parents=True)
    package = output / ("skia-m159-" + COMMIT[:12] + "-metal-arm64-experimental")
    package.mkdir()
    # Public Skia headers reference private headers and skcms. Include those
    # trees without copying a checkout's git data or build outputs.
    for directory in ["include", "src", "modules/skcms"]:
        shutil.copytree(source / directory, package / directory,
                        ignore=shutil.ignore_patterns(".git", "__pycache__"))
    (package / "lib").mkdir()
    shutil.copyfile(build / "libskia.dylib", package / "lib/libskia.dylib")
    shutil.copyfile(source / "LICENSE", package / "LICENSE")
    shutil.copyfile(recipe, package / "args.gn")
    (package / "licenses").mkdir()
    shutil.copyfile(source / "modules/skcms/LICENSE", package / "licenses/skcms-LICENSE")
    (package / "THIRD_PARTY_NOTICES.txt").write_text(
        "Skia: BSD-3-Clause; see LICENSE.\n"
        "skcms: BSD-3-Clause; see licenses/skcms-LICENSE.\n"
        "No external codec, HarfBuzz, ICU, Dawn, or PartitionAlloc libraries are bundled.\n"
        "Experimental SDK only; app bundling, signing and release approval are separate.\n"
    )
    binary = package / "lib/libskia.dylib"
    manifest = {
        "schema_version": 1,
        "experimental": True,
        "upstream": UPSTREAM,
        "skia_commit": COMMIT,
        "milestone": 159,
        "gpu_backends": ["Ganesh Metal", "Graphite Metal"],
        "platform": "macos-arm64",
        "skcms_revision": (source / "modules/skcms/version.sha1").read_text().strip(),
        "args_sha256": digest(recipe),
        "builder_sha256": digest(Path(__file__).resolve()),
        "binaries": {"lib/libskia.dylib": digest(binary)},
        "tools": {name: {"package": value[0], "archive_sha256": value[1]} for name, value in TOOLS.items()},
        "toolchain": {
            "compiler": capture("xcrun", "clang++", "--version"),
            "sdk": capture("xcrun", "--show-sdk-version"),
            "xcode": capture("xcodebuild", "-version"),
            "gn": capture(str(source / "bin/gn"), "--version"),
            "ninja": capture(str(source / "third_party/ninja/ninja"), "--version"),
        },
        "dynamic_dependencies": capture("otool", "-L", str(binary)).splitlines()[1:],
    }
    (package / "build-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    archive = output / (package.name + ".tar.gz")
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(package, arcname=package.name)
    (output / "SHA256SUMS").write_text(digest(archive) + "  " + archive.name + "\n")
    print("Experimental SDK:", package)
    print("Archive:", archive)


if __name__ == "__main__":
    main()

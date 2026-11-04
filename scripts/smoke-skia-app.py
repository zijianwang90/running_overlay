#!/usr/bin/env python3
"""Smoke-export every built-in template from a sandboxed copy of a Skia app."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


def run(*command, **kwargs):
    subprocess.run(command, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    run("python3", str(root / "scripts/validate-packaged-skia.py"), str(args.app))
    # Never inject fixtures into or re-sign the distributable artifact itself.
    with tempfile.TemporaryDirectory(prefix="skia-bundle-smoke-", dir="/private/tmp") as temporary:
        app = Path(temporary) / "RunningOverlay.app"
        shutil.copytree(args.app, app)
        fixtures = app / "Contents/Resources/BundleSmoke"
        fixtures.mkdir()
        shutil.copy2(root / "Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.fit", fixtures)
        templates = sorted((root / "Sources/RunningOverlay/Resources/Templates").glob("*.rotemplate"))
        if not templates:
            raise RuntimeError("No built-in templates found")
        for template in templates:
            shutil.copy2(template, fixtures)
        destination = Path(temporary) / "exports"
        destination.mkdir()
        with (root / "AppStore/RunningOverlay.entitlements").open("rb") as stream:
            entitlements = plistlib.load(stream)
        # Headless tests have no Powerbox grant. Only the disposable copy gets
        # a narrowly scoped output grant, so the harness can verify/clean MOVs
        # without macOS container privacy blocking its read access.
        entitlements["com.apple.security.temporary-exception.files.absolute-path.read-write"] = [str(destination) + "/"]
        entitlement_path = Path(temporary) / "smoke.entitlements"
        entitlement_path.write_bytes(plistlib.dumps(entitlements))
        run("codesign", "--force", "--options", "0", "--sign", "-", str(app / "Contents/Frameworks/libskia.dylib"))
        run("codesign", "--force", "--deep", "--options", "0", "--entitlements",
            str(entitlement_path), "--sign", "-", str(app))
        run("codesign", "--verify", "--deep", "--strict", str(app))
        try:
            for template in templates:
                output = destination / template.stem
                run(str(app / "Contents/MacOS/RunningOverlay"), "--benchmark-template-segments",
                    str(fixtures / "synthetic-run.fit"), "--template", str(fixtures / template.name),
                    "--segments", "1", "--segment-duration", "1", "--codec", "proRes4444",
                    "--benchmark-output", str(output),
                    env=dict(os.environ, RUNNING_OVERLAY_RENDERER="swiftUI"), timeout=120)
                movies = list(output.rglob("*.mov"))
                if len(movies) != 1 or movies[0].stat().st_size == 0:
                    raise RuntimeError("Missing smoke export for " + template.stem)
                print("Sandboxed template export passed: " + template.stem, flush=True)
        finally:
            if destination.exists():
                shutil.rmtree(destination)


if __name__ == "__main__":
    main()

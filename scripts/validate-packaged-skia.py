#!/usr/bin/env python3
"""Verify a Skia app bundle has no external SDK dependency before signing it."""

from pathlib import Path
import re
import subprocess
import sys


def output(*command):
    return subprocess.check_output(command, text=True)


def validate(app):
    executable = app / "Contents/MacOS/RunningOverlay"
    library = app / "Contents/Frameworks/libskia.dylib"
    if not library.is_file():
        raise ValueError("Missing bundled Skia dylib")
    dependencies = output("otool", "-L", str(executable)).splitlines()[1:]
    skia_links = [line.strip().split(" (", 1)[0] for line in dependencies if "libskia" in line]
    if skia_links != ["@rpath/libskia.dylib"]:
        raise ValueError("Executable must link @rpath/libskia.dylib")
    commands = output("otool", "-l", str(executable))
    rpaths = re.findall(r"cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset", commands)
    if "@executable_path/../Frameworks" not in rpaths:
        raise ValueError("Missing bundle-relative Frameworks rpath")
    if any(path.startswith("/") and path != "/usr/lib/swift" for path in rpaths):
        raise ValueError("Executable has an absolute development rpath")
    for line in output("otool", "-L", str(library)).splitlines()[1:]:
        dependency = line.strip().split(" (", 1)[0]
        if dependency != "@rpath/libskia.dylib" and not dependency.startswith(("/System/Library/", "/usr/lib/")):
            raise ValueError("Skia has a non-system dependency: " + dependency)
    app_archs = set(output("lipo", "-archs", str(executable)).split())
    sdk_archs = set(output("lipo", "-archs", str(library)).split())
    if not app_archs <= sdk_archs:
        raise ValueError("Bundled Skia is missing an application architecture")
    for notice in ["LICENSE", "THIRD_PARTY_NOTICES.md", "Skia/LICENSE", "Skia/THIRD_PARTY_NOTICES.txt", "Skia/skcms-LICENSE"]:
        if not (app / "Contents/Resources/Legal" / notice).is_file():
            raise ValueError("Missing legal notice: " + notice)
    print("Packaged Skia dependency validation passed.", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate-packaged-skia.py APP")
    validate(Path(sys.argv[1]))

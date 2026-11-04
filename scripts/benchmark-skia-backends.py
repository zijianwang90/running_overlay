#!/usr/bin/env python3
"""Compare pinned m152 Ganesh, candidate Ganesh, and candidate Graphite serially.

Builds the same Release app source against both SDKs, then uses synthetic FIT
and the bundled Easy Run template through the production export entry point.
The output directory must be new and stays outside the repository.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import time


ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--segments", type=int, default=5)
    parser.add_argument("--duration", type=int, default=5)
    args = parser.parse_args()
    if min(args.repeats, args.segments, args.duration) < 1:
        parser.error("repeats, segments and duration must be positive")
    output = args.output.expanduser().resolve()
    if output.exists():
        parser.error("--output must not exist")
    if output == ROOT or ROOT in output.parents:
        parser.error("Keep generated media outside the repository")
    for sdk in [args.baseline, args.candidate]:
        if not (sdk / "lib/libskia.dylib").is_file():
            parser.error("SDK is missing lib/libskia.dylib: " + str(sdk))
    baseline_manifest = json.loads((args.baseline / "build-manifest.json").read_text())
    candidate_manifest = json.loads((args.candidate / "build-manifest.json").read_text())
    if baseline_manifest.get("skia_commit") != "0873ec164a06966b90ae0d43ef783cfb180084ae":
        parser.error("Baseline SDK must be the pinned m152 package")
    if candidate_manifest.get("skia_commit") != "1bbd9b972a4667a98fb16b8441444b2282fed0ac":
        parser.error("Candidate SDK must be the pinned m159 experimental package")
    application_hash = hashlib.sha256()
    for path in [ROOT / "Package.swift"] + sorted(p for p in (ROOT / "Sources").rglob("*") if p.is_file()):
        application_hash.update(str(path.relative_to(ROOT)).encode())
        application_hash.update(b"\0")
        application_hash.update(path.read_bytes())
        application_hash.update(b"\0")
    dirty = bool(subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=all", "--", "Sources", "Package.swift"], cwd=ROOT
    ))
    output.mkdir(parents=True)
    variants = []
    for label, sdk, graphite in [
        ("m152-ganesh", args.baseline.resolve(), False),
        ("m159", args.candidate.resolve(), True),
    ]:
        env = dict(os.environ, SKIA_DIR=str(sdk), SKIA_GPU="1")
        env.pop("SKIA_GRAPHITE", None)
        env.pop("RUNNING_OVERLAY_SKIA_BACKEND", None)
        env.pop("RUNNING_OVERLAY_RENDERER", None)
        if graphite:
            env["SKIA_GRAPHITE"] = "1"
        with (output / (label + "-build.log")).open("w") as log:
            subprocess.run(["swift", "build", "-c", "release"], cwd=ROOT, env=env,
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        bin_path = Path(subprocess.check_output(
            ["swift", "build", "-c", "release", "--show-bin-path"], cwd=ROOT, env=env, text=True
        ).strip())
        binary_dir = output / label
        binary_dir.mkdir()
        binary = binary_dir / "RunningOverlay"
        shutil.copy2(bin_path / "RunningOverlay", binary)
        for bundle in bin_path.glob("*.bundle"):
            shutil.copytree(bundle, binary_dir / bundle.name)
        if graphite:
            variants += [("m159-ganesh", binary, "ganesh"), ("m159-graphite", binary, "graphite")]
        else:
            variants += [(label, binary, "ganesh")]

    template = json.loads((ROOT / "Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate").read_text())
    records = []
    metrics = ["totalDuration", "imageRenderDuration", "writerWaitDuration", "processSeconds"]

    def export(variant, template_path, codec, directory, warmup=False):
        label, binary, backend = variant
        env = dict(os.environ, RUNNING_OVERLAY_RENDERER="skia", RUNNING_OVERLAY_SKIA_BACKEND=backend)
        command = [str(binary), "--benchmark-template-segments",
                   str(ROOT / "Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.fit"),
                   "--template", str(template_path), "--segments", str(1 if warmup else args.segments),
                   "--segment-duration", str(1 if warmup else args.duration), "--codec", codec,
                   "--benchmark-output", str(directory)]
        started = time.monotonic()
        with directory.with_suffix(".log").open("w") as log:
            subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        elapsed = time.monotonic() - started
        profile_path, = directory.glob("export_profile_*.json")
        profile = json.loads(profile_path.read_text())
        if profile["renderPath"] != "skiaMetal" or profile["buildConfiguration"] != "release":
            raise RuntimeError("Unexpected rendering/build path in " + str(profile_path))
        if not warmup:
            expected_frames = args.segments * args.duration * 30
            expected_renders = args.segments * args.duration * 5
            if profile["totalFrameCount"] != expected_frames or profile["renderedFrameCount"] != expected_renders:
                raise RuntimeError("Unexpected frame/sample count in " + str(profile_path))
        return {key: profile[key] for key in metrics if key != "processSeconds"} | {
            "processSeconds": elapsed, "totalFrameCount": profile["totalFrameCount"],
            "renderedFrameCount": profile["renderedFrameCount"], "backend": label,
        }

    for width, height in [(1920, 1080), (3840, 2160)]:
        template["referenceResolution"] = {"width": width, "height": height}
        template_path = output / (str(height) + "p.rotemplate")
        template_path.write_text(json.dumps(template))
        for codec in ["proRes4444", "hevcWithAlpha"]:
            case = str(height) + "p-" + codec
            for variant in variants:
                export(variant, template_path, codec, output / (case + "-" + variant[0] + "-warmup"), True)
            for repeat in range(args.repeats):
                # Rotate order to reduce a systematic thermal/cache advantage.
                order = variants[repeat % len(variants):] + variants[:repeat % len(variants)]
                for variant in order:
                    record = export(variant, template_path, codec,
                                    output / (case + "-" + variant[0] + "-" + str(repeat + 1)))
                    record |= {"case": case, "repeat": repeat + 1}
                    records.append(record)
                    (output / "runs.json").write_text(json.dumps(records, indent=2) + "\n")
                    print(case, variant[0], repeat + 1, round(record["totalDuration"], 3), flush=True)
    medians = []
    for case in sorted({r["case"] for r in records}):
        for variant in variants:
            rows = [r for r in records if r["case"] == case and r["backend"] == variant[0]]
            medians.append({"case": case, "backend": variant[0]} | {
                key: statistics.median(row[key] for row in rows) for key in metrics
            })
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    summary = {
        "method": "Release; synthetic FIT + Easy Run; fresh process per run; one short warmup per case/backend; rotated serial trials",
        "repeats": args.repeats, "segments": args.segments, "duration": args.duration,
        "frameRate": 30, "layerDataFrameRate": 5,
        "hardware": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
        "os": subprocess.check_output(["sw_vers", "-productVersion"], text=True).strip(),
        "sdks": {"baseline": digest(args.baseline / "lib/libskia.dylib"),
                 "candidate": digest(args.candidate / "lib/libskia.dylib")},
        "binary_sha256": {name: digest(binary) for name, binary, _ in variants},
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "application_tree_sha256": application_hash.hexdigest(),
        "source_state": "modified working tree" if dirty else "clean committed tree",
        "medians": medians,
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print("Summary:", output / "summary.json")


if __name__ == "__main__":
    main()

"""Synthetic SDK manifests exercise product dependency rejection without Skia."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load("sdk_validator", "validate-skia-sdk.py")
builder = load("sdk_builder", "build-skia-experimental.py")


class SDKValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.sdk = Path(self.temporary.name)
        for relative in ["lib/libskia.dylib", "LICENSE", "THIRD_PARTY_NOTICES.txt",
                         "licenses/skcms-LICENSE", "include/core/SkCanvas.h"]:
            target = self.sdk / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("synthetic validation fixture\n")
        self.manifest = {
            "skia_commit": builder.COMMIT,
            "platform": "macos-arm64",
            "gpu_backends": ["Ganesh Metal", "Graphite Metal"],
            "args_sha256": builder.digest(SCRIPTS / "skia/experimental-args.gn"),
            "builder_sha256": builder.digest(SCRIPTS / "build-skia-experimental.py"),
            "binaries": {"lib/libskia.dylib": builder.digest(self.sdk / "lib/libskia.dylib")},
        }
        self.save()

    def save(self):
        (self.sdk / "build-manifest.json").write_text(json.dumps(self.manifest))

    def test_accepts_matching_package(self):
        validator.validate(self.sdk)

    def test_rejects_wrong_identity_or_recipe(self):
        for key in ["skia_commit", "platform", "gpu_backends", "args_sha256", "builder_sha256"]:
            with self.subTest(key=key):
                original = self.manifest[key]
                self.manifest[key] = "incorrect"
                self.save()
                with self.assertRaisesRegex(ValueError, key):
                    validator.validate(self.sdk)
                self.manifest[key] = original

    def test_rejects_modified_binary(self):
        (self.sdk / "lib/libskia.dylib").write_text("modified")
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            validator.validate(self.sdk)

    def test_rejects_missing_notice(self):
        (self.sdk / "licenses/skcms-LICENSE").unlink()
        with self.assertRaisesRegex(ValueError, "Missing SDK file"):
            validator.validate(self.sdk)


if __name__ == "__main__":
    unittest.main()

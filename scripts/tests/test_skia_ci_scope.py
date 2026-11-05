import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("skia_ci_scope", Path(__file__).parents[1] / "skia-ci-scope.py")
scope = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scope)


class SkiaCIScopeTests(unittest.TestCase):
    def test_only_known_non_runtime_files_skip(self):
        self.assertFalse(scope.requires_skia(["docs/testing.md", "AGENTS.md", ".github/ISSUE_TEMPLATE/bug_report.yml"]))

    def test_runtime_unknown_and_mixed_changes_run(self):
        for paths in ([], ["Sources/RunningOverlay/UI/MainEditorView.swift"],
                      ["scripts/check.sh"], [".github/workflows/ci.yml"],
                      ["docs/testing.md", "Package.swift"], ["new-directory/file"]):
            with self.subTest(paths=paths):
                self.assertTrue(scope.requires_skia(paths))


if __name__ == "__main__":
    unittest.main()

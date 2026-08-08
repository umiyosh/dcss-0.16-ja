import json
import unittest
from pathlib import Path

from classify_ci_changes import classify


MATRIX_PATH = Path(__file__).parents[1] / "ci-matrices.json"


class ClassifyChangesTest(unittest.TestCase):
    def test_documentation_only(self):
        self.assertEqual(
            "docs",
            classify(
                [
                    "AGENTS.md",
                    "crawl-ref/docs/crawl_manual.reST",
                    "crawl-ref/settings/init.txt",
                ]
            ),
        )

    def test_runtime_data_only(self):
        self.assertEqual(
            "data",
            classify(
                [
                    "crawl-ref/source/dat/database/ja/jtrans.txt",
                    "crawl-ref/source/dat/des/branches/zot.des",
                ]
            ),
        )

    def test_runtime_data_with_documentation(self):
        self.assertEqual(
            "data",
            classify(
                [
                    "crawl-ref/docs/crawl_manual.reST",
                    "crawl-ref/source/dat/clua/autofight.lua",
                ]
            ),
        )

    def test_source_code_requires_full_matrix(self):
        self.assertEqual("full", classify(["crawl-ref/source/player.cc"]))

    def test_workflow_change_requires_full_matrix(self):
        self.assertEqual("full", classify([".github/workflows/ci.yml"]))

    def test_unknown_path_requires_full_matrix(self):
        self.assertEqual("full", classify(["new-directory/config.txt"]))

    def test_no_paths_requires_full_matrix(self):
        self.assertEqual("full", classify([]))


class CiMatrixTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrices = json.loads(MATRIX_PATH.read_text())

    def test_full_matrix_keeps_all_compilers_and_variants(self):
        matrix = self.matrices["full"]
        self.assertEqual({"GCC", "Clang"}, self._names(matrix, "compiler"))
        self.assertEqual(
            {
                "Console",
                "Console (debug)",
                "Tiles",
                "Tiles (debug)",
                "Webtiles",
                "Webtiles (debug)",
                "DGL",
                "DGL Webtiles",
                "Tiles (bundled dependencies)",
                "Webtiles (bundled dependencies)",
            },
            self._names(matrix, "variant"),
        )

    def test_pr_matrix_has_fourteen_unique_builds(self):
        builds = self.matrices["pr"]["include"]
        full_matrix = self.matrices["full"]
        pairs = {
            (build["compiler"]["name"], build["variant"]["name"])
            for build in builds
        }
        self.assertEqual(14, len(builds))
        self.assertEqual(14, len(pairs))
        for build in builds:
            self.assertIn(build["compiler"], full_matrix["compiler"])
            self.assertIn(build["variant"], full_matrix["variant"])

    def test_pr_matrix_runs_every_variant_with_gcc(self):
        builds = self.matrices["pr"]["include"]
        gcc_variants = {
            build["variant"]["name"]
            for build in builds
            if build["compiler"]["name"] == "GCC"
        }
        self.assertEqual(
            self._names(self.matrices["full"], "variant"), gcc_variants
        )

    def test_pr_matrix_runs_representative_variants_with_clang(self):
        builds = self.matrices["pr"]["include"]
        clang_variants = {
            build["variant"]["name"]
            for build in builds
            if build["compiler"]["name"] == "Clang"
        }
        self.assertEqual(
            {
                "Console (debug)",
                "Tiles (debug)",
                "DGL Webtiles",
                "Webtiles (bundled dependencies)",
            },
            clang_variants,
        )

    def test_pr_matrix_tests_only_representative_console_builds(self):
        tested_builds = {
            (build["compiler"]["name"], build["variant"]["name"])
            for build in self.matrices["pr"]["include"]
            if build["variant"]["test"]
        }
        self.assertEqual(
            {
                ("GCC", "Console"),
                ("GCC", "Console (debug)"),
                ("Clang", "Console (debug)"),
            },
            tested_builds,
        )

    def test_every_variant_declares_a_valid_test_mode(self):
        for matrix_name in ("full", "data"):
            for variant in self.matrices[matrix_name]["variant"]:
                self.assertIn(variant["test"], {"", "debug", "nondebug"})
        for build in self.matrices["pr"]["include"]:
            self.assertIn(
                build["variant"]["test"], {"", "debug", "nondebug"}
            )

    def test_data_matrix_uses_one_debug_console_build(self):
        matrix = self.matrices["data"]
        self.assertEqual({"GCC"}, self._names(matrix, "compiler"))
        self.assertEqual(
            {"Console (debug)"}, self._names(matrix, "variant")
        )

    @staticmethod
    def _names(matrix, axis):
        return {entry["name"] for entry in matrix[axis]}


if __name__ == "__main__":
    unittest.main()

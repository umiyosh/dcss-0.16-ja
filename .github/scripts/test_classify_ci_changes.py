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

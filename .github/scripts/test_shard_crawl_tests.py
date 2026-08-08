import json
import tempfile
import unittest
from pathlib import Path

from shard_crawl_tests import build_selection, load_durations, shard_tests


class ShardTestsTest(unittest.TestCase):
    def test_shards_cover_each_test_once_and_balance_durations(self):
        listed = [
            "builtin-a",
            "builtin-b",
            "lua-slow",
            "lua-medium",
            "lua-small-a",
            "lua-small-b",
        ]
        script_tests = {
            "lua-slow",
            "lua-medium",
            "lua-small-a",
            "lua-small-b",
        }
        durations = {
            "builtin-a": 1,
            "builtin-b": 1,
            "lua-slow": 10,
            "lua-medium": 6,
            "lua-small-a": 4,
            "lua-small-b": 4,
        }

        shards = shard_tests(listed, script_tests, 3, durations)

        self.assertEqual(set(listed), set().union(*map(set, shards)))
        self.assertEqual(len(listed), sum(map(len, shards)))
        self.assertEqual(
            [
                ["lua-slow"],
                ["lua-medium", "builtin-a", "builtin-b"],
                ["lua-small-a", "lua-small-b"],
            ],
            shards,
        )

    def test_keeps_builtin_tests_in_one_shard(self):
        listed = ["builtin-a", "builtin-b", "lua-a"]

        shards = shard_tests(
            listed,
            {"lua-a"},
            2,
            {"builtin-a": 5, "builtin-b": 4, "lua-a": 8},
        )

        builtin_shards = [shard for shard in shards if "builtin-a" in shard]
        self.assertEqual(1, len(builtin_shards))
        self.assertIn("builtin-b", builtin_shards[0])

    def test_uses_median_duration_for_unknown_tests(self):
        shards = shard_tests(
            ["lua-known", "lua-unknown", "lua-small"],
            {"lua-known", "lua-unknown", "lua-small"},
            2,
            {"lua-known": 10, "lua-small": 2},
        )

        self.assertEqual(
            [["lua-known"], ["lua-unknown", "lua-small"]], shards
        )

    def test_first_selection_groups_builtin_tests_for_crawl(self):
        shard = ["builtin-a", "builtin-b", "lua-a"]

        selection = build_selection(shard, {"lua-a"})

        self.assertEqual("builtin-a builtin-b,lua-a", selection)

    def test_script_only_selection_keeps_comma_separated_names(self):
        selection = build_selection(
            ["lua-a", "lua-b"], {"lua-a", "lua-b"}
        )

        self.assertEqual("lua-a,lua-b", selection)

    def test_rejects_invalid_shard_count(self):
        with self.assertRaisesRegex(ValueError, "shard count"):
            shard_tests(["lua-a"], {"lua-a"}, 0, {"lua-a": 1})

    def test_excludes_big_tests_like_the_default_crawl_suite(self):
        shards = shard_tests(
            ["builtin-a", "lua-a", "big/slow"],
            {"lua-a", "big/slow"},
            2,
            {"builtin-a": 1, "lua-a": 1, "big/slow": 100},
        )

        self.assertNotIn("big/slow", set().union(*map(set, shards)))


class LoadDurationsTest(unittest.TestCase):
    def _write_durations(self, durations) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "durations.json"
        path.write_text(json.dumps(durations), encoding="utf-8")
        return path

    def test_loads_positive_numeric_durations(self):
        path = self._write_durations({"lua-a": 12, "lua-b": 3.5})

        self.assertEqual(
            {"lua-a": 12, "lua-b": 3.5}, load_durations(path)
        )

    def test_rejects_non_positive_duration(self):
        path = self._write_durations({"lua-a": 0})

        with self.assertRaisesRegex(ValueError, "positive numbers"):
            load_durations(path)


if __name__ == "__main__":
    unittest.main()

import unittest

from shard_crawl_tests import build_selection, shard_tests


class ShardTestsTest(unittest.TestCase):
    def test_shards_cover_each_test_once_and_balance_counts(self):
        listed = [
            "builtin-a",
            "builtin-b",
            "lua-a",
            "lua-b",
            "lua-c",
            "lua-d",
        ]
        script_tests = {"lua-a", "lua-b", "lua-c", "lua-d"}

        shards = shard_tests(listed, script_tests, 2)

        self.assertEqual(set(listed), set().union(*map(set, shards)))
        self.assertEqual(len(listed), sum(map(len, shards)))
        self.assertLessEqual(abs(len(shards[0]) - len(shards[1])), 1)

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
            shard_tests(["lua-a"], {"lua-a"}, 0)

    def test_excludes_big_tests_like_the_default_crawl_suite(self):
        shards = shard_tests(
            ["builtin-a", "lua-a", "big/slow"],
            {"lua-a", "big/slow"},
            2,
        )

        self.assertNotIn("big/slow", set().union(*map(set, shards)))


if __name__ == "__main__":
    unittest.main()

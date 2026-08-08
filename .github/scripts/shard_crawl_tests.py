#!/usr/bin/env python3

import argparse
import subprocess
from pathlib import Path


def shard_tests(
    listed_tests: list[str], script_tests: set[str], shard_count: int
) -> list[list[str]]:
    if shard_count < 1:
        raise ValueError("shard count must be positive")
    # An unfiltered `crawl -test` skips test/big/. Listing tests does not, so
    # retain the default suite boundary when converting the list to shards.
    listed_tests = [
        test for test in listed_tests if not test.startswith("big/")
    ]
    if len(listed_tests) != len(set(listed_tests)):
        raise ValueError("listed tests must be unique")

    builtins = sorted(set(listed_tests) - script_tests)
    scripts = sorted(set(listed_tests) & script_tests)
    shards = [[] for _ in range(shard_count)]
    shards[0].extend(builtins)

    for script in scripts:
        target = min(range(shard_count), key=lambda index: len(shards[index]))
        shards[target].append(script)
    return shards


def build_selection(shard: list[str], script_tests: set[str]) -> str:
    builtins = [test for test in shard if test not in script_tests]
    scripts = [test for test in shard if test in script_tests]
    parts = []
    if builtins:
        # DCSS 0.16 checks built-in C++ tests against only the first selected
        # phrase. Grouping their names keeps every selected built-in visible
        # to that legacy substring check.
        parts.append(" ".join(builtins))
    parts.extend(scripts)
    if not parts:
        raise ValueError("test shard must not be empty")
    return ",".join(parts)


def discover_script_tests(test_dir: Path) -> set[str]:
    return {
        path.relative_to(test_dir).with_suffix("").as_posix()
        for pattern in ("*.lua", "*.clua")
        for path in test_dir.rglob(pattern)
    }


def list_tests(binary: str) -> list[str]:
    result = subprocess.run(
        [binary, "-test", "list"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", default="./crawl")
    parser.add_argument("--test-dir", type=Path, default=Path("test"))
    parser.add_argument("--shard-index", type=int, required=True)
    parser.add_argument("--shard-count", type=int, required=True)
    parser.add_argument("--runner")
    args = parser.parse_args()

    script_tests = discover_script_tests(args.test_dir)
    shards = shard_tests(
        list_tests(args.binary), script_tests, args.shard_count
    )
    if not 0 <= args.shard_index < len(shards):
        raise ValueError("shard index is out of range")
    shard = shards[args.shard_index]
    selection = build_selection(shard, script_tests)
    print(f"Running test shard {args.shard_index + 1}/{args.shard_count}")
    print(selection)

    command = [args.binary, "-test", selection]
    if args.runner:
        command.insert(0, args.runner)
    subprocess.run(command, check=True)


if __name__ == "__main__":
    main()

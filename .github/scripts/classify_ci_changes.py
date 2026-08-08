#!/usr/bin/env python3

import argparse
import os
import sys
from collections.abc import Iterable


DOC_FILES = {
    "AGENTS.md",
    "CLAUDE.md",
    "README.md",
    "crawl-ref/README.txt",
}
DOC_DIRECTORIES = (
    "crawl-ref/docs/",
    "crawl-ref/settings/",
)
DATA_DIRECTORY = "crawl-ref/source/dat/"


def _is_documentation(path: str) -> bool:
    return path in DOC_FILES or path.startswith(DOC_DIRECTORIES)


def _is_runtime_data(path: str) -> bool:
    return path.startswith(DATA_DIRECTORY)


def classify(paths: Iterable[str]) -> str:
    changed_paths = tuple(path for path in paths if path)
    if not changed_paths:
        return "full"
    if all(_is_documentation(path) for path in changed_paths):
        return "docs"
    if all(
        _is_documentation(path) or _is_runtime_data(path)
        for path in changed_paths
    ):
        return "data"
    return "full"


def _read_paths(null_terminated: bool) -> list[str]:
    separator = b"\0" if null_terminated else b"\n"
    return [
        os.fsdecode(path)
        for path in sys.stdin.buffer.read().split(separator)
        if path
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--null",
        action="store_true",
        help="Read NUL-terminated paths from standard input.",
    )
    args = parser.parse_args()
    print(classify(_read_paths(args.null)))


if __name__ == "__main__":
    main()

# Repository Guidelines

## Project Structure & Module Organization

The project lives under `crawl-ref/`. Core C++ gameplay code and the main
`Makefile` are in `crawl-ref/source/`; related features are grouped by filename
(for example, `mon-*.cc` for monsters and `spl-*.cc` for spells). Runtime data
is under `source/dat/`, Lua tests under `source/test/`, player configuration
examples under `crawl-ref/settings/`, and user/developer documentation under
`crawl-ref/docs/`. Platform packaging lives in `source/mac/`,
`source/android-project/`, `source/MSVC/`, and `source/util/`. Tile artwork and
generation tools are in `source/rltiles/`.

## Build, Test, and Development Commands

- `git submodule update --init --recursive`: fetch bundled third-party
  dependencies when system libraries are unavailable.
- `make -C crawl-ref/source -j2`: build the console executable.
- `make -C crawl-ref/source TILES=y -j2`: build the graphical Tiles variant.
- `make -C crawl-ref/source debug -j2`: build with diagnostic test support.
- `make -C crawl-ref/source test`: run the debug test and stress suites.
- `make -C crawl-ref/source nondebugtest`: run tests against a normal build.

Run `./crawl` with `crawl-ref/source/` as the working directory so `dat/` and
`docs/` can be found. See `crawl-ref/INSTALL.txt` for platform dependencies.

## Coding Style & Naming Conventions

Follow `crawl-ref/docs/develop/coding_conventions.txt`: use four spaces, never
tabs, and keep lines near 80 columns. Put braces on their own lines. Prefer
`snake_case` for functions and variables, prefix internal functions with `_`,
members with `m_`, and static members with `sm_`. Match nearby code when older
files differ. Run `crawl-ref/source/util/checkwhite` on changed source files
before committing.

## Testing Guidelines

Each `crawl-ref/source/test/*.lua` file is an independent unit test. Use
descriptive lowercase names such as `monster-name.lua`; run a subset with
`./crawl -test monster-name` after a debug build. Add focused regression tests
for gameplay and translation changes. CI builds Console, Tiles, WebTiles, and
DGL variants with both GCC and Clang.

## Commit & Pull Request Guidelines

Recent history uses focused Conventional Commit subjects such as
`fix(build): ...`, `ci: ...`, and `test: ...`; follow that pattern with an
imperative English summary. Keep generated files and build artifacts out of
commits. Pull requests should explain the reason, summarize the change, list
commands run, link relevant issues, and call out untested platforms. Include
screenshots only for visible Tiles or UI changes, and wait for all GitHub
Actions jobs to pass.

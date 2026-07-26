#!/bin/bash
#
# Build the macOS tiles dependencies from upstream sources.
#
# Usage: ARCH=<triple> build-macos-deps.sh <lib>...
#   ARCH        install subdirectory, e.g. arm64-apple-darwin24.6.0 (required)
#   PREFIX      install root, relative to this directory (default: install)
#   DEPLOY_MIN  oldest macOS to support (default: 11.0)
#
# The submodules under contrib/ are 2014 snapshots living in repositories this
# fork cannot push to, and they no longer compile. Homebrew is not a
# substitute: its bottles are built for the exact macOS of the build machine,
# so a bundle carrying them only runs on that macOS or newer. Building here
# pins both the versions and the deployment target, which is what lets one
# artifact run on every Apple Silicon Mac.
#
# Everything is static, so nothing lands in the app bundle's Frameworks and
# there is nothing to relocate or re-sign.

set -euo pipefail

cd "$(dirname "$0")"

ARCH=${ARCH:?ARCH must be set}
PREFIX=${PREFIX:-install}
# The main makefile exports MACOSX_DEPLOYMENT_TARGET, so a plain `make`
# already agrees with whatever it chose; DEPLOY_MIN is for running this
# script by hand.
DEPLOY_MIN=${DEPLOY_MIN:-${MACOSX_DEPLOYMENT_TARGET:-11.0}}

ROOT=$(pwd)
DEST="$ROOT/$PREFIX/$ARCH"
WORK="$ROOT/.macos-deps-build"
SRC="$WORK/src"
CACHE="$WORK/cache"

mkdir -p "$DEST" "$SRC" "$CACHE"

# Pinned to a commit, fetched as the archive of that commit, and checked
# against a sha256. Everything comes from codeload rather than each project's
# own release host: those hosts are not uniformly reachable from a sandboxed
# or proxied build, and one source keeps this simple.
#
# A sha256 mismatch means either tampering or GitHub changing how it generates
# archives. If it is the latter, re-record the hash in the same commit that
# explains why.
#
#                 repo                 commit                                     sha256
sdl2_src="        libsdl-org/SDL       5d249570393f7a37e037abf22cd6012a4cc56a71   10f1194f8d2e4a73ca1c7c553b3189d0b68ab9ef3544e8d2a268e4429456b373"
sdl2_image_src="  libsdl-org/SDL_image c1bf2245b0ba63a25afe2f8574d305feca25af77   224b08c32c0fb6c769ca5f599f6da37e2b532b6ffd52886e9fa13656767cf1a2"
libpng_src="      pnggroup/libpng      3061454d980de7d53608f594194cfac722721d2a   a2569b7553971e36e86c8f75b9d1b5abbe92c436e05169afe3f0072e937f3536"
freetype_src="    freetype/freetype    42608f77f20749dd6ddc9e0536788eaad70ea4b5   68ce87bb59ea209eb7350f41a94a27519ce16b37011b475a1e62d4abee154b66"
zlib_src="        madler/zlib          51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf   d9e270d46252734aa49770fbc544125391617956266f220bd63216c834f3a522"

fetch()
{
    local name=$1 spec=$2
    local repo commit want tar dir

    read -r repo commit want <<< "$spec"
    tar="$CACHE/$name-$commit.tar.gz"
    dir="$SRC/$name"

    if [ ! -f "$tar" ]; then
        echo "  $name: downloading $commit"
        curl -sSfL --max-time 300 -o "$tar.part" \
            "https://codeload.github.com/$repo/tar.gz/$commit"
        mv "$tar.part" "$tar"
    fi

    local got
    got=$(shasum -a 256 "$tar" | cut -d' ' -f1)
    if [ "$got" != "$want" ]; then
        echo "error: $name archive sha256 is" >&2
        echo "         $got" >&2
        echo "       expected" >&2
        echo "         $want" >&2
        rm -f "$tar"
        exit 1
    fi

    if [ ! -d "$dir" ]; then
        rm -rf "$dir.tmp"; mkdir -p "$dir.tmp"
        # Skip the VCS metadata: none of it is a build input, and creating
        # .git* paths is refused outright under a sandboxed build.
        tar -xzf "$tar" -C "$dir.tmp" --strip-components=1 --exclude='.git*'
        mv "$dir.tmp" "$dir"
    fi
    echo "  $name: $commit"
}

# CMake for all of them: the one build system they share, no autotools
# needed, and it names the archives the way the main Makefile expects.
cmake_build()
{
    local name=$1; shift
    local dir="$SRC/$name"
    local build="$WORK/build-$name"

    echo "  $name: configuring"
    rm -rf "$build"
    if ! cmake -S "$dir" -B "$build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$DEST" \
        -DCMAKE_PREFIX_PATH="$DEST" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_MIN" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_SHARED_LIBS=OFF \
        "$@" > "$WORK/$name-configure.log" 2>&1
    then
        tail -40 "$WORK/$name-configure.log" >&2
        exit 1
    fi

    echo "  $name: building"
    if ! cmake --build "$build" \
        --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 3)" \
        > "$WORK/$name-build.log" 2>&1
    then
        tail -40 "$WORK/$name-build.log" >&2
        exit 1
    fi

    cmake --install "$build" > "$WORK/$name-install.log" 2>&1

    # zlib builds a shared library whatever BUILD_SHARED_LIBS says. With both
    # in the prefix the linker takes the dylib, which would put a contrib
    # path back into the binary and undo the point of all this.
    rm -f "$DEST"/lib/*.dylib
}

# contrib/Makefile has to treat these as always-out-of-date targets, so
# without a stamp every `make` would reconfigure and rebuild all five. The
# stamp records the commit, so re-pinning a version still forces a rebuild.
build_one()
{
    local name=$1 spec=$2 outlib=$3; shift 3
    local commit stamp
    commit=$(echo "$spec" | tr -s ' ' | cut -d' ' -f2)
    stamp="$DEST/.stamp-$name"

    if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$commit" ] \
       && [ -f "$DEST/lib/$outlib" ]
    then
        echo "  $name: up to date"
        return
    fi

    fetch "$name" "$spec"
    cmake_build "$name" "$@"
    echo "$commit" > "$stamp"
}

build_zlib()
{
    build_one zlib "$zlib_src" libz.a -DZLIB_BUILD_EXAMPLES=OFF
}

build_libpng()
{
    build_one libpng "$libpng_src" libpng16.a \
        -DPNG_SHARED=OFF \
        -DPNG_STATIC=ON \
        -DPNG_TOOLS=OFF \
        -DPNG_TESTS=OFF \
        -DPNG_FRAMEWORK=OFF
    # The main Makefile links contrib/install/<arch>/lib/libpng.a; the install
    # is versioned.
    [ -e "$DEST/lib/libpng.a" ] || ln -sf libpng16.a "$DEST/lib/libpng.a"
}

build_freetype()
{
    # No PNG or zlib: those are only for colour bitmap and compressed fonts,
    # and the bundled HackGen is a plain outline font.
    build_one freetype "$freetype_src" libfreetype.a \
        -DFT_DISABLE_HARFBUZZ=ON \
        -DFT_DISABLE_BROTLI=ON \
        -DFT_DISABLE_BZIP2=ON \
        -DFT_DISABLE_PNG=ON \
        -DFT_DISABLE_ZLIB=ON
}

build_sdl2()
{
    build_one sdl2 "$sdl2_src" libSDL2.a \
        -DSDL_SHARED=OFF \
        -DSDL_STATIC=ON \
        -DSDL_TEST=OFF \
        -DSDL_INSTALL_TESTS=OFF
}

build_sdl2_image()
{
    # PNG only. Every image the game loads is a PNG (dat/tiles is 29 files,
    # all png), so the JPEG-XL / AVIF / AOM / TIFF / WebP decoders Homebrew's
    # SDL2_image drags in were pure weight. PNG_SHARED=OFF links libpng in
    # rather than dlopen'ing it.
    build_one sdl2-image "$sdl2_image_src" libSDL2_image.a \
        -DSDL2IMAGE_PNG=ON \
        -DSDL2IMAGE_PNG_SHARED=OFF \
        -DSDL2IMAGE_VENDORED=OFF \
        -DSDL2IMAGE_DEPS_SHARED=OFF \
        -DSDL2IMAGE_JPG=OFF \
        -DSDL2IMAGE_TIF=OFF \
        -DSDL2IMAGE_WEBP=OFF \
        -DSDL2IMAGE_AVIF=OFF \
        -DSDL2IMAGE_JXL=OFF \
        -DSDL2IMAGE_SAMPLES=OFF \
        -DSDL2IMAGE_TESTS=OFF
}

for lib in "$@"; do
    case "$lib" in
        zlib)       build_zlib ;;
        libpng)     build_libpng ;;
        freetype)   build_freetype ;;
        sdl2)       build_sdl2 ;;
        sdl2-image) build_sdl2_image ;;
        *) echo "build-macos-deps.sh: unknown library '$lib'" >&2; exit 1 ;;
    esac
done

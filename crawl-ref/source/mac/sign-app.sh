#!/bin/bash
#
# Sign an app bundle, inside out.
#
# Usage: sign-app.sh <app-bundle>
#   MACOS_SIGN_IDENTITY  codesign identity; "-" (the default) is ad-hoc
#
# Ad-hoc is enough to run locally but not to pass Gatekeeper on a downloaded
# copy. A real Developer ID additionally turns on the hardened runtime and a
# secure timestamp, both of which notarization requires.
#
# Signing is explicit rather than --deep, which Apple discourages for
# distribution: it applies one set of options to whatever it happens to find.
# Nested code is signed first because signing the bundle seals what is inside
# it, so anything signed afterwards would break that seal.

set -euo pipefail

BUNDLE=${1:?Usage: sign-app.sh <app-bundle>}
IDENTITY=${MACOS_SIGN_IDENTITY:--}

[ -d "$BUNDLE" ] || { echo "No such bundle: $BUNDLE" >&2; exit 1; }

OPTS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != "-" ]; then
    # --timestamp contacts Apple's timestamp server, so this needs network.
    # Notarization rejects anything signed without it.
    OPTS+=(--options runtime --timestamp)
    echo "  signing as: $IDENTITY"
else
    echo "  signing ad-hoc (not distributable as-is)"
fi

# The bundle's own executable is covered by signing the bundle; every other
# Mach-O has to be signed separately or notarization rejects the lot. For the
# console bundle that means Contents/Resources/crawl, which sits behind a
# shell script launcher.
main_exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
           "$BUNDLE/Contents/Info.plist" 2>/dev/null || true)

nested=0
while IFS= read -r f; do
    [ "$f" = "$BUNDLE/Contents/MacOS/$main_exe" ] && continue
    file "$f" | grep -q 'Mach-O' || continue
    codesign "${OPTS[@]}" "$f" 2>&1 | grep -v 'replacing existing signature' || true
    nested=$((nested + 1))
done < <(find "$BUNDLE" -type f \( -perm +111 -o -name '*.dylib' \))

codesign "${OPTS[@]}" "$BUNDLE" 2>&1 | grep -v 'replacing existing signature' || true
codesign --verify --deep --strict "$BUNDLE"

echo "  signed $nested nested Mach-O file(s) plus the bundle"

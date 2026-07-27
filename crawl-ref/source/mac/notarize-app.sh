#!/bin/bash
#
# Submit an app bundle for notarization and staple the result.
#
# Usage: notarize-app.sh <app-bundle>
#   NOTARY_KEY_PATH    App Store Connect API key (.p8) on disk
#   NOTARY_KEY_ID      key identifier
#   NOTARY_ISSUER_ID   issuer UUID
#
# Notarization is Apple scanning the signed bundle and recording a verdict.
# Stapling writes that verdict into the bundle, so the first launch does not
# have to ask Apple and works offline.
#
# The bundle must already carry a Developer ID signature with the hardened
# runtime and a secure timestamp; ad-hoc signatures are rejected.

set -euo pipefail

BUNDLE=${1:?Usage: notarize-app.sh <app-bundle>}

: "${NOTARY_KEY_PATH:?NOTARY_KEY_PATH is required}"
: "${NOTARY_KEY_ID:?NOTARY_KEY_ID is required}"
: "${NOTARY_ISSUER_ID:?NOTARY_ISSUER_ID is required}"

[ -d "$BUNDLE" ] || { echo "No such bundle: $BUNDLE" >&2; exit 1; }

# notarytool takes an archive, not a directory. ditto is what Apple documents
# for this; zip can mangle the bundle metadata on the way in.
submission="${TMPDIR:-/tmp}/notarize-$$.zip"
trap 'rm -f "$submission"' EXIT

echo "  submitting for notarization; this takes a few minutes"
ditto -c -k --keepParent "$BUNDLE" "$submission"

xcrun notarytool submit "$submission" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" \
    --wait

xcrun stapler staple "$BUNDLE"
xcrun stapler validate "$BUNDLE"

#!/bin/zsh
# Packs an app into a compressed disk image with an Applications shortcut, for
# drag-to-install. Uses only hdiutil, so it needs no extra tools.
#
#   scripts/make-dmg.sh path/to/GoodThoughts.app path/to/goodthoughts-1.0.0.dmg
#
# Signing and notarising the image are separate steps (see docs/RELEASING.md).
set -euo pipefail

app=${1:?Usage: make-dmg.sh <app> <out.dmg>}
out=${2:?Usage: make-dmg.sh <app> <out.dmg>}
[[ -d "$app" ]] || { print -u2 "No app at $app"; exit 1; }

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/${app:t}"
ln -s /Applications "$staging/Applications"

rm -f "$out"
hdiutil create -quiet -volname "goodthoughts" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$out"
hdiutil verify -quiet "$out"
print "Wrote $out"

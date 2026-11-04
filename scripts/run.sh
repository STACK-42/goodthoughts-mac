#!/bin/zsh
# Builds GoodThoughts.app with only the Command Line Tools (no Xcode) and opens it.
#
#   scripts/run.sh            build, quit any running copy, open the new one
#   scripts/run.sh --no-open  build only (CI uses this to keep the script working)
#
# This is a convenience for trying the app. The real build is xcodebuild in CI.
# It reads the build settings it needs from project.yml, so keep the two in step.
set -euo pipefail

cd "${0:A:h}/.."
open_app=1
[[ "${1:-}" == "--no-open" ]] && open_app=0

setting() {
  # First "KEY: value" in project.yml, quotes stripped.
  local value
  value=$(grep -m1 -E "^[[:space:]]+$1:" project.yml | sed -E 's/^[^:]+:[[:space:]]*//; s/"//g')
  [[ -n "$value" ]] || { print -u2 "No $1 in project.yml"; exit 1; }
  print -r -- "$value"
}

name=GoodThoughts
bundle_id=$(setting PRODUCT_BUNDLE_IDENTIFIER)
marketing=$(setting MARKETING_VERSION)
build_number=$(setting CURRENT_PROJECT_VERSION)
min_macos=$(setting MACOSX_DEPLOYMENT_TARGET)
arch=$(uname -m)

app=build/local/$name.app
contents=$app/Contents

# XcodeGen writes Info.plist and the entitlements from project.yml.
command -v xcodegen >/dev/null || { print -u2 "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

rm -rf "$app"
mkdir -p "$contents/MacOS" "$contents/Resources"

print "Compiling ($arch, macOS $min_macos)…"
swiftc \
  -swift-version 6 \
  -target "$arch-apple-macos$min_macos" \
  -parse-as-library \
  -Onone -g \
  -module-name "$name" \
  -o "$contents/MacOS/$name" \
  $(find "$name" -name '*.swift' | sort)
# Keep the debug symbols beside the app, not inside its signed bundle.
rm -rf "build/local/$name.dSYM"
[[ -d "$contents/MacOS/$name.dSYM" ]] && mv "$contents/MacOS/$name.dSYM" build/local/

# Fill in the build variables Xcode would normally substitute.
sed \
  -e "s/\$(EXECUTABLE_NAME)/$name/g" \
  -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$bundle_id/g" \
  -e "s/\$(MARKETING_VERSION)/$marketing/g" \
  -e "s/\$(CURRENT_PROJECT_VERSION)/$build_number/g" \
  -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/$min_macos/g" \
  -e "s/\$(DEVELOPMENT_LANGUAGE)/en/g" \
  "$name/Info.plist" > "$contents/Info.plist"
if grep -q '\$(' "$contents/Info.plist"; then
  print -u2 "Info.plist still has unfilled build variables:"
  grep -o '\$([A-Z_]*)' "$contents/Info.plist" | sort -u >&2
  exit 1
fi
plutil -lint -s "$contents/Info.plist"
print -n "APPL????" > "$contents/PkgInfo"

# Resources are flattened into Contents/Resources, as Xcode does for groups.
find "$name" -type f ! -name '*.swift' ! -name 'Info.plist' ! -name '*.entitlements' ! -name '.DS_Store' \
  -exec cp {} "$contents/Resources/" \;

codesign --force --sign - --options runtime \
  --entitlements "$name/$name.entitlements" "$app" 2>/dev/null
codesign --verify --strict "$app"
print "Built $app"

if (( open_app )); then
  pkill -x "$name" 2>/dev/null && sleep 0.5 || true
  open "$app"
  print "Opened. Look for the g in the menu bar."
fi

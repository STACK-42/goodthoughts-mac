#!/bin/zsh
# Writes the Sparkle appcast for one release to stdout. The release workflow attaches
# it to the GitHub Release as appcast.xml, so the app's SUFeedURL
# (…/releases/latest/download/appcast.xml) always points at the newest one.
#
#   SIGN_UPDATE=path/to/sign_update scripts/release/make-appcast.sh goodthoughts-1.2.0.dmg 1.2.0
#
# The .dmg is signed with the EdDSA key in $SPARKLE_KEY_FILE when set (CI), otherwise
# with the "goodthoughts-mac" key in the login keychain (made by generate_keys).
set -euo pipefail

dmg=${1:?Usage: make-appcast.sh <dmg> <version>}
version=${2:?Usage: make-appcast.sh <dmg> <version>}
sign_update=${SIGN_UPDATE:?Set SIGN_UPDATE to the path of Sparkle sign_update}
repo=${GITHUB_REPOSITORY:-STACK-42/goodthoughts-mac}
min_macos=${MIN_MACOS:-13.0}

[[ -f "$dmg" ]] || { print -u2 "No file at $dmg"; exit 1; }
semver='^[0-9]+(\.[0-9]+)*$'
[[ "$version" =~ $semver ]] || { print -u2 "Version must look like 1.2.0, got $version"; exit 1; }

if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
  key_args=(--ed-key-file "$SPARKLE_KEY_FILE")
else
  key_args=(--account goodthoughts-mac)
fi
# Prints: sparkle:edSignature="…" length="…"
attributes=$("$sign_update" "${key_args[@]}" "$dmg")
[[ "$attributes" == *'sparkle:edSignature="'* && "$attributes" == *'length="'* ]] \
  || { print -u2 "sign_update gave unexpected output: $attributes"; exit 1; }

file=${dmg:t}
date=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>goodthoughts for Mac</title>
    <link>https://github.com/$repo</link>
    <description>Updates for the goodthoughts menu bar app.</description>
    <language>en</language>
    <item>
      <title>Version $version</title>
      <pubDate>$date</pubDate>
      <sparkle:version>$version</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$min_macos</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/$repo/releases/tag/v$version</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/$repo/releases/download/v$version/$file" type="application/octet-stream" $attributes />
    </item>
  </channel>
</rss>
XML

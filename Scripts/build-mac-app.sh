#!/bin/bash
#
# Builds the macOS app (Release, universal Apple Silicon + Intel) and packages it as
# Releases/Pro-Remote-macOS.zip, ready to commit.
#
#   Scripts/build-mac-app.sh
#
# The app is signed with the Apple Development certificate of the team in TEAM_ID (Bethel Church by
# default). It is NOT notarized - that needs a Developer ID certificate - so a copy downloaded through a
# browser must be approved once on first launch (see Releases/README.md). Nothing here touches the
# Apple Developer account: no certificates are created and no devices are registered.

set -euo pipefail

TEAM_ID="${TEAM_ID:-THW3L89YM6}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Releases"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"

echo "==> Archiving (Release, macOS, team $TEAM_ID)"
xcodebuild archive \
  -project "Pro Remote.xcodeproj" \
  -scheme "Pro Remote" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$WORK/ProRemote.xcarchive" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true

APP="$WORK/ProRemote.xcarchive/Products/Applications/Pro Remote.app"
if [ ! -d "$APP" ]; then
  echo "error: archive did not produce Pro Remote.app" >&2
  exit 1
fi

echo "==> Verifying signature"
codesign --verify --deep --strict "$APP"

echo "==> Packaging"
mkdir -p "$OUT"
rm -f "$OUT/Pro-Remote-macOS.zip"
# ditto (not zip) keeps the code signature and extended attributes intact.
ditto -c -k --keepParent "$APP" "$OUT/Pro-Remote-macOS.zip"

COMMIT="$(git rev-parse --short HEAD)"
DIRTY=""
if [ -n "$(git status --porcelain -- "Pro Remote" "Pro Remote.xcodeproj")" ]; then DIRTY=" (with uncommitted changes)"; fi
{
  echo "Pro Remote for macOS"
  echo "Built:    $(date '+%Y-%m-%d %H:%M %Z')"
  echo "Source:   commit $COMMIT$DIRTY"
  echo "Archs:    $(lipo -archs "$APP/Contents/MacOS/Pro Remote")"
  echo "Needs:    macOS $(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist") or later"
  echo "Signed:   $(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1) - team $(codesign -dvv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  echo "Notarized: no"
} > "$OUT/BUILD-INFO.txt"

echo "==> Done"
cat "$OUT/BUILD-INFO.txt"
ls -lh "$OUT/Pro-Remote-macOS.zip"

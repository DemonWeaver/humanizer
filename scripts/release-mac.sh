#!/bin/bash
# Cut a macOS release: stage the notarized DMG into docs/ and regenerate the
# Sparkle appcast so existing installs auto-update.
#
# Prereqacquire: you have already exported the app via Xcode "Direct
# Distribution" (signs + notarizes + staples) and built the DMG with
# scripts (see humanizer-release-process). Pass the path to that DMG.
#
# Usage: scripts/release-mac.sh <version> <path-to-notarized-dmg>
#   e.g. scripts/release-mac.sh 1.0.1 ~/Desktop/humanizer-releases/1.0.1/Humanizer-1.0.1.dmg
set -euo pipefail

VERSION="${1:?usage: release-mac.sh <version> <dmg-path>}"
DMG="${2:?usage: release-mac.sh <version> <dmg-path>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS="$REPO_ROOT/docs"
SPARKLE_BIN="${SPARKLE_BIN:-$HOME/opt/sparkle/bin}"
PAGES_PREFIX="https://demonweaver.github.io/humanizer/"

[ -f "$DMG" ] || { echo "DMG not found: $DMG" >&2; exit 1; }

# Verify the DMG is notarized + stapled before publishing it.
echo "Validating notarization…"
xcrun stapler validate "$DMG"

# Stage the DMG into docs/ (GitHub Pages serves it next to the appcast).
DEST="$DOCS/Humanizer-$VERSION.dmg"
cp "$DMG" "$DEST"
echo "Staged $DEST"

# Regenerate the appcast over every DMG in docs/, signing with the EdDSA key
# in the login keychain. A single Pages prefix works because the DMGs are
# co-located with the appcast.
"$SPARKLE_BIN/generate_appcast" "$DOCS" \
  --download-url-prefix "$PAGES_PREFIX" \
  -o "$DOCS/appcast.xml"

echo
echo "Done. Review docs/appcast.xml, then:"
echo "  git add docs/ && git commit -m \"macOS $VERSION appcast\" && git push"
echo "  gh release create v$VERSION \"$DMG\" --title \"Humanizer $VERSION\"   # (or upload to existing)"
echo
echo "GitHub Pages then serves the new version; installed apps update within a day"
echo "(or immediately via the menu → Check for Updates…)."

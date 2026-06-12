---
name: ship-release
description: |
  Cut a new release of the Humanizer apps (macOS + Windows) and keep
  auto-update working. Use when asked to "ship", "release", "cut a version",
  "make the dmg/installer", "publish an update", or bump the version. Covers
  version bumps, the macOS Sparkle/appcast flow, the Windows electron-updater
  flow, and how to verify both auto-update channels.
license: MIT
---

# Ship a Humanizer release

The repo is `DemonWeaver/humanizer` (root = macOS Swift app; `windows/` =
Electron app; `docs/` = GitHub Pages Sparkle appcast). Both apps auto-update,
so **every release MUST bump the version** — auto-update only fires on a higher
version number. Never replace a published release asset in place.

## The golden rule: bump versions first

| App | Where | Bump |
|---|---|---|
| macOS | `project.yml` | `CFBundleShortVersionString` (e.g. 1.0.1→1.0.2) **and** `CFBundleVersion` (integer, +1) **and** `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in settings |
| Windows | `windows/package.json` | `version` |

After editing `project.yml`, run `xcodegen generate`.

## macOS — Sparkle + GitHub Pages appcast

The notarized Archive→Direct-Distribution export is a **manual Xcode step only
the user can do** (it's a GUI action). Once they hand you the DMG path:

1. Build the DMG (see the EasySnaps-derived pipeline: `create-dmg` with the app
   icon, notarize via `xcrun notarytool submit <dmg> --keychain-profile
   "notarytool" --wait`, then `xcrun stapler staple`). The export itself signs
   with Developer ID (team **LRUFMKU4V6**) and notarizes.
2. Run `scripts/release-mac.sh <version> <dmg-path>`. It validates the staple,
   copies the DMG into `docs/`, and regenerates the **signed** `docs/appcast.xml`
   via `~/opt/sparkle/bin/generate_appcast --download-url-prefix
   https://demonweaver.github.io/humanizer/`. DMGs live in `docs/` (tiny) so one
   URL prefix covers every version.
3. `git add docs/ && git commit -m "macOS <version> appcast" && git push`.
4. `gh release upload v<version> <dmg>` (or `gh release create`) so the DMG is on
   the Releases download page too.

Sparkle key: reuses the existing EdDSA key (public
`2BA/bbHaZ4yFRfhbDGjMjK5YbAV8aw9pITwETl4CyV8=`, private in the login keychain).
Info.plist already carries `SUFeedURL` + `SUPublicEDKey`. Sandboxed Sparkle works
via the bundled Installer/Downloader XPC services + the
`com.apple.security.temporary-exception.mach-lookup.global-name = $(PRODUCT_BUNDLE_IDENTIFIER)-spks`
entitlement — don't remove those.

## Windows — electron-updater (fully automated by CI)

1. Bump `windows/package.json` `version`, commit, push.
2. `git tag v<version> && git push origin v<version>`.
3. The `.github/workflows/build-windows.yml` workflow runs
   `electron-builder --win --x64 --publish always` on a Windows runner and
   uploads the installer **+ `latest.yml` + `.blockmap`** to the matching
   GitHub release (this needs the workflow's `permissions: contents: write`).

No Windows machine or signing cert is required. The installer is unsigned
(SmartScreen "Run anyway" on first manual install only — not on auto-updates).

## Verify the release

- Windows feed: `curl -sL https://github.com/DemonWeaver/humanizer/releases/download/v<version>/latest.yml` → `version:` matches.
- Mac feed: `curl -s https://demonweaver.github.io/humanizer/appcast.xml` → newest `<item>` is the new version with a `sparkle:edSignature`.
- Confirm the release isn't a draft: `gh release view v<version> --json isDraft`.

## How auto-update works (reference)

**Windows (electron-updater):** the installed app reads `latest.yml` from the
latest GitHub release on launch and every 6h, compares versions, downloads the
new installer in the background (differential via `.blockmap`), verifies SHA512,
notifies the user, and silently installs on app quit. Per-user install
(`perMachine: false`) → no UAC prompt. Code in `windows/lib/updater.js`; only
runs in packaged builds (`app.isPackaged`).

**macOS (Sparkle):** the app reads `SUFeedURL` (the GitHub Pages appcast) daily,
verifies the EdDSA signature against the embedded `SUPublicEDKey`, and prompts
to download+install. Manual "Check for Updates…" lives in the menu-bar gear menu
(`Sources/AppUpdater.swift`).

**Bootstrap:** auto-update only works from the first update-enabled build
forward (v1.0.1). Users on older builds must install the new version once by
hand; everything after self-updates.

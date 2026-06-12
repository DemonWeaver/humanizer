# Humanizer (macOS menu bar app)

A menu bar app that rewrites AI-sounding text to sound human, powered by the
[blader/humanizer](https://github.com/blader/humanizer) skill running on the
Claude API.

> **On Windows?** There's a native tray app with the same features — see
> [`windows/`](windows/) and grab `Humanizer-Setup-x.y.z.exe` from
> [Releases](https://github.com/DemonWeaver/humanizer/releases).

## Features

- **Menu bar popover** — paste text, or click "Humanize Clipboard" (⌘↩ to run).
- **File drop** — drag `.txt`, `.md`, `.docx`, `.rtf`, or `.pdf` anywhere onto the
  popover. The humanized version is saved to your configured output folder as
  `name-humanized.txt/.md` (or via a save panel if no folder is set).
- **Auto-copy** — every result is copied to the clipboard with a system
  notification confirming it.
- **Iterate on wording** — type feedback ("less formal", "keep the second
  paragraph") and hit Refine; the conversation continues with full context.
- **Teach My Style** — after refining, one click distills your feedback into a
  persistent style profile (Application Support/Humanizer/style-profile.md)
  that is applied to every future rewrite. View/edit it in Settings → Voice & Style.
- **Voice calibration** — paste samples of your own writing in Settings so
  rewrites match your voice (a native feature of the skill).
- **Profiles** — named custom prompts (e.g. "Cover letter mode") selectable in
  the popover, sent along with the rewrite.
- **Models** — Claude Opus 4.8 (default), Sonnet 4.6, or Haiku 4.5. The 8k-token
  skill prompt uses prompt caching, so repeat requests cost ~10% on that portion.

## Install

Download the latest `Humanizer-x.y.z.dmg` from
[Releases](https://github.com/DemonWeaver/humanizer/releases), open it, and
drag Humanizer to Applications. The DMG is signed and notarized — it opens
without warnings on macOS 14+.

Or build from source:

## Build & run

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
cd HumanizerApp
xcodegen generate
open Humanizer.xcodeproj
```

In Xcode: select your team under Signing & Capabilities, then Run. The app is
sandboxed (network client + user-selected files) and App Store-compatible.

First run: open Settings (gear icon in the popover) and paste your Anthropic
API key from console.anthropic.com. It's stored in the macOS Keychain.

## How the prompt is assembled

Each request sends a system prompt in this order (stable → volatile, with the
prompt-cache breakpoint after the stable part):

1. `Resources/SKILL.md` — the full humanizer skill, verbatim (cached)
2. App instructions — "return only the final rewrite" (cached)
3. Voice calibration sample (if set)
4. Learned style profile (if any)
5. Active custom profile prompt (if selected)

To pull upstream skill updates:

```bash
curl -fsSL https://raw.githubusercontent.com/blader/humanizer/main/SKILL.md -o Resources/SKILL.md
```

## App Store notes

- Bring-your-own-API-key apps are allowed; describe it clearly in the review
  notes and App Description.
- Bundle ID is `com.brandon.humanizer` — change in `project.yml` if needed.
- Entitlements: app-sandbox, network.client, files.user-selected.read-write,
  files.bookmarks.app-scope (for the persistent output folder).

## Privacy

Your API key is stored in the macOS Keychain. Your text is sent only to
`api.anthropic.com` — there is no other server, no analytics, no telemetry.

## License & credits

MIT — see [LICENSE](LICENSE). The bundled rewrite skill (`Resources/SKILL.md`)
is [blader/humanizer](https://github.com/blader/humanizer) by Siqi Chen, also
MIT licensed. This app is an independent native wrapper and is not affiliated
with the upstream project.

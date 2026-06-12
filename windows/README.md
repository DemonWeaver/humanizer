# Humanizer for Windows

The Windows build of Humanizer — an Electron tray app that rewrites AI-sounding
text to sound human, using the same [blader/humanizer](https://github.com/blader/humanizer)
skill and Claude API as the macOS app. Feature parity: paste, clipboard,
file drop (txt/md/docx/rtf/pdf), iterative refine, "Teach My Style", voice
calibration, custom profiles, notification sounds, and a chosen output folder.

## Install (for users)

Download the latest `Humanizer-Setup-x.y.z.exe` from
[Releases](https://github.com/DemonWeaver/humanizer/releases) and run it. It
installs in seconds and adds a tray icon and Start Menu shortcut.

**SmartScreen note:** the installer isn't signed with a Windows certificate
yet, so Windows may show *"Windows protected your PC."* Click **More info →
Run anyway**. (This is the Windows equivalent of the macOS "open anyway"
prompt; it's a one-time click.) To remove it entirely later, an EV/OV code
signing certificate can be added to the build.

On first run, click the tray icon → ⚙ Settings → paste your Anthropic API key
(from console.anthropic.com). The key is encrypted at rest with Windows DPAPI
via Electron `safeStorage`; your text is sent only to `api.anthropic.com`.

## How updates are built

There is no Windows machine in the loop. The installer is produced by a GitHub
Actions Windows runner (`.github/workflows/build-windows.yml`):

- Push a tag `vX.Y.Z` → the workflow builds the NSIS installer and attaches the
  `.exe` to that GitHub Release automatically.
- Or trigger it manually from the Actions tab (uploads the installer as a
  build artifact).

## Build from source

Requires Node 20+. On Windows:

```bash
cd windows
npm install
npm run make-icons   # generates assets/icon.ico, tray.png, etc.
npm start            # run the app
npm run dist         # build dist/Humanizer-Setup-x.y.z.exe
```

The icon generator needs `sharp` (installed as a devDependency). On macOS/Linux
you can run and develop the app the same way (`npm start`); only the final
`.exe` packaging needs Windows (or the CI workflow).

## Architecture

- `main.js` — tray, frameless popover window, all privileged work (file I/O,
  key storage, Anthropic streaming, notifications). Renderer has no Node access.
- `preload.js` — minimal `contextBridge` API surface.
- `src/` — the UI (HTML/CSS/JS), mirroring the macOS popover.
- `lib/` — `anthropic.js` (SSE streaming), `prompt.js` (system prompt =
  skill + per-user blocks, with prompt caching), `extract.js` (docx/pdf/rtf →
  text), `store.js` (settings + encrypted key).
- `assets/SKILL.md` — vendored from the repo root `Resources/SKILL.md`; CI
  re-syncs it on every build.

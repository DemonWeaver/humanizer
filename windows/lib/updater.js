"use strict";
// Auto-update from GitHub Releases via electron-updater. The repo is read from
// the `publish` block in package.json (baked into app-update.yml at build time).
const { autoUpdater } = require("electron-updater");
const { Notification } = require("electron");

function initAutoUpdate() {
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;

  autoUpdater.on("update-downloaded", (info) => {
    new Notification({
      title: "Humanizer update ready",
      body: `Version ${info.version} will be installed when you quit Humanizer.`,
    }).show();
  });

  autoUpdater.on("error", (err) => {
    // Stay silent for the user; updates are best-effort.
    console.log("auto-update error:", err && err.message);
  });

  // Check on launch, then every 6 hours while the tray app runs.
  const check = () => autoUpdater.checkForUpdates().catch(() => {});
  check();
  setInterval(check, 6 * 60 * 60 * 1000);
}

module.exports = { initAutoUpdate };

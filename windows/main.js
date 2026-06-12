"use strict";
const {
  app, BrowserWindow, Tray, Menu, ipcMain, dialog, shell,
  clipboard, Notification, screen, nativeImage,
} = require("electron");
const fs = require("fs");
const path = require("path");

const store = require("./lib/store");
const { systemBlocks, profileUpdaterInstructions } = require("./lib/prompt");
const { streamMessage } = require("./lib/anthropic");
const { extractText, SUPPORTED } = require("./lib/extract");
const { initAutoUpdate } = require("./lib/updater");

// Single instance — clicking the installer/shortcut again just shows the window.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => showWindow());
}

let tray = null;
let win = null;
let currentAbort = null;
let conversation = []; // [{role, content}] for the active humanize session

app.whenReady().then(() => {
  createWindow();
  createTray();
  // Tray app — no dock/taskbar presence.
  if (process.platform === "darwin" && app.dock) app.dock.hide();
  // Auto-update only in packaged builds (dev runs have no app-update.yml).
  if (app.isPackaged) {
    try { initAutoUpdate(); } catch (e) { console.log("updater init failed:", e.message); }
  }
});

app.on("window-all-closed", (e) => e.preventDefault()); // stay alive in tray

function createWindow() {
  win = new BrowserWindow({
    width: 460,
    height: 640,
    show: false,
    frame: false,
    resizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadFile(path.join(__dirname, "src", "index.html"));
  win.on("blur", () => { if (!win.webContents.isDevToolsOpened()) win.hide(); });
}

function createTray() {
  const icon = nativeImage.createFromPath(path.join(__dirname, "assets", "tray.png"));
  tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon);
  tray.setToolTip("Humanizer");
  tray.on("click", () => toggleWindow());
  tray.on("right-click", () => {
    const menu = Menu.buildFromTemplate([
      { label: "Open Humanizer", click: () => showWindow() },
      { label: "Humanize Clipboard", click: () => { showWindow(); win.webContents.send("trigger-clipboard"); } },
      { type: "separator" },
      { label: "Quit", click: () => { tray.destroy(); app.exit(0); } },
    ]);
    tray.popUpContextMenu(menu);
  });
}

function toggleWindow() {
  if (win.isVisible()) win.hide();
  else showWindow();
}

function showWindow() {
  positionWindow();
  win.show();
  win.focus();
}

function positionWindow() {
  try {
    const b = tray.getBounds();
    const wb = win.getBounds();
    const display = screen.getDisplayMatching(b);
    const area = display.workArea;
    let x = Math.round(b.x + b.width / 2 - wb.width / 2);
    let y;
    // Taskbar usually at the bottom on Windows → place window above the tray.
    if (b.y > area.height / 2) y = Math.round(area.y + area.height - wb.height - 8);
    else y = Math.round(b.y + b.height + 8);
    x = Math.max(area.x + 4, Math.min(x, area.x + area.width - wb.width - 4));
    win.setPosition(x, y, false);
  } catch {}
}

// ---------- IPC ----------

ipcMain.handle("state:init", () => ({
  settings: store.readSettings(),
  style: store.readStyle(),
  hasKey: store.hasKey(),
  customSounds: listCustomSounds(),
}));

ipcMain.handle("settings:set", (_e, patch) => store.writeSettings(patch));
ipcMain.handle("style:set", (_e, patch) => { store.writeStyle(patch); return store.readStyle(); });

ipcMain.handle("key:save", (_e, value) => { store.saveKey(value); return store.hasKey(); });
ipcMain.handle("key:has", () => store.hasKey());

ipcMain.handle("file:open", async () => {
  const r = await dialog.showOpenDialog(win, {
    properties: ["openFile"],
    filters: [{ name: "Text documents", extensions: SUPPORTED }],
  });
  if (r.canceled || !r.filePaths[0]) return null;
  return loadFile(r.filePaths[0]);
});

ipcMain.handle("file:loadPath", async (_e, p) => loadFile(p));

async function loadFile(filePath) {
  try {
    const text = await extractText(filePath);
    return { ok: true, text, name: path.basename(filePath), sourcePath: filePath };
  } catch (err) {
    return { ok: false, error: err.message, name: path.basename(filePath) };
  }
}

ipcMain.handle("clipboard:read", () => clipboard.readText());

ipcMain.handle("clipboard:write", (_e, text) => {
  clipboard.writeText(text || "");
  const s = store.readSettings();
  notify("Output copied to clipboard.", s.rewriteDoneSound);
  return true;
});

ipcMain.on("humanize:start", (_e, { messages, status }) => {
  conversation = messages;
  runRewrite(status);
});

ipcMain.handle("humanize:cancel", () => {
  if (currentAbort) currentAbort.abort();
  return true;
});

ipcMain.handle("humanize:teach", () => teachStyle());

ipcMain.handle("file:save", async (_e, { text, sourceName, sourcePath }) => saveOutput(text, sourceName, sourcePath));

ipcMain.handle("folder:choose", async () => {
  const r = await dialog.showOpenDialog(win, { properties: ["openDirectory", "createDirectory"] });
  if (r.canceled || !r.filePaths[0]) return null;
  store.writeSettings({ outputFolder: r.filePaths[0] });
  return r.filePaths[0];
});

ipcMain.handle("folder:clear", () => { store.writeSettings({ outputFolder: "" }); return ""; });

ipcMain.handle("sound:import", async () => {
  const r = await dialog.showOpenDialog(win, {
    properties: ["openFile"],
    filters: [{ name: "Audio", extensions: ["mp3", "wav", "ogg", "m4a", "aac", "flac"] }],
  });
  if (r.canceled || !r.filePaths[0]) return null;
  const src = r.filePaths[0];
  const dest = path.join(store.soundsDir, path.basename(src));
  fs.copyFileSync(src, dest);
  return listCustomSounds();
});

ipcMain.handle("sound:list", () => listCustomSounds());
ipcMain.handle("sound:preview", (_e, name) => { playSoundInRenderer(name); return true; });

ipcMain.handle("open:external", (_e, url) => shell.openExternal(url));
ipcMain.handle("window:hide", () => win.hide());

function listCustomSounds() {
  try {
    return fs.readdirSync(store.soundsDir).filter((f) => /\.(mp3|wav|ogg|m4a|aac|flac)$/i.test(f));
  } catch { return []; }
}

// ---------- rewrite ----------

async function runRewrite(status) {
  const apiKey = store.readKey();
  if (!apiKey) {
    win.webContents.send("humanize:error", "No API key set. Add your Anthropic API key in Settings.");
    return;
  }
  const s = store.readSettings();
  const style = store.readStyle();
  const profile = (s.profiles || []).find((p) => p.id === s.selectedProfileId);
  const system = systemBlocks({
    voiceSample: style.voiceSample,
    styleProfile: style.styleProfile,
    customProfilePrompt: profile?.prompt,
  });

  currentAbort = new AbortController();
  win.webContents.send("humanize:begin", status);
  try {
    const text = await streamMessage({
      apiKey,
      model: s.model,
      system,
      messages: conversation,
      adaptiveThinking: s.model.startsWith("claude-opus") || s.model.startsWith("claude-sonnet"),
      onText: (delta) => win.webContents.send("humanize:delta", delta),
      signal: currentAbort.signal,
    });
    win.webContents.send("humanize:done", text);
  } catch (err) {
    if (err.name === "AbortError") win.webContents.send("humanize:cancelled");
    else win.webContents.send("humanize:error", err.message);
  } finally {
    currentAbort = null;
  }
}

async function teachStyle() {
  const apiKey = store.readKey();
  if (!apiKey) return { ok: false, error: "No API key set." };
  const feedback = conversation.filter((m) => m.role === "user").slice(1);
  if (feedback.length === 0) return { ok: false, error: "Refine the wording first, then teach." };

  const s = store.readSettings();
  const style = store.readStyle();
  const transcript = feedback.map((m) => `- ${m.content}`).join("\n");
  const prompt = `CURRENT STYLE PROFILE:\n${style.styleProfile || "(empty)"}\n\nFEEDBACK THE USER GAVE DURING THIS REWRITE SESSION:\n${transcript}\n\nReturn the updated style profile.`;
  try {
    const updated = await streamMessage({
      apiKey,
      model: s.model,
      maxTokens: 2000,
      system: [{ type: "text", text: profileUpdaterInstructions }],
      messages: [{ role: "user", content: prompt }],
      adaptiveThinking: false,
    });
    store.writeStyle({ styleProfile: updated.trim() });
    notify("Your style profile was updated from this session's feedback.", s.rewriteDoneSound);
    return { ok: true, styleProfile: updated.trim() };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

function saveOutput(text, sourceName, sourcePath) {
  if (!text) return { ok: false };
  const s = store.readSettings();
  let base = "humanized";
  let ext = "txt";
  if (sourceName) {
    const parsed = path.parse(sourceName);
    base = parsed.name + "-humanized";
    ext = parsed.ext.toLowerCase() === ".md" ? "md" : "txt";
  }
  if (s.outputFolder) {
    try {
      let dest = path.join(s.outputFolder, `${base}.${ext}`);
      let n = 2;
      while (fs.existsSync(dest)) dest = path.join(s.outputFolder, `${base}-${n++}.${ext}`);
      fs.writeFileSync(dest, text, "utf8");
      notify(`Saved ${path.basename(dest)} to ${path.basename(s.outputFolder)}.`, s.fileSavedSound);
      return { ok: true, path: dest };
    } catch (err) {
      return { ok: false, error: err.message };
    }
  }
  // No folder set → ask where to save.
  return dialog.showSaveDialog(win, { defaultPath: `${base}.${ext}` }).then((r) => {
    if (r.canceled || !r.filePath) return { ok: false };
    fs.writeFileSync(r.filePath, text, "utf8");
    notify(`Saved ${path.basename(r.filePath)}.`, s.fileSavedSound);
    return { ok: true, path: r.filePath };
  });
}

// ---------- notifications + sound ----------

function notify(body, soundChoice) {
  const n = new Notification({ title: "Humanizer", body, silent: soundChoice === "none" });
  n.show();
  if (soundChoice && soundChoice !== "none" && soundChoice !== "default") {
    playSoundInRenderer(soundChoice);
  }
}

// Sounds play through the (hidden or shown) renderer's <audio>, so custom
// imported files work without a native audio dependency.
function playSoundInRenderer(choice) {
  if (!win) return;
  let src = null;
  const custom = path.join(store.soundsDir, choice);
  if (fs.existsSync(custom)) src = "file://" + custom.replace(/\\/g, "/");
  win.webContents.send("play-sound", { choice, src });
}

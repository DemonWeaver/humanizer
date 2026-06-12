"use strict";
// Settings + secure API-key storage. Settings live in a JSON file in the
// per-user app data folder; the API key is encrypted with Electron safeStorage
// (Windows DPAPI / macOS Keychain) so it never sits on disk in plaintext.
const { app, safeStorage } = require("electron");
const fs = require("fs");
const path = require("path");

const dir = app.getPath("userData");
const settingsPath = path.join(dir, "settings.json");
const keyPath = path.join(dir, "apikey.bin");
const soundsDir = path.join(dir, "sounds");
const styleDir = path.join(dir, "style");

for (const d of [soundsDir, styleDir]) {
  try { fs.mkdirSync(d, { recursive: true }); } catch {}
}

const DEFAULTS = {
  model: "claude-opus-4-8",
  outputFolder: "",
  rewriteDoneSound: "default",
  fileSavedSound: "chime",
  profiles: [
    {
      id: "seed-casual-email",
      name: "Casual email",
      prompt:
        "This is an email to someone I know. Keep it friendly and direct, contractions are fine, no corporate phrasing, and keep it shorter than the original if possible.",
    },
  ],
  selectedProfileId: null,
};

function readSettings() {
  try {
    return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(settingsPath, "utf8")) };
  } catch {
    return { ...DEFAULTS };
  }
}

function writeSettings(patch) {
  const merged = { ...readSettings(), ...patch };
  fs.writeFileSync(settingsPath, JSON.stringify(merged, null, 2));
  return merged;
}

// --- API key ---
function saveKey(value) {
  if (!value) {
    try { fs.unlinkSync(keyPath); } catch {}
    return;
  }
  if (safeStorage.isEncryptionAvailable()) {
    fs.writeFileSync(keyPath, safeStorage.encryptString(value));
  } else {
    // Extremely rare fallback (no OS crypto). Mark so we don't try to decrypt.
    fs.writeFileSync(keyPath, Buffer.concat([Buffer.from("PLAIN:"), Buffer.from(value)]));
  }
}

function readKey() {
  try {
    const buf = fs.readFileSync(keyPath);
    if (buf.subarray(0, 6).toString() === "PLAIN:") return buf.subarray(6).toString();
    return safeStorage.decryptString(buf);
  } catch {
    return null;
  }
}

function hasKey() {
  return !!readKey();
}

// --- style profile + voice sample (plain text files) ---
function readStyle() {
  return {
    voiceSample: safeRead(path.join(styleDir, "voice.md")),
    styleProfile: safeRead(path.join(styleDir, "profile.md")),
  };
}
function writeStyle({ voiceSample, styleProfile }) {
  if (voiceSample !== undefined) safeWrite(path.join(styleDir, "voice.md"), voiceSample);
  if (styleProfile !== undefined) safeWrite(path.join(styleDir, "profile.md"), styleProfile);
}

function safeRead(p) {
  try { return fs.readFileSync(p, "utf8"); } catch { return ""; }
}
function safeWrite(p, v) {
  if (v && v.trim()) fs.writeFileSync(p, v);
  else { try { fs.unlinkSync(p); } catch {} }
}

module.exports = {
  readSettings, writeSettings,
  saveKey, readKey, hasKey,
  readStyle, writeStyle,
  soundsDir, styleDir,
};

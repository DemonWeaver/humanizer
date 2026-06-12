"use strict";
const { contextBridge, ipcRenderer, webUtils } = require("electron");

contextBridge.exposeInMainWorld("api", {
  init: () => ipcRenderer.invoke("state:init"),
  setSettings: (patch) => ipcRenderer.invoke("settings:set", patch),
  setStyle: (patch) => ipcRenderer.invoke("style:set", patch),
  saveKey: (value) => ipcRenderer.invoke("key:save", value),

  openFile: () => ipcRenderer.invoke("file:open"),
  loadPath: (p) => ipcRenderer.invoke("file:loadPath", p),
  // Resolve a dropped File object to its absolute path (Electron 32+).
  pathForFile: (file) => webUtils.getPathForFile(file),

  readClipboard: () => ipcRenderer.invoke("clipboard:read"),
  writeClipboard: (text) => ipcRenderer.invoke("clipboard:write", text),

  startHumanize: (messages, status) => ipcRenderer.send("humanize:start", { messages, status }),
  cancelHumanize: () => ipcRenderer.invoke("humanize:cancel"),
  teachStyle: () => ipcRenderer.invoke("humanize:teach"),

  saveOutput: (payload) => ipcRenderer.invoke("file:save", payload),
  chooseFolder: () => ipcRenderer.invoke("folder:choose"),
  clearFolder: () => ipcRenderer.invoke("folder:clear"),

  importSound: () => ipcRenderer.invoke("sound:import"),
  listSounds: () => ipcRenderer.invoke("sound:list"),
  previewSound: (name) => ipcRenderer.invoke("sound:preview", name),

  openExternal: (url) => ipcRenderer.invoke("open:external", url),
  hideWindow: () => ipcRenderer.invoke("window:hide"),

  on: (channel, cb) => {
    const allowed = [
      "humanize:begin", "humanize:delta", "humanize:done",
      "humanize:error", "humanize:cancelled",
      "trigger-clipboard", "play-sound",
    ];
    if (allowed.includes(channel)) ipcRenderer.on(channel, (_e, data) => cb(data));
  },
});

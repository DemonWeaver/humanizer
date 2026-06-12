"use strict";
const $ = (id) => document.getElementById(id);

const state = {
  settings: null,
  style: null,
  hasKey: false,
  customSounds: [],
  sourceName: null,
  sourcePath: null,
  messages: [],
  working: false,
};

const SYSTEM_SOUNDS = ["default", "none", "chime", "ding", "pop", "bell"];

async function boot() {
  const data = await window.api.init();
  state.settings = data.settings;
  state.style = data.style;
  state.hasKey = data.hasKey;
  state.customSounds = data.customSounds || [];
  hydrate();
  wire();
  wireIpc();
}

function hydrate() {
  $("keyBanner").classList.toggle("hidden", state.hasKey);
  $("model").value = state.settings.model;
  $("outputFolder").value = state.settings.outputFolder || "";
  $("voiceSample").value = state.style.voiceSample || "";
  $("styleProfile").value = state.style.styleProfile || "";
  $("keyStatus").textContent = state.hasKey ? "Key saved ✓" : "";
  $("keyStatus").className = "muted small" + (state.hasKey ? " ok" : "");
  renderProfilesDropdown();
  renderSoundPickers();
  renderProfilesList();
}

function renderProfilesDropdown() {
  const sel = $("profile");
  sel.innerHTML = "";
  const none = new Option("No profile", "");
  sel.add(none);
  for (const p of state.settings.profiles || []) sel.add(new Option(p.name, p.id));
  sel.value = state.settings.selectedProfileId || "";
}

function renderSoundPickers() {
  for (const id of ["rewriteDoneSound", "fileSavedSound"]) {
    const sel = $(id);
    sel.innerHTML = "";
    for (const s of SYSTEM_SOUNDS) sel.add(new Option(cap(s), s));
    for (const c of state.customSounds) sel.add(new Option(c + " (custom)", c));
    sel.value = state.settings[id] || "default";
  }
}

function renderProfilesList() {
  const wrap = $("profileList");
  wrap.innerHTML = "";
  (state.settings.profiles || []).forEach((p, i) => {
    const div = document.createElement("div");
    div.className = "profile-item";
    div.innerHTML = `
      <div class="row">
        <input type="text" class="pname" value="${esc(p.name)}" placeholder="Profile name" />
        <button class="pdel">Delete</button>
      </div>
      <textarea class="pprompt" placeholder="Extra instructions sent with every rewrite while this profile is active">${esc(p.prompt)}</textarea>`;
    div.querySelector(".pname").addEventListener("input", (e) => updateProfile(i, { name: e.target.value }));
    div.querySelector(".pprompt").addEventListener("input", (e) => updateProfile(i, { prompt: e.target.value }));
    div.querySelector(".pdel").addEventListener("click", () => { state.settings.profiles.splice(i, 1); persistProfiles(); renderProfilesList(); renderProfilesDropdown(); });
    wrap.appendChild(div);
  });
}

function updateProfile(i, patch) {
  Object.assign(state.settings.profiles[i], patch);
  persistProfiles();
  renderProfilesDropdown();
}
function persistProfiles() { window.api.setSettings({ profiles: state.settings.profiles }); }

// ---------- actions ----------

function wire() {
  $("settingsBtn").onclick = () => $("settings").classList.remove("hidden");
  $("bannerSettings").onclick = () => $("settings").classList.remove("hidden");
  $("settingsClose").onclick = () => $("settings").classList.add("hidden");
  $("quitBtn").onclick = () => window.api.hideWindow();

  $("input").addEventListener("input", () => {
    state.sourceName = null; state.sourcePath = null;
    updateInputMeta();
  });

  $("humanizeBtn").onclick = humanize;
  $("clipboardBtn").onclick = humanizeClipboard;
  $("openFileBtn").onclick = openFile;
  $("cancelBtn").onclick = () => window.api.cancelHumanize();
  $("refineBtn").onclick = refine;
  $("feedback").addEventListener("keydown", (e) => { if (e.key === "Enter") refine(); });
  $("copyBtn").onclick = () => window.api.writeClipboard($("output").value);
  $("saveBtn").onclick = saveFile;
  $("teachBtn").onclick = teach;

  // Settings
  $("saveKeyBtn").onclick = async () => {
    const v = $("apiKey").value.trim();
    state.hasKey = await window.api.saveKey(v);
    $("keyStatus").textContent = state.hasKey ? "Key saved ✓" : "";
    $("keyStatus").className = "muted small" + (state.hasKey ? " ok" : "");
    $("keyBanner").classList.toggle("hidden", state.hasKey);
  };
  $("model").onchange = (e) => { state.settings.model = e.target.value; window.api.setSettings({ model: e.target.value }); };
  $("profile").onchange = (e) => { state.settings.selectedProfileId = e.target.value || null; window.api.setSettings({ selectedProfileId: state.settings.selectedProfileId }); };
  $("chooseFolderBtn").onclick = async () => { const f = await window.api.chooseFolder(); if (f !== null) { state.settings.outputFolder = f; $("outputFolder").value = f; } };
  $("clearFolderBtn").onclick = async () => { await window.api.clearFolder(); state.settings.outputFolder = ""; $("outputFolder").value = ""; };
  $("importSoundBtn").onclick = async () => { const list = await window.api.importSound(); if (list) { state.customSounds = list; renderSoundPickers(); } };
  $("addProfileBtn").onclick = () => { state.settings.profiles.push({ id: "p" + Date.now(), name: "New Profile", prompt: "" }); persistProfiles(); renderProfilesList(); renderProfilesDropdown(); };
  $("voiceSample").addEventListener("input", (e) => window.api.setStyle({ voiceSample: e.target.value }));
  $("styleProfile").addEventListener("input", (e) => window.api.setStyle({ styleProfile: e.target.value }));

  for (const id of ["rewriteDoneSound", "fileSavedSound"]) {
    $(id).onchange = (e) => { state.settings[id] = e.target.value; window.api.setSettings({ [id]: e.target.value }); };
  }
  document.querySelectorAll(".preview").forEach((b) => {
    b.onclick = () => window.api.previewSound($(b.dataset.for).value);
  });

  for (const a of document.querySelectorAll("a")) a.onclick = (e) => { e.preventDefault(); window.api.openExternal(a.href); };

  // Settings tabs
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.onclick = () => {
      document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t === tab));
      const name = tab.dataset.tab;
      document.querySelectorAll(".tab-panel").forEach((p) => p.classList.toggle("hidden", p.dataset.panel !== name));
    };
  });

  setupDrop();
}

function updateInputMeta() {
  const t = $("input").value;
  const words = t.trim() ? t.trim().split(/\s+/).length : 0;
  $("inputMeta").textContent = (state.sourceName ? state.sourceName + " · " : "") + (words ? words + " words" : "");
}

function humanize() {
  const text = $("input").value.trim();
  if (!text) return showError("Nothing to humanize — paste or drop some text first.");
  state.messages = [{ role: "user", content: `Humanize the following text:\n\n${text}` }];
  start("Humanizing…");
}

async function humanizeClipboard() {
  const text = (await window.api.readClipboard() || "").trim();
  if (!text) return showError("Clipboard has no text.");
  $("input").value = text;
  state.sourceName = null; state.sourcePath = null;
  updateInputMeta();
  humanize();
}

async function openFile() {
  const r = await window.api.openFile();
  if (r) handleLoaded(r, true);
}

function refine() {
  const fb = $("feedback").value.trim();
  if (!fb || !$("output").value) return;
  state.messages.push({ role: "assistant", content: $("output").value });
  state.messages.push({ role: "user", content: `Adjust the rewrite based on this feedback, and return the full revised text: ${fb}` });
  $("feedback").value = "";
  start("Adjusting wording…");
}

function start(status) {
  if (!state.hasKey) return showError("No API key set. Add your Anthropic API key in Settings.");
  clearError();
  window.api.startHumanize(state.messages, status);
}

async function saveFile() {
  const r = await window.api.saveOutput({ text: $("output").value, sourceName: state.sourceName, sourcePath: state.sourcePath });
  if (r && r.ok) setStatus("Saved ✓", true);
  else if (r && r.error) showError(r.error);
}

async function teach() {
  setStatus("Updating your style profile…");
  const r = await window.api.teachStyle();
  if (r.ok) { $("styleProfile").value = r.styleProfile; setStatus("Style profile updated ✓", true); }
  else showError(r.error);
}

// ---------- streaming events ----------

function wireIpc() {
  window.api.on("humanize:begin", (status) => {
    state.working = true;
    $("output").value = "";
    setStatus(status);
    toggleWorking(true);
  });
  window.api.on("humanize:delta", (d) => { $("output").value += d; });
  window.api.on("humanize:done", (text) => {
    state.working = false;
    $("output").value = text;
    toggleWorking(false);
    setStatus("Done.");
    window.api.writeClipboard(text);
    if (state.sourceName) saveFile();
  });
  window.api.on("humanize:error", (msg) => { state.working = false; toggleWorking(false); showError(msg); });
  window.api.on("humanize:cancelled", () => { state.working = false; toggleWorking(false); setStatus("Cancelled."); });
  window.api.on("trigger-clipboard", () => humanizeClipboard());
  window.api.on("play-sound", ({ choice, src }) => {
    const p = $("player");
    if (src) { p.src = src; p.play().catch(() => {}); }
    else if (choice && choice !== "default" && choice !== "none") {
      // Built-in tones are synthesized with the Web Audio API.
      beep(choice);
    }
  });
}

function toggleWorking(on) {
  $("spinner").classList.toggle("hidden", !on);
  $("cancelBtn").classList.toggle("hidden", !on);
  $("humanizeBtn").disabled = on;
}

// ---------- file drop ----------

function setupDrop() {
  const overlay = $("dropOverlay");
  let depth = 0;
  window.addEventListener("dragenter", (e) => { e.preventDefault(); depth++; overlay.classList.remove("hidden"); });
  window.addEventListener("dragover", (e) => e.preventDefault());
  window.addEventListener("dragleave", (e) => { e.preventDefault(); if (--depth <= 0) overlay.classList.add("hidden"); });
  window.addEventListener("drop", async (e) => {
    e.preventDefault(); depth = 0; overlay.classList.add("hidden");
    const file = e.dataTransfer.files[0];
    if (!file) return;
    const p = window.api.pathForFile(file);
    const r = await window.api.loadPath(p);
    handleLoaded(r, true);
  });
}

function handleLoaded(r, autoRun) {
  if (!r.ok) return showError(`Couldn't read ${r.name}: ${r.error}`);
  $("input").value = r.text;
  state.sourceName = r.name;
  state.sourcePath = r.sourcePath;
  updateInputMeta();
  setStatus("Loaded " + r.name);
  if (autoRun && state.hasKey) humanize();
}

// ---------- helpers ----------

function setStatus(t, ok) { const s = $("status"); s.textContent = t; s.className = "muted small" + (ok ? " ok" : ""); }
function showError(m) { const e = $("error"); e.textContent = m; e.classList.remove("hidden"); }
function clearError() { $("error").classList.add("hidden"); }
function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
function esc(s) { return (s || "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }

let audioCtx;
function beep(kind) {
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    const tones = { chime: [880, 1320], ding: [1568], pop: [440], bell: [1047, 1568] };
    const seq = tones[kind] || [880];
    seq.forEach((f, i) => {
      const o = audioCtx.createOscillator(), g = audioCtx.createGain();
      o.frequency.value = f; o.type = "sine";
      o.connect(g); g.connect(audioCtx.destination);
      const t = audioCtx.currentTime + i * 0.12;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.3, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.18);
      o.start(t); o.stop(t + 0.2);
    });
  } catch {}
}

boot();

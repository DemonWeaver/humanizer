"use strict";
// Generates assets/icon.png (app/installer) and assets/tray.png from a drawn
// gradient + text→squiggle glyph, then assets/icon.ico for electron-builder.
// Pure Node + canvas-free: we render with a tiny SVG → PNG via sharp? No — keep
// zero heavy deps. Instead draw with node-canvas only if present; otherwise we
// ship pre-made PNGs. To avoid native deps, we hand-build PNGs from SVG using
// the built-in approach below.
const fs = require("fs");
const path = require("path");
const pngToIco = require("png-to-ico");

const assets = path.join(__dirname, "..", "assets");

// A self-contained SVG: gradient rounded square + two machine lines and a
// handwritten wave (the same concept as the macOS menu bar icon).
function svg(size) {
  const s = size;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}" viewBox="0 0 100 100">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ff734d"/><stop offset="0.5" stop-color="#c8389e"/><stop offset="1" stop-color="#6a32c8"/>
  </linearGradient></defs>
  <rect x="8" y="8" width="84" height="84" rx="20" fill="url(#g)"/>
  <g stroke="#fff" stroke-width="5" stroke-linecap="round" fill="none">
    <line x1="26" y1="38" x2="74" y2="38"/>
    <line x1="26" y1="52" x2="66" y2="52"/>
    <path d="M26 66 q8 -10 16 0 t16 0 t16 0"/>
  </g>
</svg>`;
}

async function main() {
  // Write SVGs; convert with the OS if possible, else require sharp.
  const svgPath = path.join(assets, "icon.svg");
  fs.writeFileSync(svgPath, svg(1024));

  let toPng;
  try {
    const sharp = require("sharp");
    toPng = async (out, size) => sharp(Buffer.from(svg(size))).png().toFile(out);
  } catch {
    // Fall back to macOS `qlmanage`/`rsvg`? Keep it simple: require sharp in CI.
    throw new Error("sharp is required to rasterize icons. `npm i -D sharp` (CI installs it).");
  }

  await toPng(path.join(assets, "icon.png"), 512);
  await toPng(path.join(assets, "tray.png"), 32);
  await toPng(path.join(assets, "tray@2x.png"), 64);

  // .ico needs multiple sizes for crisp Windows rendering.
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const tmp = [];
  for (const z of sizes) {
    const p = path.join(assets, `_ico_${z}.png`);
    await toPng(p, z);
    tmp.push(p);
  }
  const ico = await pngToIco(tmp);
  fs.writeFileSync(path.join(assets, "icon.ico"), ico);
  tmp.forEach((p) => fs.unlinkSync(p));
  console.log("icons written");
}

main().catch((e) => { console.error(e.message); process.exit(1); });

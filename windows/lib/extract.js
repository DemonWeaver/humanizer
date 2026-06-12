"use strict";
// Extract plain text from dropped/opened files.
const fs = require("fs");
const path = require("path");

const SUPPORTED = ["txt", "md", "markdown", "text", "docx", "pdf", "rtf"];

async function extractText(filePath) {
  const ext = path.extname(filePath).slice(1).toLowerCase();
  let text;
  switch (ext) {
    case "txt": case "md": case "markdown": case "text": case "":
      text = fs.readFileSync(filePath, "utf8");
      break;
    case "rtf":
      text = stripRtf(fs.readFileSync(filePath, "utf8"));
      break;
    case "docx": {
      const mammoth = require("mammoth");
      const { value } = await mammoth.extractRawText({ path: filePath });
      text = value;
      break;
    }
    case "pdf": {
      // Require the lib entry directly — pdf-parse's index.js runs a debug
      // read of a sample file on import otherwise.
      const pdfParse = require("pdf-parse/lib/pdf-parse.js");
      const data = await pdfParse(fs.readFileSync(filePath));
      text = data.text;
      break;
    }
    default:
      throw new Error(`Unsupported file type: .${ext}. Use txt, md, docx, rtf, or pdf.`);
  }
  text = (text || "").trim();
  if (!text) throw new Error("No text found in the file.");
  return text;
}

// Minimal RTF → text (handles the common control words; good enough for prose).
function stripRtf(rtf) {
  return rtf
    .replace(/\\par[d]?/g, "\n")
    .replace(/\{\\\*?[^{}]+}/g, "")
    .replace(/\\'[0-9a-f]{2}/gi, "")
    .replace(/\\[a-z]+-?\d* ?/gi, "")
    .replace(/[{}]/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

module.exports = { extractText, SUPPORTED };

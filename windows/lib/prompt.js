"use strict";
// Builds the Anthropic system prompt: the bundled humanizer skill (stable,
// cached) followed by per-user volatile blocks.
const fs = require("fs");
const path = require("path");

const skillText = (() => {
  try {
    return fs.readFileSync(path.join(__dirname, "..", "assets", "SKILL.md"), "utf8");
  } catch {
    return "You are a writing editor that removes signs of AI-generated text to make writing sound natural and human. Preserve meaning, rewrite rather than delete, and never use em dashes in the final text.";
  }
})();

const appInstructions = `You are the rewriting engine inside a desktop menu/tray app. Apply the humanizer skill above to the text the user provides. Override the skill's "Process and Output" deliverable: do the draft and the "what still looks AI-generated?" audit silently, and respond with ONLY the final rewritten text. No draft, no audit notes, no summary of changes, no headers, no preamble, no closing remarks. The rewrite must cover everything the original covers. When the user sends follow-up feedback, apply it and again return only the full revised text.`;

const profileUpdaterInstructions = `You maintain a concise personal style-preference profile for a text-humanizing app. Given the current profile and feedback the user gave during a rewrite session, return the updated profile as short markdown bullet points. Merge with the existing profile, deduplicate, and generalize one-off comments into durable preferences (tone, vocabulary, sentence rhythm, formatting, phrasings they like or dislike). Drop anything that was specific to a single document. Respond with ONLY the profile text.`;

function systemBlocks({ voiceSample, styleProfile, customProfilePrompt }) {
  // Stable prefix first; cache breakpoint on the last stable block so the skill
  // + app instructions are cached together. Volatile per-user content follows.
  const blocks = [
    { type: "text", text: skillText },
    { type: "text", text: appInstructions, cache_control: { type: "ephemeral" } },
  ];
  if (voiceSample && voiceSample.trim()) {
    blocks.push({ type: "text", text: `VOICE CALIBRATION SAMPLE — the user's own writing. Match its rhythm, word choice, and quirks in every rewrite:\n\n${voiceSample}` });
  }
  if (styleProfile && styleProfile.trim()) {
    blocks.push({ type: "text", text: `USER STYLE PROFILE — durable preferences learned from past feedback. Always apply these:\n\n${styleProfile}` });
  }
  if (customProfilePrompt && customProfilePrompt.trim()) {
    blocks.push({ type: "text", text: `ACTIVE PROFILE INSTRUCTIONS for this rewrite:\n\n${customProfilePrompt}` });
  }
  return blocks;
}

module.exports = { systemBlocks, appInstructions, profileUpdaterInstructions };

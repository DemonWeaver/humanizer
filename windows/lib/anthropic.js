"use strict";
// Streaming Anthropic Messages API client (no SDK — uses global fetch).

async function streamMessage({ apiKey, model, system, messages, maxTokens = 32000, adaptiveThinking, onText, signal }) {
  const body = {
    model,
    max_tokens: maxTokens,
    stream: true,
    system,
    messages,
  };
  if (adaptiveThinking) body.thinking = { type: "adaptive" };

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!res.ok) {
    let message = `HTTP ${res.status}`;
    try {
      const j = await res.json();
      message = j?.error?.message || message;
    } catch {}
    throw new Error(message);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let full = "";
  let stopReason = null;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop(); // keep trailing partial line
    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const payload = line.slice(6);
      if (payload === "[DONE]") continue;
      let json;
      try { json = JSON.parse(payload); } catch { continue; }
      if (json.type === "content_block_delta" && json.delta?.type === "text_delta") {
        full += json.delta.text;
        onText && onText(json.delta.text);
      } else if (json.type === "message_delta" && json.delta?.stop_reason) {
        stopReason = json.delta.stop_reason;
      } else if (json.type === "error") {
        throw new Error(json.error?.message || "stream error");
      }
    }
  }

  if (stopReason === "refusal") throw new Error("The model declined this request.");
  if (!full) throw new Error("The model returned no text.");
  return full;
}

module.exports = { streamMessage };

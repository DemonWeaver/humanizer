import Foundation

/// Composes the system prompt: the bundled humanizer skill (stable, cached)
/// followed by per-user volatile blocks (voice sample, learned style profile,
/// active custom profile).
enum SkillPrompt {
    /// The bundled SKILL.md from github.com/blader/humanizer.
    static let skillText: String = {
        guard let url = Bundle.main.url(forResource: "SKILL", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "You are a writing editor that removes signs of AI-generated text to make writing sound natural and human. Preserve meaning, rewrite rather than delete, and never use em dashes in the final text."
        }
        return text
    }()

    static let appInstructions = """
    You are the rewriting engine inside a macOS menu bar app. Apply the humanizer \
    skill above to the text the user provides. Override the skill's "Process and \
    Output" deliverable: do the draft and the "what still looks AI-generated?" audit \
    silently, and respond with ONLY the final rewritten text. No draft, no audit \
    notes, no summary of changes, no headers, no preamble, no closing remarks. The \
    rewrite must cover everything the original covers. When the user sends follow-up \
    feedback, apply it and again return only the full revised text.
    """

    static let profileUpdaterInstructions = """
    You maintain a concise personal style-preference profile for a text-humanizing \
    app. Given the current profile and feedback the user gave during a rewrite \
    session, return the updated profile as short markdown bullet points. Merge with \
    the existing profile, deduplicate, and generalize one-off comments into durable \
    preferences (tone, vocabulary, sentence rhythm, formatting, phrasings they like \
    or dislike). Drop anything that was specific to a single document. Respond with \
    ONLY the profile text.
    """

    static func systemBlocks(
        voiceSample: String?,
        styleProfile: String?,
        customProfilePrompt: String?
    ) -> [AnthropicClient.SystemBlock] {
        // Stable prefix first; the cache breakpoint goes on the last stable block
        // so the skill + app instructions are cached together. Volatile per-user
        // content follows the breakpoint.
        var blocks: [AnthropicClient.SystemBlock] = [
            .init(text: skillText),
            .init(text: appInstructions, cached: true),
        ]
        if let voice = voiceSample, !voice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.init(text: "VOICE CALIBRATION SAMPLE — the user's own writing. Match its rhythm, word choice, and quirks in every rewrite:\n\n\(voice)"))
        }
        if let profile = styleProfile, !profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.init(text: "USER STYLE PROFILE — durable preferences learned from past feedback. Always apply these:\n\n\(profile)"))
        }
        if let custom = customProfilePrompt, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.init(text: "ACTIVE PROFILE INSTRUCTIONS for this rewrite:\n\n\(custom)"))
        }
        return blocks
    }
}

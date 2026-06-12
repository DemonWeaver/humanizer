import Foundation

/// Minimal Anthropic Messages API client (streaming SSE).
final class AnthropicClient {
    struct ChatMessage: Codable {
        var role: String
        var content: String
    }

    struct SystemBlock: Encodable {
        var type = "text"
        var text: String
        var cacheControl: CacheControl?

        init(text: String, cached: Bool = false) {
            self.text = text
            self.cacheControl = cached ? CacheControl() : nil
        }

        enum CodingKeys: String, CodingKey {
            case type, text
            case cacheControl = "cache_control"
        }
    }

    struct CacheControl: Encodable {
        var type = "ephemeral"
    }

    struct RequestBody: Encodable {
        var model: String
        var maxTokens: Int
        var stream = true
        var system: [SystemBlock]
        var messages: [ChatMessage]
        var thinking: Thinking?

        init(model: String, maxTokens: Int, system: [SystemBlock], messages: [ChatMessage], adaptiveThinking: Bool) {
            self.model = model
            self.maxTokens = maxTokens
            self.system = system
            self.messages = messages
            self.thinking = adaptiveThinking ? Thinking() : nil
        }

        enum CodingKeys: String, CodingKey {
            case model, stream, system, messages, thinking
            case maxTokens = "max_tokens"
        }
    }

    struct Thinking: Encodable {
        var type = "adaptive"
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        case refusal
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .http(let code, let message):
                return "API error (\(code)): \(message)"
            case .refusal:
                return "The model declined this request."
            case .emptyResponse:
                return "The model returned no text."
            }
        }
    }

    /// Streams a message, invoking `onText` for each text delta.
    /// Returns the accumulated final text.
    func streamMessage(
        apiKey: String,
        body: RequestBody,
        onText: @escaping (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 600
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(0, "No HTTP response")
        }
        if http.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            let message = Self.extractErrorMessage(from: errorBody) ?? errorBody
            throw APIError.http(http.statusCode, message)
        }

        var fullText = ""
        var stopReason: String?

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard payload != "[DONE]",
                  let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            switch type {
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    fullText += text
                    onText(text)
                }
            case "message_delta":
                if let delta = json["delta"] as? [String: Any],
                   let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
            case "error":
                let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown stream error"
                throw APIError.http(200, message)
            default:
                break
            }
        }

        if stopReason == "refusal" { throw APIError.refusal }
        guard !fullText.isEmpty else { throw APIError.emptyResponse }
        return fullText
    }

    private static func extractErrorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }
}

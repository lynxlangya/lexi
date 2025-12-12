//
//  LLMService.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Foundation

enum LLMServiceError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case let .httpError(code, message):
            return "HTTP \(code): \(message)"
        case .missingAPIKey:
            return "API Key is missing."
        }
    }
}

actor LLMService {
    static let shared = LLMService()

    struct Configuration {
        var baseURL: URL
        var apiKey: String
        var model: String
        var systemPrompt: String

        init(
            baseURL: URL,
            apiKey: String,
            model: String,
            systemPrompt: String = "You are a translation assistant. Translate the user's text into Chinese. Preserve markdown formatting."
        ) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
            self.systemPrompt = systemPrompt
        }
    }

    func streamTranslate(
        configuration: Configuration,
        sourceText: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try makeChatCompletionsRequest(configuration: configuration, sourceText: sourceText, stream: true)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw LLMServiceError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let body = try await bytesToString(bytes)
                        throw LLMServiceError.httpError(http.statusCode, body)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedLine.hasPrefix("data:") else { continue }
                        let payload = trimmedLine.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" {
                            break
                        }
                        guard let data = String(payload).data(using: .utf8) else { continue }
                        if let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data),
                           let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func translate(configuration: Configuration, sourceText: String) async throws -> String {
        var result = ""
        for try await token in streamTranslate(configuration: configuration, sourceText: sourceText) {
            result += token
        }
        return result
    }

    private func makeChatCompletionsRequest(
        configuration: Configuration,
        sourceText: String,
        stream: Bool
    ) throws -> URLRequest {
        guard !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMServiceError.missingAPIKey
        }

        var url = configuration.baseURL
        if url.absoluteString.hasSuffix("/") {
            let trimmed = String(url.absoluteString.dropLast())
            url = URL(string: trimmed) ?? url
        }
        // If user provides host only (no /v1), default to OpenAI-compatible /v1 prefix.
        if url.path.isEmpty || url.path == "/" {
            url.appendPathComponent("v1")
        }

        // Allow users to paste full endpoint (e.g. .../chat/completions).
        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !(normalizedPath.hasSuffix("chat/completions") || normalizedPath.hasSuffix("completions")) {
            url.appendPathComponent("chat/completions")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatCompletionRequest(
            model: configuration.model,
            stream: stream,
            messages: [
                .init(role: "system", content: configuration.systemPrompt),
                .init(role: "user", content: sourceText)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func bytesToString(_ bytes: URLSession.AsyncBytes) async throws -> String {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > 64 * 1024 { break }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let stream: Bool
    let messages: [Message]
}

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

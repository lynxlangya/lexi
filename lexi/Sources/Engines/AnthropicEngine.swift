import Foundation

nonisolated struct AnthropicEngine: TranslationEngine {
    private static let minimumMaxTokens = 2_048
    private static let maximumMaxTokens = 8_192

    let apiKey: String
    let baseURL: URL
    let client: EngineHTTPClient

    var id: EngineID { .anthropic }

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        client: EngineHTTPClient = URLSessionEngineHTTPClient()
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    func translate(_ tasks: [TranslationTask], model: String) -> AsyncThrowingStream<TranslationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for (index, translationTask) in tasks.enumerated() {
                        try await streamTask(translationTask, index: index, model: model, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func ping(model: String) async throws -> PingResult {
        do {
            let request = try makeMessageRequest(
                task: .sentence(text: "ping", context: nil),
                model: model,
                stream: false,
                maxTokens: 1
            )
            let (data, response) = try await client.data(for: request)

            if response.isSuccess {
                return .ok
            }

            if response.statusCode == 400 || response.statusCode == 404 {
                return .keyOkModelUnknown
            }

            return .fail(reason: engineErrorReason(from: data))
        } catch {
            return .fail(reason: error.localizedDescription)
        }
    }

    func lookup(_ task: TranslationTask, model: String) async throws -> LookupResult {
        let request = try makeLookupRequest(task: task, model: model)
        let (data, response) = try await client.data(for: request)
        guard response.isSuccess else {
            throw EngineError.httpStatus(response.statusCode, engineErrorReason(from: data))
        }

        let payload = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        guard let toolInput = payload.content.first(where: { $0.type == "tool_use" && $0.name == AnthropicLookupTool.name })?.input else {
            throw EngineError.invalidResponse
        }
        return toolInput
    }

    private func streamTask(
        _ task: TranslationTask,
        index: Int,
        model: String,
        continuation: AsyncThrowingStream<TranslationChunk, Error>.Continuation
    ) async throws {
        var maxTokens = Self.estimatedMaxTokens(for: task)
        var didRetryAfterTokenLimit = false

        while true {
            do {
                let chunks = try await streamTaskChunks(task, model: model, maxTokens: maxTokens)
                for text in chunks {
                    continuation.yield(TranslationChunk(index: index, text: text))
                }
                return
            } catch EngineError.truncatedByTokenLimit where !didRetryAfterTokenLimit && maxTokens < Self.maximumMaxTokens {
                didRetryAfterTokenLimit = true
                maxTokens = min(Self.maximumMaxTokens, maxTokens * 2)
            } catch let error as EngineError {
                throw EngineError.taskFailed(index: index, reason: error.localizedDescription)
            } catch {
                throw EngineError.taskFailed(index: index, reason: error.localizedDescription)
            }
        }
    }

    private func streamTaskChunks(
        _ task: TranslationTask,
        model: String,
        maxTokens: Int
    ) async throws -> [String] {
        do {
            let request = try makeMessageRequest(task: task, model: model, stream: true, maxTokens: maxTokens)
            let (stream, response) = try await client.bytes(for: request)
            guard response.isSuccess else {
                throw EngineError.httpStatus(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
            }

            var parser = SSEParser()
            var sawMessageStop = false
            var stopReason: String?
            var chunks: [String] = []
            for try await data in stream {
                for payload in parser.feed(data) {
                    let event = try SSEParser.anthropicEvent(from: payload)
                    sawMessageStop = sawMessageStop || event.isMessageStop
                    stopReason = event.stopReason ?? stopReason
                    if let text = event.text {
                        chunks.append(text)
                    }
                }
            }

            for payload in parser.finish() {
                let event = try SSEParser.anthropicEvent(from: payload)
                sawMessageStop = sawMessageStop || event.isMessageStop
                stopReason = event.stopReason ?? stopReason
                if let text = event.text {
                    chunks.append(text)
                }
            }

            try validateAnthropicStreamCompletion(sawMessageStop: sawMessageStop, stopReason: stopReason)
            return chunks
        } catch let error as EngineError {
            throw error
        } catch {
            throw error
        }
    }

    private func validateAnthropicStreamCompletion(sawMessageStop: Bool, stopReason: String?) throws {
        guard sawMessageStop else {
            throw EngineError.invalidResponseWithReason("Translation stream ended before message_stop.")
        }

        guard let stopReason else {
            return
        }

        switch stopReason {
        case "end_turn", "stop_sequence":
            return
        case "max_tokens":
            throw EngineError.truncatedByTokenLimit
        default:
            throw EngineError.invalidResponseWithReason("Translation stream stopped with stop_reason=\(stopReason).")
        }
    }

    private func makeMessageRequest(
        task: TranslationTask,
        model: String,
        stream: Bool,
        maxTokens: Int = 2048
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "v1/messages"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AnthropicMessageRequest(
                model: model,
                maxTokens: maxTokens,
                system: Prompts.systemPrompt(for: task),
                messages: anthropicMessages(for: task),
                stream: stream
            )
        )
        return request
    }

    private static func estimatedMaxTokens(for task: TranslationTask) -> Int {
        min(maximumMaxTokens, max(minimumMaxTokens, task.sourceTextForTokenBudget.utf8.count * 3))
    }

    func makeLookupRequest(task: TranslationTask, model: String) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "v1/messages"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AnthropicMessageRequest(
                model: model,
                maxTokens: 1024,
                system: Prompts.systemPrompt(for: task),
                messages: anthropicMessages(for: task),
                stream: false,
                tools: [AnthropicLookupTool.tool],
                toolChoice: AnthropicToolChoice(type: "tool", name: AnthropicLookupTool.name)
            )
        )
        return request
    }

    private func anthropicMessages(for task: TranslationTask) -> [AnthropicMessageRequest.Message] {
        Prompts.conversationMessages(for: task).map {
            .init(role: $0.role, content: $0.content)
        }
    }
}

private extension TranslationTask {
    nonisolated var sourceTextForTokenBudget: String {
        switch self {
        case .paragraph(let text, _), .sentence(let text, _):
            return text
        case .wordLookup(let word, _):
            return word
        case .phraseLookup(let phrase, _):
            return phrase
        case .narrationProfile:
            return ""
        }
    }
}

nonisolated struct AnthropicMessageRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    var model: String
    var maxTokens: Int
    var system: String
    var messages: [Message]
    var stream: Bool
    var tools: [AnthropicTool]?
    var toolChoice: AnthropicToolChoice?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
        case tools
        case toolChoice = "tool_choice"
    }
}

nonisolated struct AnthropicTool: Encodable {
    var name: String
    var description: String
    var inputSchema: JSONValue

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

nonisolated struct AnthropicToolChoice: Encodable {
    var type: String
    var name: String
}

nonisolated enum AnthropicLookupTool {
    static let name = "emit_lookup"
    static let tool = AnthropicTool(
        name: name,
        description: "Emit Lexi's structured dictionary or phrase lookup payload.",
        inputSchema: LookupSchema.schema
    )
}

nonisolated struct AnthropicMessageResponse: Decodable {
    struct Content: Decodable {
        var type: String
        var name: String?
        var input: LookupResult?
    }

    var content: [Content]
}

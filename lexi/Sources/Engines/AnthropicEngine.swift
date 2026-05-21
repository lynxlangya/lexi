import Foundation

nonisolated struct AnthropicEngine: TranslationEngine {
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

    private func streamTask(
        _ task: TranslationTask,
        index: Int,
        model: String,
        continuation: AsyncThrowingStream<TranslationChunk, Error>.Continuation
    ) async throws {
        do {
            let request = try makeMessageRequest(task: task, model: model, stream: true)
            let (stream, response) = try await client.bytes(for: request)
            guard response.isSuccess else {
                throw EngineError.httpStatus(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
            }

            var parser = SSEParser()
            for try await data in stream {
                for payload in parser.feed(data) {
                    if let text = try SSEParser.anthropicText(from: payload) {
                        continuation.yield(TranslationChunk(index: index, text: text))
                    }
                }
            }

            for payload in parser.finish() {
                if let text = try SSEParser.anthropicText(from: payload) {
                    continuation.yield(TranslationChunk(index: index, text: text))
                }
            }
        } catch let error as EngineError {
            throw EngineError.paragraphFailed(index: index, reason: error.localizedDescription)
        } catch {
            throw EngineError.paragraphFailed(index: index, reason: error.localizedDescription)
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
                system: Prompts.translationSystem,
                messages: [
                    .init(role: "user", content: Prompts.translationUserPrompt(for: task)),
                ],
                stream: stream
            )
        )
        return request
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

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }
}

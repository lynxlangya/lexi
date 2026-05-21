import Foundation

nonisolated struct OpenAIEngine: TranslationEngine {
    let apiKey: String
    let baseURL: URL
    let client: EngineHTTPClient

    var id: EngineID { .openai }

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com")!,
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
        var request = URLRequest(url: baseURL.appending(path: "v1/models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await client.data(for: request)
            guard response.isSuccess else {
                return .fail(reason: engineErrorReason(from: data))
            }

            let models = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            return models.data.contains { $0.id == model } ? .ok : .keyOkModelUnknown
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
            let request = try makeTranslateRequest(task: task, model: model)
            let (stream, response) = try await client.bytes(for: request)
            guard response.isSuccess else {
                throw EngineError.httpStatus(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
            }

            var parser = SSEParser()
            for try await data in stream {
                for payload in parser.feed(data) {
                    if let text = try SSEParser.openAIText(from: payload) {
                        continuation.yield(TranslationChunk(index: index, text: text))
                    }
                }
            }

            for payload in parser.finish() {
                if let text = try SSEParser.openAIText(from: payload) {
                    continuation.yield(TranslationChunk(index: index, text: text))
                }
            }
        } catch let error as EngineError {
            throw EngineError.paragraphFailed(index: index, reason: error.localizedDescription)
        } catch {
            throw EngineError.paragraphFailed(index: index, reason: error.localizedDescription)
        }
    }

    private func makeTranslateRequest(task: TranslationTask, model: String) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OpenAIChatRequest(
                model: model,
                messages: [
                    .init(role: "system", content: Prompts.translationSystem),
                    .init(role: "user", content: Prompts.translationUserPrompt(for: task)),
                ],
                stream: true
            )
        )
        return request
    }
}

nonisolated struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    var model: String
    var messages: [Message]
    var stream: Bool
}

nonisolated struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        var id: String
    }

    var data: [Model]
}

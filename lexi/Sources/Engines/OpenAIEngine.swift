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
                LexiLog.engineError("OpenAI models request failed status=\(response.statusCode)")
                return .fail(reason: engineErrorReason(from: data))
            }

            let models = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            return models.data.contains { $0.id == model } ? .ok : .keyOkModelUnknown
        } catch {
            LexiLog.engineError("OpenAI ping failed error=\(String(describing: type(of: error)))")
            return .fail(reason: error.localizedDescription)
        }
    }

    func lookup(_ task: TranslationTask, model: String) async throws -> LookupResult {
        let request = try makeLookupRequest(task: task, model: model, strict: true)
        let (data, response) = try await client.data(for: request)
        guard response.isSuccess else {
            LexiLog.engineError("OpenAI lookup request failed status=\(response.statusCode)")
            throw EngineError.httpStatus(response.statusCode, engineErrorReason(from: data))
        }

        let payload = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = payload.choices.first?.message.content else {
            throw EngineError.invalidResponse
        }
        return try LookupSchema.decode(content)
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
                LexiLog.engineError("OpenAI translation stream failed status=\(response.statusCode)")
                throw EngineError.httpStatus(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
            }

            var parser = SSEParser()
            var sawCompletionMarker = false
            var finishReasons: [String] = []
            for try await data in stream {
                for payload in parser.feed(data) {
                    if try SSEParser.isOpenAITerminalPayload(payload) {
                        sawCompletionMarker = true
                    }
                    finishReasons.append(contentsOf: try SSEParser.openAIFinishReasons(from: payload))
                    if let text = try SSEParser.openAIText(from: payload) {
                        continuation.yield(TranslationChunk(index: index, text: text))
                    }
                }
            }

            for payload in parser.finish() {
                if try SSEParser.isOpenAITerminalPayload(payload) {
                    sawCompletionMarker = true
                }
                finishReasons.append(contentsOf: try SSEParser.openAIFinishReasons(from: payload))
                if let text = try SSEParser.openAIText(from: payload) {
                    continuation.yield(TranslationChunk(index: index, text: text))
                }
            }

            try validateOpenAIStreamCompletion(
                sawCompletionMarker: sawCompletionMarker,
                finishReasons: finishReasons
            )
        } catch let error as EngineError {
            LexiLog.engineError("OpenAI stream task failed error=\(String(describing: type(of: error)))")
            throw EngineError.taskFailed(index: index, reason: error.localizedDescription)
        } catch {
            LexiLog.engineError("OpenAI stream task failed error=\(String(describing: type(of: error)))")
            throw EngineError.taskFailed(index: index, reason: error.localizedDescription)
        }
    }

    private func validateOpenAIStreamCompletion(
        sawCompletionMarker: Bool,
        finishReasons: [String]
    ) throws {
        guard sawCompletionMarker else {
            throw EngineError.invalidResponseWithReason("Translation stream ended before completion marker.")
        }

        let invalidReason = finishReasons.first { reason in
            reason != "stop"
        }
        if let invalidReason {
            throw EngineError.invalidResponseWithReason("Translation stream stopped with finish_reason=\(invalidReason).")
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
                messages: openAIMessages(for: task),
                stream: true
            )
        )
        return request
    }

    func makeLookupRequest(
        task: TranslationTask,
        model: String,
        strict: Bool,
        extraUserMessages: [String] = []
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let messages = openAIMessages(for: task) + extraUserMessages.map {
            OpenAIChatRequest.Message(role: "user", content: $0)
        }
        request.httpBody = try JSONEncoder().encode(
            OpenAIChatRequest(
                model: model,
                messages: messages,
                stream: false,
                responseFormat: strict ? .jsonSchema(name: LookupSchema.name, schema: LookupSchema.schema) : nil
            )
        )
        return request
    }

    private func openAIMessages(for task: TranslationTask) -> [OpenAIChatRequest.Message] {
        [.init(role: "system", content: Prompts.systemPrompt(for: task))]
            + Prompts.conversationMessages(for: task).map {
                .init(role: $0.role, content: $0.content)
            }
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
    var responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case responseFormat = "response_format"
    }

    struct ResponseFormat: Encodable {
        struct JSONSchema: Encodable {
            var name: String
            var strict: Bool
            var schema: JSONValue
        }

        var type: String
        var jsonSchema: JSONSchema

        static func jsonSchema(name: String, schema: JSONValue) -> ResponseFormat {
            ResponseFormat(type: "json_schema", jsonSchema: JSONSchema(name: name, strict: true, schema: schema))
        }

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }
}

nonisolated struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }

        var message: Message
    }

    var choices: [Choice]
}

nonisolated struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        var id: String
    }

    var data: [Model]
}

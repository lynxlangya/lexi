import Foundation

nonisolated struct DeepSeekEngine: TranslationEngine {
    private let openAICompatible: OpenAIEngine

    var id: EngineID { .deepseek }

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        client: EngineHTTPClient = URLSessionEngineHTTPClient()
    ) {
        openAICompatible = OpenAIEngine(apiKey: apiKey, baseURL: baseURL, client: client)
    }

    func translate(_ tasks: [TranslationTask], model: String) -> AsyncThrowingStream<TranslationChunk, Error> {
        openAICompatible.translate(tasks, model: model)
    }

    func lookup(_ task: TranslationTask, model: String) async throws -> LookupResult {
        do {
            return try await lookup(task, model: model, extraUserMessages: [])
        } catch let firstError {
            LexiLog.engineError("DeepSeek lookup first attempt failed error=\(String(describing: type(of: firstError)))")
            do {
                return try await lookup(
                    task,
                    model: model,
                    extraUserMessages: [Self.lookupRetryInstruction]
                )
            } catch {
                LexiLog.engineError("DeepSeek lookup retry failed error=\(String(describing: type(of: error)))")
                throw EngineError.invalidResponseWithReason(
                    "DeepSeek lookup failed after retry. First error: \(firstError.localizedDescription). Retry error: \(error.localizedDescription)"
                )
            }
        }
    }

    func ping(model: String) async throws -> PingResult {
        try await openAICompatible.ping(model: model)
    }

    private func lookup(
        _ task: TranslationTask,
        model: String,
        extraUserMessages: [String]
    ) async throws -> LookupResult {
        let request = try openAICompatible.makeLookupRequest(
            task: task,
            model: model,
            strict: false,
            extraUserMessages: extraUserMessages
        )
        let (data, response) = try await openAICompatible.client.data(for: request)
        guard response.isSuccess else {
            LexiLog.engineError("DeepSeek lookup request failed status=\(response.statusCode)")
            throw EngineError.httpStatus(response.statusCode, engineErrorReason(from: data))
        }

        let payload = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = payload.choices.first?.message.content else {
            throw EngineError.invalidResponse
        }
        return try LookupSchema.decode(content)
    }

    private static let lookupRetryInstruction = """
    Your previous response was not valid JSON conforming to the lookup schema.
    Reply with ONLY a valid JSON object matching the schema. No prose, no Markdown, no code fences.
    """
}

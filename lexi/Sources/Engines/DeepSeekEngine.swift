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
            let request = try openAICompatible.makeLookupRequest(task: task, model: model, strict: false)
            let (data, response) = try await openAICompatible.client.data(for: request)
            guard response.isSuccess else {
                throw EngineError.httpStatus(response.statusCode, engineErrorReason(from: data))
            }

            let payload = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let content = payload.choices.first?.message.content else {
                throw EngineError.invalidResponse
            }
            return try LookupSchema.decode(content)
        } catch {
            let request = try openAICompatible.makeLookupRequest(task: task, model: model, strict: false)
            let (data, response) = try await openAICompatible.client.data(for: request)
            guard response.isSuccess else {
                throw EngineError.httpStatus(response.statusCode, engineErrorReason(from: data))
            }

            let payload = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let content = payload.choices.first?.message.content else {
                throw EngineError.invalidResponse
            }
            return try LookupSchema.decode(content)
        }
    }

    func ping(model: String) async throws -> PingResult {
        try await openAICompatible.ping(model: model)
    }
}

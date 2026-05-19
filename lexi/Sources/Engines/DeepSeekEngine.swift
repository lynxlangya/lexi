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

    func translate(_ paragraphs: [String], model: String) -> AsyncThrowingStream<TranslationChunk, Error> {
        openAICompatible.translate(paragraphs, model: model)
    }

    func ping(model: String) async throws -> PingResult {
        try await openAICompatible.ping(model: model)
    }
}

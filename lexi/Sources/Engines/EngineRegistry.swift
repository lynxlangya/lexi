nonisolated struct EngineRegistry {
    static let shared = EngineRegistry()

    private let client: EngineHTTPClient
    private let apiKeyProvider: @Sendable (EngineID) -> String?

    init(
        client: EngineHTTPClient = URLSessionEngineHTTPClient(),
        apiKeyProvider: @escaping @Sendable (EngineID) -> String? = { engine in
            Keychain.apiKey(for: engine)
        }
    ) {
        self.client = client
        self.apiKeyProvider = apiKeyProvider
    }

    func engine(for config: EngineConfig) throws -> any TranslationEngine {
        guard let apiKey = apiKeyProvider(config.id), !apiKey.isEmpty else {
            throw EngineError.missingAPIKey(config.id)
        }

        switch config.id {
        case .openai:
            return OpenAIEngine(apiKey: apiKey, client: client)
        case .anthropic:
            return AnthropicEngine(apiKey: apiKey, client: client)
        case .deepseek:
            return DeepSeekEngine(apiKey: apiKey, client: client)
        }
    }
}

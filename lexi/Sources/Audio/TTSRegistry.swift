import Foundation

struct TTSRegistry: Sendable {
    static let shared = TTSRegistry()

    private let client: EngineHTTPClient
    private let apiKeyProvider: @Sendable (TTSProviderID) -> String?

    init(
        client: EngineHTTPClient = URLSessionEngineHTTPClient(),
        apiKeyProvider: @escaping @Sendable (TTSProviderID) -> String? = { provider in
            TTSKeychain.apiKey(for: provider)
        }
    ) {
        self.client = client
        self.apiKeyProvider = apiKeyProvider
    }

    func provider(for config: TTSProviderConfig) throws -> any TTSProvider {
        guard let apiKey = apiKeyProvider(config.provider), !apiKey.isEmpty else {
            throw TTSProviderError.missingAPIKey(config.provider)
        }

        switch config.provider {
        case .doubao:
            return DoubaoTTSProvider(apiKey: apiKey, client: client)
        }
    }
}

import CryptoKit
import Foundation

nonisolated enum TTSProviderID: String, Codable, CaseIterable, Sendable {
    case doubao
    case openai

    var displayName: String {
        switch self {
        case .doubao:
            return "豆包语音"
        case .openai:
            return "OpenAI TTS"
        }
    }
}

nonisolated enum TTSAudioLanguage: String, Codable, Sendable {
    case source
    case target
}

nonisolated struct TTSProviderConfig: Codable, Equatable, Sendable {
    var provider: TTSProviderID
    var resourceId: String
    var speaker: String
    var speechRate: Int
    var format: String
    var sampleRate: Int

    static let doubaoDefault = TTSProviderConfig(
        provider: .doubao,
        resourceId: "seed-tts-2.0",
        speaker: "",
        speechRate: 0,
        format: "mp3",
        sampleRate: 24_000
    )

    static let openAIDefault = TTSProviderConfig(
        provider: .openai,
        resourceId: "gpt-4o-mini-tts",
        speaker: "marin",
        speechRate: 0,
        format: "mp3",
        sampleRate: 24_000
    )

    static func defaultConfig(for provider: TTSProviderID) -> TTSProviderConfig {
        switch provider {
        case .doubao:
            return doubaoDefault
        case .openai:
            return openAIDefault
        }
    }
}

nonisolated struct TTSRequest: Equatable, Sendable {
    var text: String
    var config: TTSProviderConfig
    var contextInstruction: String?
    var userId: String
    var requestId: UUID

    init(
        text: String,
        config: TTSProviderConfig,
        contextInstruction: String? = nil,
        userId: String = "lexi-local-user",
        requestId: UUID = UUID()
    ) {
        self.text = text
        self.config = config
        self.contextInstruction = contextInstruction
        self.userId = userId
        self.requestId = requestId
    }
}

nonisolated struct TTSAudioChunk: Equatable, Sendable {
    var data: Data
    var isFinal: Bool
}

nonisolated enum TTSProviderError: Error, Equatable, LocalizedError, Sendable {
    case missingAPIKey(TTSProviderID)
    case missingSpeaker
    case invalidResponse
    case httpStatus(Int, String)
    case providerMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "请先在设置里配置 \(provider.displayName) API Key"
        case .missingSpeaker:
            return "请先配置语音音色"
        case .invalidResponse:
            return "Invalid TTS provider response."
        case .httpStatus(let status, let reason):
            return "HTTP \(status): \(reason)"
        case .providerMessage(let message):
            return message
        }
    }
}

nonisolated protocol TTSProvider: Sendable {
    var id: TTSProviderID { get }

    func streamSpeech(_ request: TTSRequest) -> AsyncThrowingStream<TTSAudioChunk, Error>
    func ping(_ request: TTSRequest) async throws -> Data
}

nonisolated struct TTSAudioCacheKey: Codable, Equatable, Sendable {
    var bookId: String
    var chapterId: Int64?
    var paragraphStart: Int
    var paragraphEnd: Int
    var language: TTSAudioLanguage
    var provider: TTSProviderID
    var resourceId: String
    var speaker: String
    var speechRate: Int
    var profileHash: String
    var textHash: String

    var value: String {
        [
            bookId,
            chapterId.map(String.init) ?? "chapter-none",
            String(paragraphStart),
            String(paragraphEnd),
            language.rawValue,
            provider.rawValue,
            resourceId,
            speaker,
            String(speechRate),
            profileHash,
            textHash,
        ].joined(separator: "|").lexiSHA256
    }

    static func makeTextHash(_ text: String) -> String {
        text.lexiSHA256
    }
}

extension String {
    nonisolated var lexiSHA256: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

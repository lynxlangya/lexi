import Foundation
import XCTest
@testable import lexi

final class AudioTests: XCTestCase {
    func testOpenAIRequestIncludesSpeechPayloadAndInstructions() throws {
        let config = TTSProviderConfig(
            provider: .openai,
            resourceId: "gpt-4o-mini-tts",
            speaker: "marin",
            speechRate: 25,
            format: "mp3",
            sampleRate: 24_000
        )
        let request = try OpenAITTSProvider(apiKey: "openai-key").makeRequest(TTSRequest(
            text: "Hello Lexi.",
            config: config,
            contextInstruction: "Read with a calm nonfiction audiobook tone."
        ))

        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/audio/speech")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer openai-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "gpt-4o-mini-tts")
        XCTAssertEqual(json?["voice"] as? String, "marin")
        XCTAssertEqual(json?["input"] as? String, "Hello Lexi.")
        XCTAssertEqual(json?["response_format"] as? String, "mp3")
        XCTAssertEqual(json?["speed"] as? Double, 1.25)
        XCTAssertEqual(json?["instructions"] as? String, "Read with a calm nonfiction audiobook tone.")
    }

    func testOpenAIRequestRequiresVoice() {
        var config = TTSProviderConfig.openAIDefault
        config.speaker = "   "

        XCTAssertThrowsError(try OpenAITTSProvider(apiKey: "openai-key").makeRequest(TTSRequest(
            text: "Hello Lexi.",
            config: config
        ))) { error in
            XCTAssertEqual(error as? TTSProviderError, .missingSpeaker)
        }
    }

    func testDoubaoRequestIncludesRequiredHeadersAndPayload() throws {
        let config = TTSProviderConfig(
            provider: .doubao,
            resourceId: "seed-tts-2.0",
            speaker: "voice-test",
            speechRate: 10,
            format: "mp3",
            sampleRate: 24_000
        )
        let requestId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let request = try DoubaoTTSProvider(apiKey: "test-key").makeRequest(TTSRequest(
            text: "Hello Lexi.",
            config: config,
            contextInstruction: "Read naturally.",
            requestId: requestId
        ))

        XCTAssertEqual(request.url?.absoluteString, "https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Resource-Id"), "seed-tts-2.0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Request-Id"), requestId.uuidString)

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let params = try XCTUnwrap(json?["req_params"] as? [String: Any])
        XCTAssertEqual(params["text"] as? String, "Hello Lexi.")
        XCTAssertEqual(params["speaker"] as? String, "voice-test")

        let audioParams = try XCTUnwrap(params["audio_params"] as? [String: Any])
        XCTAssertEqual(audioParams["format"] as? String, "mp3")
        XCTAssertEqual(audioParams["sample_rate"] as? Int, 24_000)
        XCTAssertEqual(audioParams["speech_rate"] as? Int, 10)

        let additions = try XCTUnwrap(params["additions"] as? String)
        let additionsData = try XCTUnwrap(additions.data(using: .utf8))
        let additionsJSON = try JSONSerialization.jsonObject(with: additionsData) as? [String: Any]
        XCTAssertEqual(additionsJSON?["context_texts"] as? [String], ["Read naturally."])
    }

    func testDoubaoParserCollectsBase64AudioFromNestedSSEPayload() throws {
        var parser = DoubaoSSEAudioParser()
        let audio = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = audio.base64EncodedString()
        let payload = Data((
            "event: 350\n" +
            "data: {\"result\":{\"audio\":\"\(encoded)\"},\"message\":\"Success\"}\n\n" +
            "event: 152\n" +
            "data: {\"message\":\"Success\"}\n\n"
        ).utf8)

        let splitIndex = payload.count / 2
        XCTAssertEqual(try parser.feed(Data(payload[..<splitIndex])), [])
        let chunks = try parser.feed(Data(payload[splitIndex...])) + parser.finish()

        XCTAssertEqual(chunks.map(\.data), [audio, Data()])
        XCTAssertEqual(chunks.map(\.isFinal), [false, true])
    }

    func testDoubaoParserTreatsErrorEventAsFailure() throws {
        var parser = DoubaoSSEAudioParser()
        let payload = Data((
            "event: 153\n" +
            "data: {\"code\":40000001,\"message\":\"bad speaker\"}\n\n"
        ).utf8)

        XCTAssertThrowsError(try parser.feed(payload)) { error in
            XCTAssertEqual(error as? TTSProviderError, .providerMessage("bad speaker"))
        }
    }

    func testAudioCacheKeyChangesWithTextAndProviderSettings() {
        let base = TTSAudioCacheKey(
            bookId: "book",
            chapterId: 1,
            paragraphStart: 2,
            paragraphEnd: 4,
            language: .source,
            provider: .doubao,
            resourceId: "seed-tts-2.0",
            speaker: "voice",
            speechRate: 0,
            profileHash: "profile",
            textHash: TTSAudioCacheKey.makeTextHash("hello")
        )
        var changedText = base
        changedText.textHash = TTSAudioCacheKey.makeTextHash("hello!")
        var changedSpeaker = base
        changedSpeaker.speaker = "voice-2"
        var changedProvider = base
        changedProvider.provider = .openai
        changedProvider.resourceId = "gpt-4o-mini-tts"
        changedProvider.speaker = "marin"

        XCTAssertEqual(base.value, base.value)
        XCTAssertNotEqual(base.value, changedText.value)
        XCTAssertNotEqual(base.value, changedSpeaker.value)
        XCTAssertNotEqual(base.value, changedProvider.value)
    }

    func testTTSRegistryBuildsDoubaoProviderFromKeyProvider() throws {
        let registry = TTSRegistry(client: AudioMockHTTPClient(), apiKeyProvider: { provider in
            provider == .doubao ? "doubao-key" : nil
        })
        let provider = try registry.provider(for: .doubaoDefault)
        XCTAssertEqual(provider.id, .doubao)
    }

    func testTTSRegistryBuildsOpenAIProviderFromKeyProvider() throws {
        let registry = TTSRegistry(client: AudioMockHTTPClient(), apiKeyProvider: { provider in
            provider == .openai ? "openai-key" : nil
        })
        let provider = try registry.provider(for: .openAIDefault)
        XCTAssertEqual(provider.id, .openai)
    }

    func testTTSRegistryWithoutKeyFails() {
        let registry = TTSRegistry(client: AudioMockHTTPClient(), apiKeyProvider: { _ in nil })
        XCTAssertThrowsError(try registry.provider(for: .doubaoDefault)) { error in
            XCTAssertEqual(error as? TTSProviderError, .missingAPIKey(.doubao))
        }
    }

    func testMissingAPIKeyErrorIsUserFacingChinese() {
        XCTAssertEqual(
            TTSProviderError.missingAPIKey(.doubao).errorDescription,
            "请先在设置里配置 豆包语音 API Key"
        )
        XCTAssertEqual(
            TTSProviderError.missingAPIKey(.openai).errorDescription,
            "请先在设置里配置 OpenAI TTS API Key"
        )
    }

    func testAudioCacheRemoveFilesOnlyDeletesInsideAudioCacheDirectory() throws {
        let cacheFile = try AudioCacheLocation.fileURL(cacheKey: UUID().uuidString, format: "mp3")
        let outsideFile = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-outside.mp3")
        try Data([0x01]).write(to: cacheFile)
        try Data([0x02]).write(to: outsideFile)
        defer {
            try? FileManager.default.removeItem(at: cacheFile)
            try? FileManager.default.removeItem(at: outsideFile)
        }

        AudioCacheLocation.removeFiles(at: [cacheFile, outsideFile])

        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideFile.path))
    }
}

private final class AudioMockHTTPClient: EngineHTTPClient, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw TTSProviderError.invalidResponse
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        throw TTSProviderError.invalidResponse
    }
}

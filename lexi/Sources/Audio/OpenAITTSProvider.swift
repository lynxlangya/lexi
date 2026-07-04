import Foundation

nonisolated struct OpenAITTSProvider: TTSProvider {
    let apiKey: String
    let baseURL: URL
    let client: EngineHTTPClient

    var id: TTSProviderID { .openai }

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com")!,
        client: EngineHTTPClient = URLSessionEngineHTTPClient()
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    func streamSpeech(_ speech: TTSRequest) -> AsyncThrowingStream<TTSAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(speech)
                    let (stream, response) = try await client.bytes(for: request)
                    guard response.isSuccess else {
                        LexiLog.ttsError("OpenAI TTS stream failed status=\(response.statusCode)")
                        throw TTSProviderError.httpStatus(
                            response.statusCode,
                            HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
                        )
                    }

                    for try await data in stream {
                        guard !data.isEmpty else { continue }
                        continuation.yield(TTSAudioChunk(data: data, isFinal: false))
                    }
                    continuation.yield(TTSAudioChunk(data: Data(), isFinal: true))
                    continuation.finish()
                } catch {
                    LexiLog.ttsError("OpenAI TTS stream failed error=\(String(describing: type(of: error)))")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func ping(_ request: TTSRequest) async throws -> Data {
        var audio = Data()
        for try await chunk in streamSpeech(request) {
            audio.append(chunk.data)
        }
        guard !audio.isEmpty else {
            throw TTSProviderError.invalidResponse
        }
        return audio
    }

    func makeRequest(_ speech: TTSRequest) throws -> URLRequest {
        guard !speech.config.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TTSProviderError.missingSpeaker
        }

        var request = URLRequest(url: baseURL.appending(path: "v1/audio/speech"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAITTSRequestPayload(speech))
        return request
    }
}

private nonisolated struct OpenAITTSRequestPayload: Encodable {
    var model: String
    var input: String
    var voice: String
    var instructions: String?
    var responseFormat: String
    var speed: Double

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case voice
        case instructions
        case responseFormat = "response_format"
        case speed
    }

    init(_ speech: TTSRequest) {
        model = speech.config.resourceId
        input = speech.text
        voice = speech.config.speaker
        responseFormat = speech.config.format
        instructions = Self.nonEmptyTrimmed(speech.contextInstruction)
        speed = Self.openAISpeed(from: speech.config.speechRate)
    }

    private static func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func openAISpeed(from lexiSpeechRate: Int) -> Double {
        let speed = 1 + (Double(lexiSpeechRate) / 100)
        return min(4.0, max(0.25, speed))
    }
}

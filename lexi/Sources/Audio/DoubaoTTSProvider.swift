import Foundation

nonisolated struct DoubaoTTSProvider: TTSProvider {
    let apiKey: String
    let baseURL: URL
    let client: EngineHTTPClient

    var id: TTSProviderID { .doubao }

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://openspeech.bytedance.com")!,
        client: EngineHTTPClient = URLSessionEngineHTTPClient()
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    func streamSpeech(_ request: TTSRequest) -> AsyncThrowingStream<TTSAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeRequest(request)
                    let (stream, response) = try await client.bytes(for: urlRequest)
                    guard response.isSuccess else {
                        LexiLog.ttsError("Doubao TTS stream failed status=\(response.statusCode)")
                        throw TTSProviderError.httpStatus(
                            response.statusCode,
                            HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
                        )
                    }

                    var parser = DoubaoSSEAudioParser()
                    for try await data in stream {
                        for chunk in try parser.feed(data) {
                            continuation.yield(chunk)
                        }
                    }
                    for chunk in try parser.finish() {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    LexiLog.ttsError("Doubao TTS stream failed error=\(String(describing: type(of: error)))")
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

        var request = URLRequest(url: baseURL.appending(path: "api/v3/tts/unidirectional/sse"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(speech.config.resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(speech.requestId.uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DoubaoTTSRequestPayload(speech))
        return request
    }
}

nonisolated struct DoubaoSSEAudioParser {
    private var buffer = Data()

    mutating func feed(_ data: Data) throws -> [TTSAudioChunk] {
        buffer.append(data)
        return try drainCompleteEvents()
    }

    mutating func finish() throws -> [TTSAudioChunk] {
        guard !buffer.isEmpty else {
            return []
        }
        defer { buffer.removeAll(keepingCapacity: true) }
        guard let event = String(data: buffer, encoding: .utf8) else {
            throw TTSProviderError.invalidResponse
        }
        return try [Self.audioChunk(from: event)].compactMap { $0 }
    }

    private mutating func drainCompleteEvents() throws -> [TTSAudioChunk] {
        var chunks: [TTSAudioChunk] = []
        while let range = buffer.lexiSSEEventDelimiterRange {
            let eventData = Data(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            guard !eventData.isEmpty else {
                continue
            }
            guard let event = String(data: eventData, encoding: .utf8) else {
                throw TTSProviderError.invalidResponse
            }
            if let chunk = try Self.audioChunk(from: event) {
                chunks.append(chunk)
            }
        }
        return chunks
    }

    private static func audioChunk(from event: String) throws -> TTSAudioChunk? {
        let fields = Self.fields(from: event)
        let eventCode = fields.event
        let payload = fields.data.joined(separator: "\n")

        if payload == "[DONE]" || eventCode == "152" {
            return TTSAudioChunk(data: Data(), isFinal: true)
        }
        if eventCode == "151" {
            throw TTSProviderError.providerMessage("豆包语音合成已取消")
        }

        guard let data = payload.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let encoded = Self.firstAudioString(in: json),
              let audio = Data(base64Encoded: encoded),
              !audio.isEmpty else {
            if eventCode == "153" || Self.hasFailureCode(json) {
                throw TTSProviderError.providerMessage(Self.errorMessage(from: json))
            }
            return nil
        }

        let isFinal = (json["is_final"] as? Bool)
            ?? (json["done"] as? Bool)
            ?? Self.isDoneEvent(json["event"])
        return TTSAudioChunk(data: audio, isFinal: isFinal)
    }

    private static func fields(from event: String) -> (event: String?, data: [String]) {
        var eventName: String?
        var dataLines: [String] = []
        for line in event.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("event:") {
                eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces))
            }
        }
        return (eventName, dataLines)
    }

    private static func hasFailureCode(_ json: [String: Any]) -> Bool {
        for key in ["code", "status_code", "statusCode"] {
            if let intValue = json[key] as? Int {
                return !Self.successCodes.contains(intValue)
            }
            if let stringValue = json[key] as? String, let intValue = Int(stringValue) {
                return !Self.successCodes.contains(intValue)
            }
        }
        return false
    }

    private static let successCodes: Set<Int> = [0, 20000000]

    private static func errorMessage(from json: [String: Any]) -> String {
        for key in ["message", "error", "status_text", "statusText"] {
            if let message = json[key] as? String, !message.isEmpty {
                return message
            }
        }
        return "豆包语音合成失败"
    }

    private static func isDoneEvent(_ value: Any?) -> Bool {
        guard let string = value as? String else {
            return false
        }
        return string == "done" || string == "final"
    }

    private static func firstAudioString(in value: Any) -> String? {
        if value is String {
            return nil
        }

        if let dictionary = value as? [String: Any] {
            for key in ["audio", "data", "binary", "payload"] {
                if let candidate = dictionary[key] as? String,
                   Data(base64Encoded: candidate) != nil {
                    return candidate
                }
            }
            for child in dictionary.values {
                if let found = firstAudioString(in: child) {
                    return found
                }
            }
        }

        if let array = value as? [Any] {
            for child in array {
                if let found = firstAudioString(in: child) {
                    return found
                }
            }
        }

        return nil
    }
}

private extension Data {
    nonisolated var lexiSSEEventDelimiterRange: Range<Data.Index>? {
        if let range = range(of: Data("\n\n".utf8)) {
            return range
        }
        if let range = range(of: Data("\r\n\r\n".utf8)) {
            return range
        }
        return nil
    }
}

private nonisolated struct DoubaoTTSRequestPayload: Encodable {
    struct User: Encodable {
        var uid: String
    }

    struct RequestParams: Encodable {
        struct AudioParams: Encodable {
            var format: String
            var sample_rate: Int
            var speech_rate: Int
        }

        var text: String
        var speaker: String
        var audio_params: AudioParams
        var additions: String?
    }

    var user: User
    var req_params: RequestParams

    init(_ speech: TTSRequest) {
        user = User(uid: speech.userId)
        req_params = RequestParams(
            text: speech.text,
            speaker: speech.config.speaker,
            audio_params: RequestParams.AudioParams(
                format: speech.config.format,
                sample_rate: speech.config.sampleRate,
                speech_rate: speech.config.speechRate
            ),
            additions: Self.additionsJSON(from: speech.contextInstruction)
        )
    }

    private static func additionsJSON(from instruction: String?) -> String? {
        guard let trimmed = instruction?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let payload = AdditionsPayload(context_texts: [trimmed])
        guard let data = try? JSONEncoder().encode(payload) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private struct AdditionsPayload: Encodable {
        var context_texts: [String]
    }
}

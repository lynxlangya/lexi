import Foundation

nonisolated struct SSEParser {
    private var buffer = Data()
    private static let decoder = JSONDecoder()

    struct OpenAIEventSummary {
        var text: String?
        var finishReasons: [String]
        var isTerminal: Bool
    }

    struct AnthropicEventSummary {
        var text: String?
        var stopReason: String?
        var isMessageStop: Bool
    }

    mutating func feed(_ data: Data) -> [String] {
        buffer.append(data)

        var payloads: [String] = []
        while let range = nextEventRange() {
            let block = buffer[..<range.lowerBound]
            buffer.removeSubrange(..<range.upperBound)

            if let payload = payload(from: block) {
                payloads.append(payload)
            }
        }

        return payloads
    }

    mutating func finish() -> [String] {
        guard !buffer.isEmpty else {
            return []
        }

        defer {
            buffer.removeAll()
        }

        return payload(from: buffer).map { [$0] } ?? []
    }

    static func openAIText(from payload: String) throws -> String? {
        try openAIEvent(from: payload).text
    }

    static func isOpenAITerminalPayload(_ payload: String) throws -> Bool {
        try openAIEvent(from: payload).isTerminal
    }

    static func openAIFinishReasons(from payload: String) throws -> [String] {
        try openAIEvent(from: payload).finishReasons
    }

    static func openAIEvent(from payload: String) throws -> OpenAIEventSummary {
        guard payload != "[DONE]" else {
            return OpenAIEventSummary(text: nil, finishReasons: [], isTerminal: true)
        }

        let chunk = try decoder.decode(OpenAIStreamPayload.self, from: Data(payload.utf8))
        let text = chunk.choices.compactMap(\.delta.content).joined()
        return OpenAIEventSummary(
            text: text.isEmpty ? nil : text,
            finishReasons: chunk.choices.compactMap(\.finishReason),
            isTerminal: chunk.choices.contains { $0.finishReason != nil }
        )
    }

    static func anthropicText(from payload: String) throws -> String? {
        try anthropicEvent(from: payload).text
    }

    static func isAnthropicMessageStop(from payload: String) throws -> Bool {
        try anthropicEvent(from: payload).isMessageStop
    }

    static func anthropicStopReason(from payload: String) throws -> String? {
        try anthropicEvent(from: payload).stopReason
    }

    static func anthropicEvent(from payload: String) throws -> AnthropicEventSummary {
        let chunk = try decoder.decode(AnthropicStreamPayload.self, from: Data(payload.utf8))
        return AnthropicEventSummary(
            text: chunk.type == "content_block_delta" ? chunk.delta?.text : nil,
            stopReason: chunk.delta?.stopReason,
            isMessageStop: chunk.type == "message_stop"
        )
    }

    private func nextEventRange() -> Range<Data.Index>? {
        let lfRange = buffer.range(of: Data([0x0A, 0x0A]))
        let crlfRange = buffer.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A]))

        switch (lfRange, crlfRange) {
        case (.some(let lf), .some(let crlf)):
            return lf.lowerBound < crlf.lowerBound ? lf : crlf
        case (.some(let lf), .none):
            return lf
        case (.none, .some(let crlf)):
            return crlf
        case (.none, .none):
            return nil
        }
    }

    private func payload(from block: Data) -> String? {
        let payload = String(decoding: block, as: UTF8.self)
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard line.hasPrefix("data:") else {
                    return nil
                }
                return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")

        return payload.isEmpty ? nil : payload
    }
}

nonisolated private struct OpenAIStreamPayload: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            var content: String?
        }

        var delta: Delta
        var finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    var choices: [Choice]
}

nonisolated private struct AnthropicStreamPayload: Decodable {
    struct Delta: Decodable {
        var text: String?
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case text
            case stopReason = "stop_reason"
        }
    }

    var type: String
    var delta: Delta?
}

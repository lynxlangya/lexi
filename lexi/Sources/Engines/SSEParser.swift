import Foundation

nonisolated struct SSEParser {
    private var buffer = Data()

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
        guard payload != "[DONE]" else {
            return nil
        }

        let chunk = try JSONDecoder().decode(OpenAIStreamPayload.self, from: Data(payload.utf8))
        let text = chunk.choices.compactMap(\.delta.content).joined()
        return text.isEmpty ? nil : text
    }

    static func isOpenAITerminalPayload(_ payload: String) throws -> Bool {
        guard payload != "[DONE]" else {
            return true
        }

        let chunk = try JSONDecoder().decode(OpenAIStreamPayload.self, from: Data(payload.utf8))
        return chunk.choices.contains { $0.finishReason != nil }
    }

    static func openAIFinishReasons(from payload: String) throws -> [String] {
        guard payload != "[DONE]" else {
            return []
        }

        let chunk = try JSONDecoder().decode(OpenAIStreamPayload.self, from: Data(payload.utf8))
        return chunk.choices.compactMap(\.finishReason)
    }

    static func anthropicText(from payload: String) throws -> String? {
        guard payload != "[DONE]" else {
            return nil
        }

        let chunk = try JSONDecoder().decode(AnthropicStreamPayload.self, from: Data(payload.utf8))
        guard chunk.type == "content_block_delta" else {
            return nil
        }
        return chunk.delta?.text
    }

    static func isAnthropicMessageStop(from payload: String) throws -> Bool {
        let chunk = try JSONDecoder().decode(AnthropicStreamPayload.self, from: Data(payload.utf8))
        return chunk.type == "message_stop"
    }

    static func anthropicStopReason(from payload: String) throws -> String? {
        let chunk = try JSONDecoder().decode(AnthropicStreamPayload.self, from: Data(payload.utf8))
        return chunk.delta?.stopReason
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

import Foundation

nonisolated enum LookupSchema {
    static let name = "lookup"

    static let schema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("senses"),
            .string("contextualMeaning"),
            .string("synonyms"),
            .string("example"),
        ]),
        "properties": .object([
            "senses": .object([
                "type": .string("array"),
                "minItems": .number(1),
                "maxItems": .number(4),
                "items": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "required": .array([.string("pos"), .string("zh")]),
                    "properties": .object([
                        "pos": .object([
                            "type": .string("string"),
                            "enum": .array(LookupPartOfSpeech.allCases.map { .string($0.rawValue) }),
                        ]),
                        "zh": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                ]),
            ]),
            "contextualMeaning": nullableString(
                description: "Meaning specific to the surrounding sentence, or null when no surrounding sentence was provided."
            ),
            "synonyms": .object([
                "type": .array([.string("array"), .string("null")]),
                "items": .object(["type": .string("string")]),
                "maxItems": .number(3),
            ]),
            "example": .object([
                "type": .array([.string("object"), .string("null")]),
                "additionalProperties": .bool(false),
                "required": .array([.string("en"), .string("zh")]),
                "properties": .object([
                    "en": nullableString(),
                    "zh": nullableString(),
                ]),
            ]),
        ]),
    ])

    static func decode(_ data: Data) throws -> LookupResult {
        let result = try JSONDecoder().decode(LookupResult.self, from: data)
        guard !result.senses.isEmpty else {
            throw EngineError.invalidResponse
        }
        return result
    }

    static func decode(_ text: String) throws -> LookupResult {
        try decode(Data(extractJSONObject(from: text).utf8))
    }

    private static func nullableString(description: String? = nil) -> JSONValue {
        var object: [String: JSONValue] = [
            "type": .array([.string("string"), .string("null")]),
        ]
        if let description {
            object["description"] = .string(description)
        }
        return .object(object)
    }

    private static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("{"),
              let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start < end else {
            return trimmed
        }
        return String(trimmed[start...end])
    }
}

nonisolated enum JSONValue: Encodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }
}

import Foundation

struct VocabSnapshot: Equatable, Sendable {
    var primaryZh: String
    var sensesJSON: String
    var ukIPA: String?
    var usIPA: String?
    var exampleEN: String?
    var exampleZH: String?

    static func make(word: String, lookup: LookupResult, localEntry: LocalDictionaryEntry?) -> VocabSnapshot {
        let sensesJSON = (try? String(data: JSONEncoder().encode(lookup.senses), encoding: .utf8)) ?? "[]"
        return VocabSnapshot(
            primaryZh: lookup.primaryZh(fallback: word),
            sensesJSON: sensesJSON,
            ukIPA: localEntry?.ukIPA,
            usIPA: localEntry?.usIPA,
            exampleEN: lookup.example?.en,
            exampleZH: lookup.example?.zh
        )
    }
}

extension LookupResult {
    func primaryZh(fallback word: String) -> String {
        let contextual = contextualMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let contextual, !contextual.isEmpty {
            return contextual
        }

        let sense = senses.first?.zh.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sense, !sense.isEmpty {
            return sense
        }

        return word
    }
}

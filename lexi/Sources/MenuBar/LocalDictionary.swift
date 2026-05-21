import CoreServices
import Foundation

nonisolated struct LocalDictionaryEntry: Equatable, Sendable {
    var ukIPA: String?
    var usIPA: String?
    var partsOfSpeech: [String]
    var rawDefinition: String?
}

nonisolated enum LocalDictionary {
    typealias DefinitionProvider = @Sendable (_ word: String) -> String?

    static func lookup(_ word: String) -> LocalDictionaryEntry? {
        lookup(word, definitionProvider: systemDefinition)
    }

    static func lookup(
        _ word: String,
        definitionProvider: DefinitionProvider
    ) -> LocalDictionaryEntry? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              let raw = definitionProvider(normalized),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let ipa = extractIPA(from: raw)
        return LocalDictionaryEntry(
            ukIPA: ipa.first,
            usIPA: ipa.dropFirst().first ?? ipa.first,
            partsOfSpeech: extractPartsOfSpeech(from: raw),
            rawDefinition: raw
        )
    }

    private static func systemDefinition(for word: String) -> String? {
        let cfWord = word as CFString
        let range = CFRange(location: 0, length: CFStringGetLength(cfWord))
        guard let definition = DCSCopyTextDefinition(nil, cfWord, range)?.takeRetainedValue() else {
            return nil
        }
        return definition as String
    }

    private static func extractIPA(from text: String) -> [String] {
        let pattern = "[|/][A-Za-z\u{0250}-\u{02AF}ˈˌː.ˑ -]+[|/]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else {
                return nil
            }
            return String(text[swiftRange])
                .replacingOccurrences(of: "|", with: "/")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func extractPartsOfSpeech(from text: String) -> [String] {
        let mapping: [(pattern: String, label: String)] = [
            (#"\bpronoun\b"#, "pron."),
            (#"\bpreposition\b"#, "prep."),
            (#"\bconjunction\b"#, "conj."),
            (#"\badjective\b"#, "adj."),
            (#"\badverb\b"#, "adv."),
            (#"\bnoun\b"#, "n."),
            (#"\bverb\b"#, "v."),
        ]
        let lowercased = text.lowercased()
        let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
        var seen = Set<String>()
        var result: [String] = []

        for (pattern, label) in mapping {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  regex.firstMatch(in: lowercased, range: range) != nil,
                  !seen.contains(label) else {
                continue
            }
            seen.insert(label)
            result.append(label)
        }
        return result
    }
}

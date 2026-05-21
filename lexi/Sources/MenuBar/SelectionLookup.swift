import Foundation

enum SelectionLookupClassifier {
    static func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canTranslate(_ text: String) -> Bool {
        normalizedText(text).count >= 2
    }

    static func isWord(_ text: String) -> Bool {
        let trimmed = normalizedText(text)
        guard trimmed.split(whereSeparator: { $0.isWhitespace }).count == 1 else {
            return false
        }

        return trimmed.range(of: #"^[a-zA-Z'\u{2019}-]+$"#, options: .regularExpression) != nil
    }
}

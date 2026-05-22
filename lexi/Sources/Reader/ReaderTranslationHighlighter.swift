import Foundation

enum ReaderTranslationHighlighter {
    static func targetRange(
        sourceText: String,
        selectedText: String,
        translatedText: String
    ) -> Range<String.Index>? {
        let selection = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard selection.count >= 2,
              !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let acronymRange = acronymMatchRange(selectedText: selection, in: translatedText) {
            return acronymRange
        }

        if isLikelySentence(selection),
           let sentenceRange = sentenceMatchRange(
               sourceText: sourceText,
               selectedText: selection,
               translatedText: translatedText
           ) {
            return sentenceRange
        }

        if let literalRange = translatedText.range(of: selection, options: [.caseInsensitive, .diacriticInsensitive]),
           isHighConfidenceLiteral(selection) {
            return literalRange
        }

        return nil
    }

    private static func acronymMatchRange(selectedText: String, in translatedText: String) -> Range<String.Index>? {
        for acronym in acronyms(from: selectedText) {
            guard acronym.count >= 2,
                  let acronymRange = translatedText.range(of: acronym, options: [.caseInsensitive, .diacriticInsensitive]) else {
                continue
            }

            return expandedTermRange(around: acronymRange, in: translatedText)
        }

        return nil
    }

    private static func acronyms(from text: String) -> [String] {
        var results: [String] = []
        let parentheticalPattern = #"\(([A-Za-z]{2,})s?\)"#
        if let regex = try? NSRegularExpression(pattern: parentheticalPattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: nsRange) {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: text) else {
                    continue
                }
                results.append(String(text[range]).dropTrailingPluralS().uppercased())
            }
        }

        let tokens = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for token in tokens where token.count >= 2 && token.allSatisfy(\.isUppercaseLetter) {
            results.append(String(token.dropTrailingPluralS()).uppercased())
        }

        let initialism = tokens
            .filter { $0.count > 2 }
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
        if initialism.count >= 2 {
            results.append(initialism)
        }

        var seen: Set<String> = []
        return results.filter { seen.insert($0).inserted }
    }

    private static func expandedTermRange(
        around acronymRange: Range<String.Index>,
        in text: String
    ) -> Range<String.Index> {
        var lower = acronymRange.lowerBound
        while lower > text.startIndex {
            let previous = text.index(before: lower)
            guard shouldExtendTermLeft(text[previous]) else {
                break
            }
            lower = previous
        }

        var upper = acronymRange.upperBound
        while upper < text.endIndex {
            let current = text[upper]
            guard shouldExtendTermRight(current) else {
                break
            }
            upper = text.index(after: upper)
        }

        return trimmedLeadingContext(in: lower..<upper, text: text)
    }

    private static func shouldExtendTermLeft(_ character: Character) -> Bool {
        character.isCJK || character.isWhitespace || "（(".contains(character)
    }

    private static func shouldExtendTermRight(_ character: Character) -> Bool {
        character.isWhitespace || "）)sS".contains(character)
    }

    private static func trimmedLeadingContext(
        in range: Range<String.Index>,
        text: String
    ) -> Range<String.Index> {
        let leadingContexts = ["这个", "该", "此", "这种", "这些", "那个"]
        let fragment = String(text[range])
        guard let prefix = leadingContexts.first(where: { fragment.hasPrefix($0) }) else {
            return range
        }

        let lower = text.index(range.lowerBound, offsetBy: prefix.count)
        return lower..<range.upperBound
    }

    private static func sentenceMatchRange(
        sourceText: String,
        selectedText: String,
        translatedText: String
    ) -> Range<String.Index>? {
        let sourceSentences = sentenceRanges(in: sourceText)
        let translatedSentences = sentenceRanges(in: translatedText)
        guard !sourceSentences.isEmpty, !translatedSentences.isEmpty else {
            return nil
        }

        guard let selectedRange = sourceText.range(
            of: selectedText,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) else {
            return nil
        }

        let selectedOffset = sourceText.distance(from: sourceText.startIndex, to: selectedRange.lowerBound)
        guard let sourceIndex = sourceSentences.firstIndex(where: { range in
            range.contains(selectedRange.lowerBound) || range.contains(sourceText.index(before: selectedRange.upperBound))
        }) else {
            return nil
        }

        if translatedSentences.indices.contains(sourceIndex) {
            return translatedSentences[sourceIndex]
        }

        let ratio = Double(selectedOffset) / Double(max(sourceText.count, 1))
        let estimatedIndex = min(
            translatedSentences.count - 1,
            max(0, Int((ratio * Double(translatedSentences.count)).rounded(.down)))
        )
        return translatedSentences[estimatedIndex]
    }

    private static func sentenceRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if ".!?。！？；;".contains(character) {
                let range = trimmedRange(start..<next, in: text)
                if !range.isEmpty {
                    ranges.append(range)
                }
                start = next
            }
            index = next
        }

        let tail = trimmedRange(start..<text.endIndex, in: text)
        if !tail.isEmpty {
            ranges.append(tail)
        }
        return ranges
    }

    private static func trimmedRange(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var lower = range.lowerBound
        var upper = range.upperBound

        while lower < upper, text[lower].isWhitespace {
            lower = text.index(after: lower)
        }
        while lower < upper {
            let previous = text.index(before: upper)
            guard text[previous].isWhitespace else {
                break
            }
            upper = previous
        }

        return lower..<upper
    }

    private static func isLikelySentence(_ text: String) -> Bool {
        text.count >= 40 || text.contains(where: { ".!?。！？；;".contains($0) })
    }

    private static func isHighConfidenceLiteral(_ text: String) -> Bool {
        text.contains(where: { !$0.isLetter && !$0.isNumber }) || text.contains(where: \.isUppercaseLetter)
    }
}

private extension Character {
    var isCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    var isUppercaseLetter: Bool {
        String(self).rangeOfCharacter(from: .uppercaseLetters) != nil
    }
}

private extension String {
    func dropTrailingPluralS() -> String {
        guard count > 2, lowercased().hasSuffix("s") else {
            return self
        }
        return String(dropLast())
    }
}

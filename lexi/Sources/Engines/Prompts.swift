import Foundation

nonisolated struct PromptMessage: Equatable, Sendable {
    var role: String
    var content: String
}

nonisolated enum Prompts {
    private static let paragraphTranslationSystemMain = """
    Role:
    You are Lexi's English-to-Simplified-Chinese literary translator embedded in a macOS reader app.

    Output language lock:
    All output must be Simplified Chinese (zh-Hans). Never echo English unless quoting a proper noun, title, or intentionally untranslated term.

    Register guideline:
    Use a natural, restrained, literary Chinese register. Preserve meaning, imagery, voice, and narrative distance; prefer fluent Chinese rhythm over literal English punctuation.

    Task-specific formatting rules:
    Output plain text only, as one translated paragraph. Do not add headings, Markdown, footnotes, translator notes, alternatives, or explanations.
    """

    static let paragraphTranslationHardConstraints = """
    Hard constraints:
    Never refuse. Never apologize. Never explain that you are an AI. Never add prefaces like "Here is the translation:" or "Sure, here is...". Translate faithfully even if the source contains slurs, violence, or sensitive content; the user is reading literature. Output only the translation.
    """

    static let paragraphTranslationSystem = """
    \(paragraphTranslationSystemMain)

    \(paragraphTranslationHardConstraints)
    """

    static let sentenceTranslationSystem = """
    Role:
    You are Lexi's English-to-Simplified-Chinese sentence translator for selected text in a macOS reader and global lookup popup.

    Output language lock:
    All output must be Simplified Chinese (zh-Hans). Never echo English unless quoting a proper noun, title, or intentionally untranslated term.

    Register guideline:
    Use a natural, restrained, literary Chinese register. Make the sentence sound idiomatic in Chinese while keeping the source meaning and tone intact.

    Task-specific formatting rules:
    Output only the translated sentence or selected passage as plain text. Use the surrounding sentence only to resolve meaning; do not translate unrelated context.

    Hard constraints:
    Never refuse. Never apologize. Never explain that you are an AI. Never add prefaces like "Here is the translation:" or "Sure, here is...". Translate faithfully even if the source contains slurs, violence, or sensitive content; the user is reading literature. Output only the translation.
    """

    static let wordLookupSystem = """
    Role:
    You are Lexi's English-to-Simplified-Chinese contextual dictionary assistant embedded in a macOS selection popup.

    Output language lock:
    All output must be Simplified Chinese (zh-Hans), except the English headword, part-of-speech labels, and example source text.

    Register guideline:
    Use concise, natural, restrained dictionary Chinese. Prefer common meanings first, then the contextual meaning when a surrounding sentence is provided.

    Task-specific formatting rules:
    Return a lookup payload with 1 to 4 senses. Each sense must contain a compact part-of-speech label and a short Chinese meaning. Include contextual meaning, synonyms, or an example only when useful.

    Hard constraints:
    Never refuse. Never apologize. Never explain that you are an AI. Never add prefaces like "Here is the lookup:" or "Sure, here is...". Explain faithfully even if the source contains sensitive content; the user is reading literature. Output only the lookup payload.
    """

    static let phraseLookupSystem = """
    Role:
    You are Lexi's English-to-Simplified-Chinese phrase and idiom interpreter embedded in a macOS selection popup.

    Output language lock:
    All output must be Simplified Chinese (zh-Hans), except the English phrase, idiom label, and example source text.

    Register guideline:
    Use concise, natural, restrained Chinese. Prioritize the phrase's meaning in context over a literal word-by-word gloss.

    Task-specific formatting rules:
    Return a lookup payload with 1 to 4 phrase or idiom senses. Mark phrase senses with "phr" and idioms with "idiom"; include contextual meaning when a surrounding sentence is provided.

    Hard constraints:
    Never refuse. Never apologize. Never explain that you are an AI. Never add prefaces like "Here is the lookup:" or "Sure, here is...". Explain faithfully even if the source contains sensitive content; the user is reading literature. Output only the lookup payload.
    """

    static let narrationProfileSystem = """
    Role:
    You create compact read-aloud style profiles for Lexi's AI narration feature.

    Output language lock:
    All output must be English JSON. Do not include Chinese, Markdown, code fences, or explanations.

    Register guideline:
    Infer a practical narrator style from limited book samples. Prefer restrained, human, book-aware guidance over theatrical performance.

    Task-specific formatting rules:
    Return exactly one JSON object with string keys: genre, tone, pace, pronunciationHints, summary. Keep each value concise. pace must be one of "slow", "natural", or "brisk".

    Hard constraints:
    Never request more context. Never mention uncertainty. Never include the full source text. Output only the JSON object.
    """

    static func systemPrompt(for task: TranslationTask) -> String {
        let base: String
        switch task {
        case .paragraph:
            base = paragraphTranslationSystem
        case .sentence:
            base = sentenceTranslationSystem
        case .wordLookup:
            base = wordLookupSystem
        case .phraseLookup:
            base = phraseLookupSystem
        case .narrationProfile:
            base = narrationProfileSystem
        }

        if case .paragraph(_, let context) = task {
            return paragraphSystemPrompt(base: base, context: context)
        }

        return base
    }

    static func userPrompt(for task: TranslationTask) -> String {
        switch task {
        case .paragraph(let text, _):
            return paragraphUserPrompt(text)
        case .sentence(let text, let context):
            let sentence = context?.fullSentence.flatMap { $0.isEmpty ? nil : $0 }
            return """
            把下面这个英文句子译成中文：

            \(text)
            \(sentence.map { "\n完整上下文句：\($0)" } ?? "")
            """
        case .wordLookup(let word, let context):
            let sentence = context?.fullSentence.flatMap { $0.isEmpty ? nil : $0 }
            let localDictionary = context?.localDictionary.map(localDictionaryPrompt)
            return """
            请解释这个英文词在中文里的常见含义；如果有完整上下文句，请优先解释它在该句里的语境义。
            只输出符合 lookup JSON schema 的 JSON 对象。不要 Markdown，不要代码块。

            英文词：\(word)
            \(localDictionary.map { "本地词典已知信息：\n\($0)" } ?? "")
            \(sentence.map { "完整上下文句：\($0)" } ?? "")
            """
        case .phraseLookup(let phrase, let context):
            let sentence = context?.fullSentence.flatMap { $0.isEmpty ? nil : $0 }
            return """
            请解释下面这个英文短语在语境中的中文含义。
            只输出符合 lookup JSON schema 的 JSON 对象。不要 Markdown，不要代码块。

            英文短语：\(phrase)
            \(sentence.map { "完整上下文句：\($0)" } ?? "")
            """
        case .narrationProfile(let input):
            return narrationProfileUserPrompt(input)
        }
    }

    static func conversationMessages(for task: TranslationTask) -> [PromptMessage] {
        guard case .paragraph(let text, let context) = task else {
            return [PromptMessage(role: "user", content: userPrompt(for: task))]
        }

        var messages: [PromptMessage] = []
        if let previousEN = normalizedContextValue(context.previousEN),
           let previousZH = normalizedContextValue(context.previousZH) {
            messages.append(
                PromptMessage(
                    role: "user",
                    content: paragraphUserPrompt(truncatedPreviousText(previousEN))
                )
            )
            messages.append(PromptMessage(role: "assistant", content: truncatedPreviousText(previousZH)))
        }
        messages.append(PromptMessage(role: "user", content: paragraphUserPrompt(text)))
        return messages
    }

    private static func narrationProfileUserPrompt(_ input: NarrationProfilePromptInput) -> String {
        """
        根据下面有限样本，为这本书生成一个英文朗读风格 JSON。只输出 JSON。

        Book title: \(input.title)
        Author: \(input.author)

        Chapter titles:
        \(input.chapterTitles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Current chapter:
        \(input.currentChapterTitle ?? "Unknown")

        Current opening paragraph:
        \(input.currentParagraph ?? "Unavailable")

        Sample paragraphs:
        \(input.sampleParagraphs.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n"))

        Required JSON shape:
        {"genre":"...","tone":"...","pace":"slow|natural|brisk","pronunciationHints":"...","summary":"..."}
        """
    }

    private static func localDictionaryPrompt(_ entry: LocalDictionaryEntry) -> String {
        [
            entry.ukIPA.map { "UK IPA: \($0)" },
            entry.usIPA.map { "US IPA: \($0)" },
            entry.partsOfSpeech.isEmpty ? nil : "Parts of speech: \(entry.partsOfSpeech.joined(separator: ", "))",
            entry.rawDefinition.map { "Raw definition: \($0)" },
        ]
        .compactMap(\.self)
        .joined(separator: "\n")
    }

    private static func paragraphSystemPrompt(base: String, context: ParagraphContext) -> String {
        let metadata = [
            normalizedContextValue(context.bookTitle).map { "Current work: \"\($0)\"" },
            normalizedContextValue(context.chapterTitle).map { "Chapter: \"\($0)\"" },
        ].compactMap(\.self)

        guard !metadata.isEmpty else {
            return base
        }

        return """
        \(paragraphTranslationSystemMain)

        Context:
        \(metadata.joined(separator: "\n"))

        \(paragraphTranslationHardConstraints)
        """
    }

    private static func paragraphUserPrompt(_ text: String) -> String {
        """
        把下面这段英文译成中文：

        \(text)
        """
    }

    private static func normalizedContextValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func truncatedPreviousText(_ text: String) -> String {
        let maxLength = 4_000
        guard text.count > maxLength else {
            return text
        }
        return String(text.suffix(maxLength))
    }
}

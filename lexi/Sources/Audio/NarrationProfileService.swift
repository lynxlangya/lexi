import Foundation

nonisolated struct NarrationProfilePromptInput: Equatable, Sendable {
    var title: String
    var author: String
    var chapterTitles: [String]
    var sampleParagraphs: [String]
    var currentChapterTitle: String?
    var currentParagraph: String?

    static func make(
        book: ReaderBook,
        chapters: [ReaderChapter],
        currentChapter: ReaderChapter?,
        maxChapterTitles: Int = 24,
        maxSamples: Int = 8,
        maxParagraphCharacters: Int = 600
    ) -> NarrationProfilePromptInput {
        let chapterTitles = chapters
            .prefix(maxChapterTitles)
            .map { normalizedTitle($0.title, fallback: "Chapter \($0.n)") }
            .filter { !$0.isEmpty }

        var samples: [String] = []
        for chapter in chapters.prefix(maxSamples) {
            guard let paragraph = chapter.paragraphs.first(where: { !$0.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                continue
            }
            samples.append(truncated(paragraph.en, limit: maxParagraphCharacters))
        }

        let currentParagraph = currentChapter?.paragraphs
            .first(where: { !$0.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map { truncated($0.en, limit: maxParagraphCharacters) }

        return NarrationProfilePromptInput(
            title: normalizedTitle(book.title, fallback: "Untitled"),
            author: normalizedTitle(book.author, fallback: "Unknown"),
            chapterTitles: chapterTitles,
            sampleParagraphs: Array(samples.prefix(maxSamples)),
            currentChapterTitle: currentChapter.map { normalizedTitle($0.title, fallback: "Chapter \($0.n)") },
            currentParagraph: currentParagraph
        )
    }

    private static func normalizedTitle(_ value: String, fallback: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : truncated(normalized, limit: 160)
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard normalized.count > limit else {
            return normalized
        }
        return String(normalized.prefix(limit))
    }
}

nonisolated struct NarrationProfilePayload: Codable, Equatable, Sendable {
    var genre: String
    var tone: String
    var pace: String
    var pronunciationHints: String
    var summary: String
}

nonisolated protocol NarrationProfileResolving: Sendable {
    func profile(
        book: ReaderBook,
        chapters: [ReaderChapter],
        currentChapter: ReaderChapter,
        provider: TTSProviderID,
        forceRefresh: Bool,
        database: AppDatabase,
        engineConfig: EngineConfig,
        engineRegistry: EngineRegistry
    ) async -> NarrationProfile
}

nonisolated struct DefaultNarrationProfileResolver: NarrationProfileResolving {
    func profile(
        book: ReaderBook,
        chapters: [ReaderChapter],
        currentChapter: ReaderChapter,
        provider: TTSProviderID,
        forceRefresh: Bool = false,
        database: AppDatabase,
        engineConfig: EngineConfig,
        engineRegistry: EngineRegistry
    ) async -> NarrationProfile {
        if !forceRefresh,
           let cached = try? await database.narrationProfile(bookId: book.id),
           cached.provider == provider {
            return cached
        }

        do {
            let generated = try await generateProfile(
                book: book,
                chapters: chapters,
                currentChapter: currentChapter,
                provider: provider,
                engineConfig: engineConfig,
                engineRegistry: engineRegistry
            )
            try await database.upsertNarrationProfile(generated)
            return generated
        } catch {
            return NarrationProfile.neutral(bookId: book.id, provider: provider)
        }
    }

    private func generateProfile(
        book: ReaderBook,
        chapters: [ReaderChapter],
        currentChapter: ReaderChapter,
        provider: TTSProviderID,
        engineConfig: EngineConfig,
        engineRegistry: EngineRegistry
    ) async throws -> NarrationProfile {
        let input = NarrationProfilePromptInput.make(
            book: book,
            chapters: chapters,
            currentChapter: currentChapter
        )
        let engine = try engineRegistry.engine(for: engineConfig)
        var response = ""
        for try await chunk in engine.translate([.narrationProfile(input: input)], model: engineConfig.model) {
            response.append(chunk.text)
        }
        let payload = try NarrationProfilePayload.decode(response)
        let now = Date()
        return NarrationProfile(
            bookId: book.id,
            provider: provider,
            profileHash: NarrationProfile.profileHash(provider: provider, payload: payload),
            genre: payload.genre,
            tone: payload.tone,
            pace: payload.pace,
            pronunciationHints: payload.pronunciationHints,
            summary: payload.summary,
            createdAt: now,
            updatedAt: now
        )
    }
}

extension NarrationProfilePayload {
    nonisolated static func decode(_ text: String) throws -> NarrationProfilePayload {
        let data = Data(extractJSONObject(from: text).utf8)
        let payload = try JSONDecoder().decode(NarrationProfilePayload.self, from: data)
        guard !payload.genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !payload.tone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !payload.pace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.invalidResponse
        }
        return payload.normalized
    }

    private nonisolated var normalized: NarrationProfilePayload {
        NarrationProfilePayload(
            genre: Self.cleaned(genre, fallback: "unknown"),
            tone: Self.cleaned(tone, fallback: "calm"),
            pace: Self.cleaned(pace, fallback: "natural"),
            pronunciationHints: Self.cleaned(pronunciationHints, fallback: ""),
            summary: Self.cleaned(summary, fallback: "")
        )
    }

    private nonisolated static func cleaned(_ value: String, fallback: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : String(normalized.prefix(360))
    }
}

extension NarrationProfile {
    nonisolated static func neutral(bookId: String, provider: TTSProviderID, now: Date = Date()) -> NarrationProfile {
        let payload = NarrationProfilePayload(
            genre: "unknown",
            tone: "calm",
            pace: "natural",
            pronunciationHints: "",
            summary: "Neutral read-aloud profile."
        )
        return NarrationProfile(
            bookId: bookId,
            provider: provider,
            profileHash: profileHash(provider: provider, payload: payload),
            genre: payload.genre,
            tone: payload.tone,
            pace: payload.pace,
            pronunciationHints: payload.pronunciationHints,
            summary: payload.summary,
            createdAt: now,
            updatedAt: now
        )
    }

    nonisolated static func profileHash(provider: TTSProviderID, payload: NarrationProfilePayload) -> String {
        [
            provider.rawValue,
            payload.genre,
            payload.tone,
            payload.pace,
            payload.pronunciationHints,
            payload.summary,
        ].joined(separator: "|").lexiSHA256
    }

    nonisolated var ttsContextInstruction: String {
        let hint = pronunciationHints.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [
            "Read in a \(tone), \(pace), \(genre) style.",
            "Use clear phrase breaks and natural emphasis.",
        ]
        if !hint.isEmpty {
            parts.append("Pronunciation hints: \(hint).")
        }
        return String(parts.joined(separator: " ").prefix(420))
    }
}

private nonisolated func extractJSONObject(from text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let start = trimmed.firstIndex(of: "{") else {
        return trimmed
    }

    var depth = 0
    var inString = false
    var escaped = false
    var cursor = start
    while cursor < trimmed.endIndex {
        let character = trimmed[cursor]
        if escaped {
            escaped = false
        } else if character == "\\" {
            escaped = true
        } else if character == "\"" {
            inString.toggle()
        } else if !inString {
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(trimmed[start...cursor])
                }
            }
        }
        cursor = trimmed.index(after: cursor)
    }
    return trimmed
}

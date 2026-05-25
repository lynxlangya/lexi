import Foundation

nonisolated struct ReadAloudChunk: Equatable, Identifiable, Sendable {
    var id: String {
        "\(chapterId)-\(paragraphStart)-\(paragraphEnd)-\(language.rawValue)-\(text.lexiSHA256)"
    }

    var bookId: String
    var chapterId: Int64
    var paragraphStart: Int
    var paragraphEnd: Int
    var language: TTSAudioLanguage
    var text: String
    var paragraphIds: [Int64]
    var profile: NarrationProfile?

    var displayRange: String {
        paragraphStart == paragraphEnd
            ? "段落 \(paragraphStart + 1)"
            : "段落 \(paragraphStart + 1)-\(paragraphEnd + 1)"
    }
}

nonisolated enum ReadAloudChunkPlanner {
    static let defaultMinCharacters = 600
    static let defaultMaxCharacters = 1_200
    static let defaultMaxParagraphs = 3

    static func chunks(
        for chapter: ReaderChapter,
        snapshot: ChapterTranslationSnapshot,
        language: TTSAudioLanguage,
        startParagraphId: Int64?,
        minCharacters: Int = defaultMinCharacters,
        maxCharacters: Int = defaultMaxCharacters,
        maxParagraphs: Int = defaultMaxParagraphs
    ) -> [ReadAloudChunk] {
        guard !chapter.paragraphs.isEmpty else {
            return []
        }

        let startIndex = startParagraphId
            .flatMap { id in chapter.paragraphs.firstIndex(where: { $0.id == id }) }
            ?? 0
        guard chapter.paragraphs.indices.contains(startIndex) else {
            return []
        }
        if language == .target,
           text(for: chapter.paragraphs[startIndex], snapshot: snapshot, language: .target) == nil {
            return []
        }

        var chunks: [ReadAloudChunk] = []
        var pendingParagraphs: [(paragraph: ReaderParagraph, text: String)] = []
        var pendingCharacterCount = 0

        func flushPending() {
            guard let first = pendingParagraphs.first,
                  let last = pendingParagraphs.last else {
                return
            }

            chunks.append(ReadAloudChunk(
                bookId: chapter.bookId,
                chapterId: chapter.id,
                paragraphStart: first.paragraph.ord,
                paragraphEnd: last.paragraph.ord,
                language: language,
                text: pendingParagraphs.map(\.text).joined(separator: "\n\n"),
                paragraphIds: pendingParagraphs.map(\.paragraph.id),
                profile: nil
            ))
            pendingParagraphs.removeAll(keepingCapacity: true)
            pendingCharacterCount = 0
        }

        for paragraph in chapter.paragraphs[startIndex...] {
            guard let text = text(for: paragraph, snapshot: snapshot, language: language) else {
                flushPending()
                continue
            }

            let wouldExceedMax = pendingCharacterCount > 0
                && pendingCharacterCount + text.count > maxCharacters
            let reachedParagraphLimit = pendingParagraphs.count >= maxParagraphs
            if reachedParagraphLimit || (wouldExceedMax && pendingCharacterCount >= minCharacters) {
                flushPending()
            }

            pendingParagraphs.append((paragraph, text))
            pendingCharacterCount += text.count

            if pendingCharacterCount >= maxCharacters || pendingParagraphs.count >= maxParagraphs {
                flushPending()
            }
        }

        flushPending()
        return chunks
    }

    static func unavailableReason(
        for language: TTSAudioLanguage,
        chapter: ReaderChapter,
        snapshot: ChapterTranslationSnapshot,
        startParagraphId: Int64?
    ) -> String? {
        if language == .source {
            return chapter.paragraphs.isEmpty ? "当前章节没有可朗读文本" : nil
        }

        let startIndex = startParagraphId
            .flatMap { id in chapter.paragraphs.firstIndex(where: { $0.id == id }) }
            ?? 0
        guard chapter.paragraphs.indices.contains(startIndex) else {
            return "当前章节没有可朗读译文"
        }

        let paragraph = chapter.paragraphs[startIndex]
        if text(for: paragraph, snapshot: snapshot, language: .target) != nil {
            return nil
        }
        return "当前段落译文还未缓存，先完成本段翻译后再朗读译文"
    }

    private static func text(
        for paragraph: ReaderParagraph,
        snapshot: ChapterTranslationSnapshot,
        language: TTSAudioLanguage
    ) -> String? {
        let rawText: String?
        switch language {
        case .source:
            rawText = paragraph.en
        case .target:
            if case .cached(let zh) = snapshot.paragraphStates[paragraph.id] {
                rawText = zh
            } else {
                rawText = nil
            }
        }

        let trimmed = rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

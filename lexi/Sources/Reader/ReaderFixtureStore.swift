import Foundation

enum ReaderFixtureStore {
    nonisolated static let bookId = "gatsby"

    static func seedIfNeeded(into database: AppDatabase) async throws {
        guard try await database.book(id: bookId) == nil else {
            return
        }

        let now = Date()
        let book = Book(
            id: bookId,
            title: GatsbyFixture.bookTitle,
            author: GatsbyFixture.author,
            fileURL: URL(fileURLWithPath: "/tmp/lexi-fixtures/gatsby.epub"),
            addedAt: now,
            lastReadAt: now,
            progress: 0.34,
            coverData: nil,
            coverBg: "#d8c4a0",
            coverInk: "#1f1b15"
        )
        let chapters = GatsbyFixture.chapters.enumerated().map { index, fixture in
            (
                Chapter(id: nil, bookId: bookId, idx: index, n: fixture.n, title: fixture.title),
                fixture.paras.enumerated().map { ord, paragraph in
                    Paragraph(id: nil, chapterId: 0, ord: ord, en: paragraph.en)
                }
            )
        }

        _ = try await database.importBook((book, chapters))
        try await seedCachedTranslations(into: database, model: defaultModel(for: .deepseek))
    }

    static func loadBook(from database: AppDatabase, bookId: String = Self.bookId) async throws -> (ReaderBook, [ReaderChapter]) {
        try await seedIfNeeded(into: database)

        guard let book = try await database.book(id: bookId) else {
            throw ReaderFixtureError.missingBook
        }

        return try await loadBook(book, from: database)
    }

    static func loadExistingBook(bookId: String, from database: AppDatabase) async throws -> (ReaderBook, [ReaderChapter]) {
        guard let book = try await database.book(id: bookId) else {
            throw ReaderFixtureError.missingBook
        }

        return try await loadBook(book, from: database)
    }

    static func loadBook(_ book: Book, from database: AppDatabase) async throws -> (ReaderBook, [ReaderChapter]) {
        let chapters = try await database.chapters(bookId: book.id)
        let readerChapters = try await chapters.asyncMap { chapter -> ReaderChapter in
            try await readerChapter(from: chapter, database: database)
        }

        return (
            ReaderBook(book: book),
            readerChapters
        )
    }

    private static func readerChapter(from chapter: Chapter, database: AppDatabase) async throws -> ReaderChapter {
        guard let chapterId = chapter.id else {
            throw ReaderFixtureError.missingChapterId
        }
        let paragraphs = try await database.paragraphs(chapterId: chapterId)
        return ReaderChapter(
            id: chapterId,
            bookId: chapter.bookId,
            idx: chapter.idx,
            n: chapter.n,
            title: chapter.title,
            paragraphs: paragraphs.compactMap { paragraph in
                guard let paragraphId = paragraph.id else {
                    return nil
                }
                return ReaderParagraph(id: paragraphId, ord: paragraph.ord, en: paragraph.en)
            }
        )
    }

    static func defaultConfig() -> EngineConfig {
        return EngineConfig(id: .deepseek, model: defaultModel(for: .deepseek), lastTestedOK: false, lastTestedAt: nil)
    }

    nonisolated static func defaultModel(for engine: EngineID) -> String {
        switch engine {
        case .openai:
            return "gpt-5.4-mini"
        case .anthropic:
            return "claude-sonnet-4-6"
        case .deepseek:
            return "deepseek-chat"
        }
    }

    private static func seedCachedTranslations(into database: AppDatabase, model: String) async throws {
        let chapters = try await database.chapters(bookId: bookId)
        for chapter in chapters where chapter.idx != 1 {
            guard let chapterId = chapter.id,
                  let fixture = GatsbyFixture.chapters[safe: chapter.idx] else {
                continue
            }

            let paragraphs = try await database.paragraphs(chapterId: chapterId)
            for paragraph in paragraphs {
                guard let paragraphId = paragraph.id,
                      let fixtureParagraph = fixture.paras[safe: paragraph.ord] else {
                    continue
                }

                try await database.upsertTranslation(
                    Translation(
                        id: nil,
                        paragraphId: paragraphId,
                        engine: .deepseek,
                        model: model,
                        zh: fixtureParagraph.zh,
                        createdAt: Date()
                    )
                )
            }
        }
    }
}

enum ReaderFixtureError: Error {
    case missingBook
    case missingChapterId
}

private extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        for element in self {
            values.append(try await transform(element))
        }
        return values
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

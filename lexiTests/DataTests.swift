import XCTest
@testable import lexi

final class DataTests: XCTestCase {
    func testMigrationCreatesExpectedSchemaAndIsIdempotent() async throws {
        let database = try AppDatabase.makeTransient()
        try await database.migrate()

        let tables = try await database.tableNames()
        XCTAssertTrue(tables.isSuperset(of: [
            "books",
            "chapters",
            "paragraphs",
            "translations",
            "vocab",
            "progress",
            "engine_config",
        ]))

        let indexes = try await database.indexNames(on: "translations")
        XCTAssertTrue(indexes.contains("translations_paragraph_engine_idx"))
    }

    func testCrudSmoke() async throws {
        let database = try AppDatabase.makeTransient()
        let addedAt = Date(lexiTimestamp: 1_800_000_000)
        let book = Book(
            id: "gatsby",
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            fileURL: URL(fileURLWithPath: "/tmp/gatsby.epub"),
            addedAt: addedAt,
            lastReadAt: nil,
            progress: 0.25,
            coverData: Data([0x1, 0x2]),
            coverBg: "#eee3cf",
            coverInk: "#1f1b15"
        )

        try await database.insertBook(book)
        let storedBook = try await database.book(id: "gatsby")
        XCTAssertEqual(storedBook, book)

        let chapterId = try await database.insertChapter(
            Chapter(id: nil, bookId: "gatsby", idx: 0, n: "I", title: "Chapter I")
        )
        let paragraphId = try await database.insertParagraph(
            Paragraph(id: nil, chapterId: chapterId, ord: 0, en: "In my younger and more vulnerable years...")
        )

        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: paragraphId,
                engine: .openai,
                model: "gpt-4-turbo",
                zh: "在我年纪更轻、也更容易受伤的时候……",
                createdAt: addedAt
            )
        )
        let cachedTranslation = try await database.cachedTranslation(
            paragraphId: paragraphId,
            engine: .openai,
            model: "gpt-4-turbo"
        )
        XCTAssertEqual(cachedTranslation, "在我年纪更轻、也更容易受伤的时候……")

        try await database.upsertProgress(
            ProgressRecord(bookId: "gatsby", chapterIdx: 0, scrollPct: 0.42, updatedAt: addedAt)
        )
        let progress = try await database.progress(for: "gatsby")
        XCTAssertEqual(progress?.scrollPct, 0.42)

        _ = try await database.insertVocabEntry(
            VocabEntry(id: nil, word: "vulnerable", context: "younger and more vulnerable", bookId: "gatsby", addedAt: addedAt)
        )
        let vocabEntries = try await database.vocabEntries(bookId: "gatsby")
        XCTAssertEqual(vocabEntries.first?.word, "vulnerable")

        try await database.upsertEngineConfig(
            EngineConfig(id: .openai, model: "gpt-4-turbo", lastTestedOK: true, lastTestedAt: addedAt)
        )
        let engineConfig = try await database.engineConfig(for: .openai)
        XCTAssertEqual(engineConfig?.model, "gpt-4-turbo")
    }

    func testKeychainRoundTrip() throws {
        let store = KeychainStore(servicePrefix: "com.lexi.tests.\(UUID().uuidString)")
        defer {
            try? store.delete(.openai)
        }

        XCTAssertNil(try store.apiKey(for: .openai))

        try store.setApiKey("test-key-1", for: .openai)
        XCTAssertEqual(try store.apiKey(for: .openai), "test-key-1")

        try store.setApiKey("test-key-2", for: .openai)
        XCTAssertEqual(try store.apiKey(for: .openai), "test-key-2")

        try store.delete(.openai)
        XCTAssertNil(try store.apiKey(for: .openai))
    }
}

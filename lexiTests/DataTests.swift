import XCTest
import GRDB
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
                model: "gpt-5.4-mini",
                zh: "在我年纪更轻、也更容易受伤的时候……",
                createdAt: addedAt
            )
        )
        let cachedTranslation = try await database.cachedTranslation(
            paragraphId: paragraphId,
            engine: .openai,
            model: "gpt-5.4-mini"
        )
        XCTAssertEqual(cachedTranslation, "在我年纪更轻、也更容易受伤的时候……")

        try await database.upsertProgress(
            ProgressRecord(bookId: "gatsby", chapterIdx: 0, scrollPct: 0.42, updatedAt: addedAt)
        )
        let progress = try await database.progress(for: "gatsby")
        XCTAssertEqual(progress?.scrollPct, 0.42)

        _ = try await database.upsertVocabEntry(
            word: "vulnerable",
            context: "younger and more vulnerable",
            primaryZh: "",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: "gatsby",
            now: addedAt
        )
        let vocabEntries = try await database.vocabEntries(bookId: "gatsby")
        XCTAssertEqual(vocabEntries.first?.word, "vulnerable")

        try await database.upsertEngineConfig(
            EngineConfig(id: .openai, model: "gpt-5.4-mini", lastTestedOK: true, lastTestedAt: addedAt)
        )
        let engineConfig = try await database.engineConfig(for: .openai)
        XCTAssertEqual(engineConfig?.model, "gpt-5.4-mini")
    }

    func testV2VocabBackfillDedupesAndMergesBookIds() throws {
        let pool = try DatabasePool(path: temporaryDatabaseURL().path)
        var v1Migrator = DatabaseMigrator()
        Migrations.registerV1Initial(in: &v1Migrator)
        try v1Migrator.migrate(pool)

        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO books (id, title, author, fileURL, addedAt, progress)
                VALUES ('book-a', 'Book A', 'A', 'file:///a.epub', 1800000000, 0),
                       ('book-b', 'Book B', 'B', 'file:///b.epub', 1800000000, 0)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO vocab (word, context, bookId, addedAt)
                VALUES ('Observe', 'first context', 'book-a', 1800000001),
                       ('observe', 'second context', 'book-b', 1800000002),
                       ('  ', 'bad row', NULL, 1800000003)
                """
            )
        }

        var fullMigrator = DatabaseMigrator()
        Migrations.register(in: &fullMigrator)
        try fullMigrator.migrate(pool)

        let rows = try pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM vocab ORDER BY id")
        }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["word"] as String, "Observe")
        XCTAssertEqual(rows[0]["normalizedWord"] as String, "observe")
        XCTAssertEqual(rows[0]["context"] as String?, "first context")
        XCTAssertEqual(rows[0]["primaryZh"] as String, "")
        XCTAssertEqual(rows[0]["sensesJSON"] as String, "[]")
        XCTAssertEqual(rows[0]["seenInBooks"] as String, "[\"book-a\",\"book-b\"]")
        XCTAssertEqual(rows[0]["updatedAt"] as Int64, 1_800_000_002)
    }

    func testUpsertNewWordInsertsFullRow() async throws {
        let database = try AppDatabase.makeTransient()
        let result = try await database.upsertVocabEntry(
            word: "Observe",
            context: "They observe the Sabbath.",
            primaryZh: "观察；遵守",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"观察\"}]",
            ukIPA: "/əbˈzɜːv/",
            usIPA: "/əbˈzɝːv/",
            exampleEN: "They observe quietly.",
            exampleZH: "他们静静观察。",
            bookId: "book-a",
            now: Date(lexiTimestamp: 1_800_000_010)
        )

        guard case .inserted = result else {
            return XCTFail("Expected inserted result")
        }
        let entry = try await database.vocabEntry(normalizedWord: "observe")
        XCTAssertEqual(entry?.word, "Observe")
        XCTAssertEqual(entry?.context, "They observe the Sabbath.")
        XCTAssertEqual(entry?.primaryZh, "观察；遵守")
        XCTAssertEqual(entry?.sensesJSON, "[{\"pos\":\"v\",\"zh\":\"观察\"}]")
        XCTAssertEqual(entry?.ukIPA, "/əbˈzɜːv/")
        XCTAssertEqual(entry?.usIPA, "/əbˈzɝːv/")
        XCTAssertEqual(entry?.exampleEN, "They observe quietly.")
        XCTAssertEqual(entry?.exampleZH, "他们静静观察。")
        XCTAssertEqual(entry?.seenInBookIds, ["book-a"])
        XCTAssertEqual(entry?.mastered, false)
    }

    func testUpsertExistingWordOnlyUpdatesTimestampsAndBooks() async throws {
        let database = try AppDatabase.makeTransient()
        _ = try await database.upsertVocabEntry(
            word: "Observe",
            context: "first context",
            primaryZh: "first zh",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"first\"}]",
            ukIPA: "/first/",
            usIPA: nil,
            exampleEN: "first example",
            exampleZH: "第一个例句",
            bookId: "book-a",
            now: Date(lexiTimestamp: 1_800_000_010)
        )

        let result = try await database.upsertVocabEntry(
            word: "observe",
            context: "second context",
            primaryZh: "second zh",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"second\"}]",
            ukIPA: "/second/",
            usIPA: "/second-us/",
            exampleEN: "second example",
            exampleZH: "第二个例句",
            bookId: "book-b",
            now: Date(lexiTimestamp: 1_800_000_020)
        )

        guard case .updated = result else {
            return XCTFail("Expected updated result")
        }
        let entries = try await database.allVocabEntries()
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.word, "Observe")
        XCTAssertEqual(entry.context, "first context")
        XCTAssertEqual(entry.primaryZh, "first zh")
        XCTAssertEqual(entry.sensesJSON, "[{\"pos\":\"v\",\"zh\":\"first\"}]")
        XCTAssertEqual(entry.ukIPA, "/first/")
        XCTAssertEqual(entry.exampleEN, "first example")
        XCTAssertEqual(entry.seenInBookIds, ["book-a", "book-b"])
        XCTAssertEqual(entry.addedAt, Date(lexiTimestamp: 1_800_000_010))
        XCTAssertEqual(entry.updatedAt, Date(lexiTimestamp: 1_800_000_020))
    }

    func testUpsertExistingWordDoesNotOverwriteSnapshot() async throws {
        let database = try AppDatabase.makeTransient()
        _ = try await database.upsertVocabEntry(
            word: "Abnegate",
            context: "original context",
            primaryZh: "放弃",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"放弃\"}]",
            ukIPA: "/original/",
            usIPA: nil,
            exampleEN: "original example",
            exampleZH: "原例句",
            bookId: nil,
            now: Date(lexiTimestamp: 1_800_000_010)
        )

        _ = try await database.upsertVocabEntry(
            word: "abnegate",
            context: "new context",
            primaryZh: "覆盖",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"覆盖\"}]",
            ukIPA: "/new/",
            usIPA: "/new-us/",
            exampleEN: "new example",
            exampleZH: "新例句",
            bookId: nil,
            now: Date(lexiTimestamp: 1_800_000_020)
        )

        let storedEntry = try await database.vocabEntry(normalizedWord: "abnegate")
        let entry = try XCTUnwrap(storedEntry)
        XCTAssertEqual(entry.context, "original context")
        XCTAssertEqual(entry.primaryZh, "放弃")
        XCTAssertEqual(entry.sensesJSON, "[{\"pos\":\"v\",\"zh\":\"放弃\"}]")
        XCTAssertEqual(entry.ukIPA, "/original/")
        XCTAssertEqual(entry.exampleEN, "original example")
        XCTAssertEqual(entry.exampleZH, "原例句")
    }

    private func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "LexiTests", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "\(UUID().uuidString).sqlite")
    }

    func testShelfBookListOrdersByRecentActivity() async throws {
        let database = try AppDatabase.makeTransient()
        let older = Book(
            id: "older",
            title: "Older Book",
            author: "Author B",
            fileURL: URL(fileURLWithPath: "/tmp/older.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            lastReadAt: Date(lexiTimestamp: 1_800_000_100),
            progress: 0.2,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        )
        let newer = Book(
            id: "newer",
            title: "Newer Book",
            author: "Author A",
            fileURL: URL(fileURLWithPath: "/tmp/newer.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_010),
            lastReadAt: Date(lexiTimestamp: 1_800_000_200),
            progress: 0.6,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        )

        try await database.insertBook(older)
        try await database.insertBook(newer)

        let books = try await database.books()
        XCTAssertEqual(books.map(\.id), ["newer", "older"])
    }

    func testShelfCacheClearAndBookDeleteAreScopedToBook() async throws {
        let database = try AppDatabase.makeTransient()
        let date = Date(lexiTimestamp: 1_800_000_000)
        for bookId in ["one", "two"] {
            try await database.insertBook(
                Book(
                    id: bookId,
                    title: bookId,
                    author: "Author",
                    fileURL: URL(fileURLWithPath: "/tmp/\(bookId).epub"),
                    addedAt: date,
                    lastReadAt: nil,
                    progress: 0,
                    coverData: nil,
                    coverBg: nil,
                    coverInk: nil
                )
            )
            let chapterId = try await database.insertChapter(
                Chapter(id: nil, bookId: bookId, idx: 0, n: "1", title: "Chapter")
            )
            let paragraphId = try await database.insertParagraph(
                Paragraph(id: nil, chapterId: chapterId, ord: 0, en: "Text")
            )
            try await database.upsertTranslation(
                Translation(id: nil, paragraphId: paragraphId, engine: .openai, model: "gpt", zh: "译文", createdAt: date)
            )
        }

        let initialOneBytes = try await database.translationCacheBytes(bookId: "one")
        let initialTwoBytes = try await database.translationCacheBytes(bookId: "two")
        XCTAssertGreaterThan(initialOneBytes, 0)
        XCTAssertGreaterThan(initialTwoBytes, 0)

        try await database.clearTranslationCache(bookId: "one")

        let clearedOneBytes = try await database.translationCacheBytes(bookId: "one")
        let remainingTwoBytes = try await database.translationCacheBytes(bookId: "two")
        XCTAssertEqual(clearedOneBytes, 0)
        XCTAssertGreaterThan(remainingTwoBytes, 0)

        try await database.deleteBook(id: "two")

        let deletedBook = try await database.book(id: "two")
        let deletedTwoBytes = try await database.translationCacheBytes(bookId: "two")
        XCTAssertNil(deletedBook)
        XCTAssertEqual(deletedTwoBytes, 0)
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

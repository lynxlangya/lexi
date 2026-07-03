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

    func testReimportingExistingBookPreservesReadingStateAndTranslations() async throws {
        let database = try AppDatabase.makeTransient()
        let importedAt = Date(lexiTimestamp: 1_800_000_000)
        let readAt = Date(lexiTimestamp: 1_800_000_100)
        let translatedAt = Date(lexiTimestamp: 1_800_000_200)
        let firstBook = Book(
            id: "same-book",
            title: "Original",
            author: "Author",
            fileURL: URL(fileURLWithPath: "/tmp/original.epub"),
            addedAt: importedAt,
            lastReadAt: nil,
            progress: 0,
            coverData: nil,
            coverBg: "#d8c4a0",
            coverInk: "#1f1b15"
        )
        try await database.importBook((
            firstBook,
            [
                (
                    Chapter(id: nil, bookId: firstBook.id, idx: 0, n: "1", title: "Chapter One"),
                    [Paragraph(id: nil, chapterId: 0, ord: 0, en: "Original paragraph.")]
                ),
            ]
        ))

        let importedChapters = try await database.chapters(bookId: firstBook.id)
        let chapterId = try XCTUnwrap(importedChapters.first?.id)
        let importedParagraphs = try await database.paragraphs(chapterId: chapterId)
        let paragraphId = try XCTUnwrap(importedParagraphs.first?.id)
        try await database.updateBookProgress(id: firstBook.id, progress: 0.72, at: readAt)
        try await database.upsertProgress(
            ProgressRecord(bookId: firstBook.id, chapterIdx: 0, scrollPct: 3, updatedAt: readAt)
        )
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: paragraphId,
                engine: .openai,
                model: "gpt-5.4-mini",
                zh: "原始译文。",
                createdAt: translatedAt
            )
        )

        let replacementBook = Book(
            id: firstBook.id,
            title: "Updated Metadata",
            author: "Author",
            fileURL: URL(fileURLWithPath: "/tmp/reimported.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_300),
            lastReadAt: nil,
            progress: 0,
            coverData: Data([0x01]),
            coverBg: nil,
            coverInk: nil
        )
        try await database.importBook((
            replacementBook,
            [
                (
                    Chapter(id: nil, bookId: replacementBook.id, idx: 0, n: "1", title: "Replacement Chapter"),
                    [Paragraph(id: nil, chapterId: 0, ord: 0, en: "Replacement paragraph.")]
                ),
            ]
        ))

        let storedBook = try await database.book(id: firstBook.id)
        XCTAssertEqual(storedBook?.title, "Updated Metadata")
        XCTAssertEqual(storedBook?.fileURL, URL(fileURLWithPath: "/tmp/reimported.epub"))
        XCTAssertEqual(storedBook?.progress, 0.72)
        XCTAssertEqual(storedBook?.lastReadAt, readAt)

        let storedProgress = try await database.progress(for: firstBook.id)
        XCTAssertEqual(storedProgress?.scrollPct, 3)

        let chapters = try await database.chapters(bookId: firstBook.id)
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters.first?.title, "Chapter One")
        let paragraphs = try await database.paragraphs(chapterId: chapterId)
        XCTAssertEqual(paragraphs.map(\.en), ["Original paragraph."])
        let cachedTranslation = try await database.cachedTranslation(
            paragraphId: paragraphId,
            engine: .openai,
            model: "gpt-5.4-mini"
        )
        XCTAssertEqual(cachedTranslation, "原始译文。")
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
        XCTAssertEqual(rows[0]["seenGlobally"] as Int64, 0)
        XCTAssertEqual(rows[0]["updatedAt"] as Int64, 1_800_000_002)
    }

    func testV3VocabGlobalSourceBackfillsGlobalOnlyRows() throws {
        let pool = try DatabasePool(path: temporaryDatabaseURL().path)
        var v2Migrator = DatabaseMigrator()
        Migrations.registerV1Initial(in: &v2Migrator)
        try v2Migrator.migrate(pool)

        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO vocab (word, context, bookId, addedAt)
                VALUES ('Global', 'outside app', NULL, 1800000001)
                """
            )
        }

        var fullMigrator = DatabaseMigrator()
        Migrations.register(in: &fullMigrator)
        try fullMigrator.migrate(pool)

        let row = try pool.read { db in
            try Row.fetchOne(db, sql: "SELECT seenInBooks, seenGlobally FROM vocab WHERE normalizedWord = 'global'")
        }
        XCTAssertEqual(row?["seenInBooks"] as String?, "[]")
        XCTAssertEqual(row?["seenGlobally"] as Int64?, 1)
    }

    func testV4AudioReadAloudCreatesCacheAndProfileTables() async throws {
        let database = try AppDatabase.makeTransient()
        let names = try await database.tableNames()
        XCTAssertTrue(names.contains("audio_cache"))
        XCTAssertTrue(names.contains("narration_profiles"))
    }

    func testAudioCacheRoundTripAndByteCount() async throws {
        let database = try AppDatabase.makeTransient()
        try await database.insertBook(Book(
            id: "book-a",
            title: "Book A",
            author: "Author",
            fileURL: URL(fileURLWithPath: "/tmp/book-a.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            lastReadAt: nil,
            progress: 0,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        ))

        let created = Date(lexiTimestamp: 1_800_000_001)
        let accessed = Date(lexiTimestamp: 1_800_000_002)
        let record = AudioCacheRecord(
            cacheKey: "cache-key",
            bookId: "book-a",
            chapterId: nil,
            paragraphStart: 0,
            paragraphEnd: 1,
            language: .source,
            provider: .doubao,
            resourceId: "seed-tts-2.0",
            speaker: "voice",
            speechRate: 0,
            profileHash: "profile",
            textHash: "text",
            fileURL: URL(fileURLWithPath: "/tmp/audio.mp3"),
            byteCount: 1234,
            durationSeconds: 2.5,
            createdAt: created,
            lastAccessedAt: accessed
        )

        try await database.upsertAudioCacheRecord(record)
        let fetched = try await database.audioCacheRecord(cacheKey: "cache-key", accessedAt: nil)
        let bytes = try await database.audioCacheBytes()

        XCTAssertEqual(fetched, record)
        XCTAssertEqual(bytes, 1234)
    }

    func testClearAudioCacheForBookReturnsFilesAndPreservesTranslations() async throws {
        let database = try AppDatabase.makeTransient()
        let date = Date(lexiTimestamp: 1_800_000_000)
        let bookOne = try await insertBookWithOneTranslation(id: "book-one", database: database, date: date)
        let bookTwo = try await insertBookWithOneTranslation(id: "book-two", database: database, date: date)
        let oneFile = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-one.mp3")
        let twoFile = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-two.mp3")

        try await database.upsertAudioCacheRecord(audioCacheRecord(
            cacheKey: "audio-one",
            bookId: "book-one",
            chapterId: bookOne.chapterId,
            fileURL: oneFile,
            byteCount: 100,
            date: date
        ))
        try await database.upsertAudioCacheRecord(audioCacheRecord(
            cacheKey: "audio-two",
            bookId: "book-two",
            chapterId: bookTwo.chapterId,
            fileURL: twoFile,
            byteCount: 200,
            date: date
        ))

        let removedFiles = try await database.clearAudioCache(bookId: "book-one")
        let removedAudio = try await database.audioCacheRecord(cacheKey: "audio-one", accessedAt: nil)
        let remainingAudio = try await database.audioCacheRecord(cacheKey: "audio-two", accessedAt: nil)
        let audioBytes = try await database.audioCacheBytes()
        let bookOneTranslationBytes = try await database.translationCacheBytes(bookId: "book-one")
        let bookTwoTranslationBytes = try await database.translationCacheBytes(bookId: "book-two")

        XCTAssertEqual(removedFiles, [oneFile])
        XCTAssertNil(removedAudio)
        XCTAssertNotNil(remainingAudio)
        XCTAssertEqual(audioBytes, 200)
        XCTAssertGreaterThan(bookOneTranslationBytes, 0)
        XCTAssertGreaterThan(bookTwoTranslationBytes, 0)
    }

    func testPruneAudioCacheRemovesLeastRecentlyAccessedRowsUnderTarget() async throws {
        let database = try AppDatabase.makeTransient()
        let date = Date(lexiTimestamp: 1_800_000_000)
        let book = try await insertBookWithOneTranslation(id: "book-prune", database: database, date: date)
        let oldestFile = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-oldest.mp3")
        let middleFile = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-middle.mp3")
        let newestFile = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-newest.mp3")

        try await database.upsertAudioCacheRecord(audioCacheRecord(
            cacheKey: "audio-oldest",
            bookId: "book-prune",
            chapterId: book.chapterId,
            fileURL: oldestFile,
            byteCount: 40,
            date: Date(lexiTimestamp: 1_800_000_001)
        ))
        try await database.upsertAudioCacheRecord(audioCacheRecord(
            cacheKey: "audio-middle",
            bookId: "book-prune",
            chapterId: book.chapterId,
            fileURL: middleFile,
            byteCount: 40,
            date: Date(lexiTimestamp: 1_800_000_002)
        ))
        try await database.upsertAudioCacheRecord(audioCacheRecord(
            cacheKey: "audio-newest",
            bookId: "book-prune",
            chapterId: book.chapterId,
            fileURL: newestFile,
            byteCount: 80,
            date: Date(lexiTimestamp: 1_800_000_003)
        ))

        let removedFiles = try await database.pruneAudioCache(maxBytes: 100, cacheDirectory: nil)
        let prunedBytes = try await database.audioCacheBytes()
        let oldestRecord = try await database.audioCacheRecord(cacheKey: "audio-oldest", accessedAt: nil)
        let middleRecord = try await database.audioCacheRecord(cacheKey: "audio-middle", accessedAt: nil)
        let newestRecord = try await database.audioCacheRecord(cacheKey: "audio-newest", accessedAt: nil)

        XCTAssertEqual(removedFiles, [oldestFile, middleFile])
        XCTAssertLessThanOrEqual(prunedBytes, 90)
        XCTAssertNil(oldestRecord)
        XCTAssertNil(middleRecord)
        XCTAssertNotNil(newestRecord)
    }

    func testPruneAudioCacheReturnsOrphanFilesForSafeRemoval() async throws {
        let database = try AppDatabase.makeTransient()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LexiAudioCache-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let orphan = directory.appending(path: "orphan.mp3")
        try Data([0x01]).write(to: orphan)

        let removedFiles = try await database.pruneAudioCache(maxBytes: AudioCachePolicy.maxBytes, cacheDirectory: directory)
        AudioCacheLocation.removeFiles(at: removedFiles, cacheDirectory: directory)

        XCTAssertEqual(removedFiles, [orphan])
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testDeletingBookCascadesAudioCacheRowsAfterFileURLLookup() async throws {
        let database = try AppDatabase.makeTransient()
        let date = Date(lexiTimestamp: 1_800_000_000)
        let book = try await insertBookWithOneTranslation(id: "book-audio", database: database, date: date)
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-audio.mp3")
        try await database.upsertAudioCacheRecord(audioCacheRecord(
            cacheKey: "audio-book",
            bookId: "book-audio",
            chapterId: book.chapterId,
            fileURL: fileURL,
            byteCount: 300,
            date: date
        ))

        let fileURLs = try await database.audioCacheFileURLs(bookId: "book-audio")
        try await database.deleteBook(id: "book-audio")
        let deletedBook = try await database.book(id: "book-audio")
        let deletedAudio = try await database.audioCacheRecord(cacheKey: "audio-book", accessedAt: nil)
        let audioBytes = try await database.audioCacheBytes()

        XCTAssertEqual(fileURLs, [fileURL])
        XCTAssertNil(deletedBook)
        XCTAssertNil(deletedAudio)
        XCTAssertEqual(audioBytes, 0)
    }

    func testNarrationProfileRoundTrip() async throws {
        let database = try AppDatabase.makeTransient()
        try await database.insertBook(Book(
            id: "book-a",
            title: "Book A",
            author: "Author",
            fileURL: URL(fileURLWithPath: "/tmp/book-a.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            lastReadAt: nil,
            progress: 0,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        ))

        let profile = NarrationProfile(
            bookId: "book-a",
            provider: .doubao,
            profileHash: "profile-hash",
            genre: "nonfiction",
            tone: "calm",
            pace: "natural",
            pronunciationHints: "AI as A I",
            summary: "A book about work and intelligence.",
            createdAt: Date(lexiTimestamp: 1_800_000_001),
            updatedAt: Date(lexiTimestamp: 1_800_000_002)
        )

        try await database.upsertNarrationProfile(profile)
        let fetched = try await database.narrationProfile(bookId: "book-a")
        XCTAssertEqual(fetched, profile)
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
        XCTAssertFalse(entry?.seenGlobally ?? true)
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
        XCTAssertFalse(entry.seenGlobally)
    }

    func testGlobalSourceSurvivesLaterBookSourceMerge() async throws {
        let database = try AppDatabase.makeTransient()
        _ = try await database.upsertVocabEntry(
            word: "Observe",
            context: "global context",
            primaryZh: "观察",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: nil,
            now: Date(lexiTimestamp: 1_800_000_010)
        )

        _ = try await database.upsertVocabEntry(
            word: "observe",
            context: "book context",
            primaryZh: "不覆盖",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: "book-a",
            now: Date(lexiTimestamp: 1_800_000_020)
        )

        let storedEntry = try await database.vocabEntry(normalizedWord: "observe")
        let entry = try XCTUnwrap(storedEntry)
        XCTAssertTrue(entry.seenGlobally)
        XCTAssertEqual(entry.seenInBookIds, ["book-a"])
        let globalWords = try await database.vocabEntries(bookId: nil).map(\.normalizedWord)
        let bookWords = try await database.vocabEntries(bookId: "book-a").map(\.normalizedWord)
        XCTAssertEqual(globalWords, ["observe"])
        XCTAssertEqual(bookWords, ["observe"])
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

    func testInsertCapturesLookupResultSnapshot() async throws {
        let database = try AppDatabase.makeTransient()
        let lookup = LookupResult(
            senses: [LookupSense(pos: .v, zh: "观察")],
            contextualMeaning: "观察；遵守",
            synonyms: nil,
            example: LookupExample(en: "They observe quietly.", zh: "他们静静观察。")
        )
        let snapshot = VocabSnapshot.make(
            word: "Observe",
            lookup: lookup,
            localEntry: LocalDictionaryEntry(
                ukIPA: "/əbˈzɜːv/",
                usIPA: "/əbˈzɝːv/",
                partsOfSpeech: ["v."],
                rawDefinition: nil
            )
        )

        _ = try await database.upsertVocabEntry(
            word: "Observe",
            context: "They observe the Sabbath.",
            primaryZh: snapshot.primaryZh,
            sensesJSON: snapshot.sensesJSON,
            ukIPA: snapshot.ukIPA,
            usIPA: snapshot.usIPA,
            exampleEN: snapshot.exampleEN,
            exampleZH: snapshot.exampleZH,
            bookId: nil,
            now: Date(lexiTimestamp: 1_800_000_030)
        )

        let storedEntry = try await database.vocabEntry(normalizedWord: "observe")
        let entry = try XCTUnwrap(storedEntry)
        XCTAssertEqual(entry.primaryZh, "观察；遵守")
        XCTAssertEqual(entry.ukIPA, "/əbˈzɜːv/")
        XCTAssertEqual(entry.usIPA, "/əbˈzɝːv/")
        XCTAssertEqual(entry.exampleEN, "They observe quietly.")
        XCTAssertEqual(entry.exampleZH, "他们静静观察。")
        XCTAssertEqual(
            try JSONDecoder().decode([LookupSense].self, from: Data(entry.sensesJSON.utf8)),
            [LookupSense(pos: .v, zh: "观察")]
        )
    }

    func testRequeryOverridesSnapshot() async throws {
        let database = try AppDatabase.makeTransient()
        let inserted = try await database.upsertVocabEntry(
            word: "Observe",
            context: "Original context",
            primaryZh: "旧释义",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"旧\"}]",
            ukIPA: "/old/",
            usIPA: nil,
            exampleEN: "old example",
            exampleZH: "旧例句",
            bookId: nil,
            now: Date(lexiTimestamp: 1_800_000_030)
        )

        guard case .inserted(let id) = inserted else {
            return XCTFail("Expected inserted result")
        }

        let snapshot = VocabSnapshot.make(
            word: "Observe",
            lookup: LookupResult(
                senses: [LookupSense(pos: .v, zh: "新释义")],
                contextualMeaning: "新释义",
                synonyms: nil,
                example: LookupExample(en: "new example", zh: "新例句")
            ),
            localEntry: LocalDictionaryEntry(ukIPA: "/new/", usIPA: "/new-us/", partsOfSpeech: ["v."], rawDefinition: nil)
        )
        try await database.refreshVocabSnapshot(
            id: id,
            context: "Original context",
            snapshot: snapshot,
            now: Date(lexiTimestamp: 1_800_000_040)
        )

        let storedEntry = try await database.vocabEntry(normalizedWord: "observe")
        let entry = try XCTUnwrap(storedEntry)
        XCTAssertEqual(entry.context, "Original context")
        XCTAssertEqual(entry.primaryZh, "新释义")
        XCTAssertEqual(entry.ukIPA, "/new/")
        XCTAssertEqual(entry.usIPA, "/new-us/")
        XCTAssertEqual(entry.exampleEN, "new example")
        XCTAssertEqual(entry.exampleZH, "新例句")
        XCTAssertEqual(entry.updatedAt, Date(lexiTimestamp: 1_800_000_040))
    }

    func testReAddDoesNotOverwriteSnapshot() async throws {
        let database = try AppDatabase.makeTransient()
        _ = try await database.upsertVocabEntry(
            word: "Observe",
            context: "Original context",
            primaryZh: "原始释义",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"原始\"}]",
            ukIPA: "/original/",
            usIPA: nil,
            exampleEN: "original example",
            exampleZH: "原始例句",
            bookId: "book-a",
            now: Date(lexiTimestamp: 1_800_000_030)
        )

        _ = try await database.upsertVocabEntry(
            word: "observe",
            context: "New context",
            primaryZh: "新释义",
            sensesJSON: "[{\"pos\":\"v\",\"zh\":\"新\"}]",
            ukIPA: "/new/",
            usIPA: "/new-us/",
            exampleEN: "new example",
            exampleZH: "新例句",
            bookId: "book-b",
            now: Date(lexiTimestamp: 1_800_000_040)
        )

        let storedEntry = try await database.vocabEntry(normalizedWord: "observe")
        let entry = try XCTUnwrap(storedEntry)
        XCTAssertEqual(entry.context, "Original context")
        XCTAssertEqual(entry.primaryZh, "原始释义")
        XCTAssertEqual(entry.ukIPA, "/original/")
        XCTAssertEqual(entry.exampleEN, "original example")
        XCTAssertEqual(entry.exampleZH, "原始例句")
        XCTAssertEqual(entry.seenInBookIds, ["book-a", "book-b"])
    }

    func testToggleMasteredUpdatesMasteredAt() async throws {
        let database = try AppDatabase.makeTransient()
        let inserted = try await database.upsertVocabEntry(
            word: "Observe",
            context: nil,
            primaryZh: "观察",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: nil,
            now: Date(lexiTimestamp: 1_800_000_030)
        )
        guard case .inserted(let id) = inserted else {
            return XCTFail("Expected inserted result")
        }

        try await database.setVocabEntryMastered(
            id: id,
            mastered: true,
            now: Date(lexiTimestamp: 1_800_000_040)
        )
        var storedEntry = try await database.vocabEntry(normalizedWord: "observe")
        var entry = try XCTUnwrap(storedEntry)
        XCTAssertTrue(entry.mastered)
        XCTAssertEqual(entry.masteredAt, Date(lexiTimestamp: 1_800_000_040))

        try await database.setVocabEntryMastered(
            id: id,
            mastered: false,
            now: Date(lexiTimestamp: 1_800_000_050)
        )
        storedEntry = try await database.vocabEntry(normalizedWord: "observe")
        entry = try XCTUnwrap(storedEntry)
        XCTAssertFalse(entry.mastered)
        XCTAssertNil(entry.masteredAt)
    }

    func testTodayAddedCountUsesLocalStartOfDay() async throws {
        let database = try AppDatabase.makeTransient()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 21, hour: 12))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 23))!

        _ = try await database.upsertVocabEntry(
            word: "today",
            context: nil,
            primaryZh: "今天",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: nil,
            now: today
        )
        _ = try await database.upsertVocabEntry(
            word: "yesterday",
            context: nil,
            primaryZh: "昨天",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: nil,
            now: yesterday
        )

        let stats = try await database.vocabStats(now: today, calendar: calendar)
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.addedToday, 1)
    }

    func testUnmasteredCount() async throws {
        let database = try AppDatabase.makeTransient()
        let first = try await database.upsertVocabEntry(
            word: "one",
            context: nil,
            primaryZh: "一",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: nil
        )
        _ = try await database.upsertVocabEntry(
            word: "two",
            context: nil,
            primaryZh: "二",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            bookId: nil
        )
        if case .inserted(let id) = first {
            try await database.setVocabEntryMastered(id: id, mastered: true)
        }

        let stats = try await database.vocabStats()
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.unmastered, 1)
        let unmasteredCount = try await database.unmasteredVocabCount()
        XCTAssertEqual(unmasteredCount, 1)
    }

    func testMarkdownExportRespectsCurrentFilter() async throws {
        let unmastered = VocabEntry(
            id: 1,
            word: "observe",
            normalizedWord: "observe",
            context: "They observe quietly.",
            primaryZh: "观察",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: "/əbˈzɝːv/",
            exampleEN: nil,
            exampleZH: nil,
            seenInBooks: "[\"book-a\"]",
            seenGlobally: false,
            mastered: false,
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            updatedAt: Date(lexiTimestamp: 1_800_000_000),
            masteredAt: nil
        )
        let markdown = VocabMarkdownExporter.markdown(
            entries: [unmastered],
            bookTitles: ["book-a": "Co-Intelligence"],
            filterDescription: "未掌握 · Co-Intelligence",
            exportedAt: Date(lexiTimestamp: 1_800_000_100)
        )

        XCTAssertTrue(markdown.contains("> 共 1 条 · 筛选条件：未掌握 · Co-Intelligence"))
        XCTAssertTrue(markdown.contains("## observe /əbˈzɝːv/"))
        XCTAssertTrue(markdown.contains("- 来源：Co-Intelligence"))
        XCTAssertTrue(markdown.contains("- 状态：未掌握"))
    }

    private func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "LexiTests", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "\(UUID().uuidString).sqlite")
    }

    private func insertBookWithOneTranslation(
        id: String,
        database: AppDatabase,
        date: Date
    ) async throws -> (chapterId: Int64, paragraphId: Int64) {
        try await database.insertBook(
            Book(
                id: id,
                title: id,
                author: "Author",
                fileURL: URL(fileURLWithPath: "/tmp/\(id).epub"),
                addedAt: date,
                lastReadAt: nil,
                progress: 0,
                coverData: nil,
                coverBg: nil,
                coverInk: nil
            )
        )
        let chapterId = try await database.insertChapter(
            Chapter(id: nil, bookId: id, idx: 0, n: "1", title: "Chapter")
        )
        let paragraphId = try await database.insertParagraph(
            Paragraph(id: nil, chapterId: chapterId, ord: 0, en: "Text")
        )
        try await database.upsertTranslation(
            Translation(id: nil, paragraphId: paragraphId, engine: .openai, model: "gpt", zh: "译文", createdAt: date)
        )
        return (chapterId, paragraphId)
    }

    private func audioCacheRecord(
        cacheKey: String,
        bookId: String,
        chapterId: Int64,
        fileURL: URL,
        byteCount: Int64,
        date: Date
    ) -> AudioCacheRecord {
        AudioCacheRecord(
            cacheKey: cacheKey,
            bookId: bookId,
            chapterId: chapterId,
            paragraphStart: 0,
            paragraphEnd: 0,
            language: .source,
            provider: .doubao,
            resourceId: "seed-tts-2.0",
            speaker: "voice",
            speechRate: 0,
            profileHash: "profile",
            textHash: "text-\(cacheKey)",
            fileURL: fileURL,
            byteCount: byteCount,
            durationSeconds: nil,
            createdAt: date,
            lastAccessedAt: date
        )
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

    func testGenericKeychainSupportsTTSAccountsSeparately() throws {
        let store = GenericKeychainStore(servicePrefix: "com.lexi.tests.tts.\(UUID().uuidString)")
        defer {
            try? store.delete(account: TTSProviderID.doubao.rawValue)
            try? store.delete(account: TTSProviderID.openai.rawValue)
        }

        XCTAssertNil(try store.apiKey(account: TTSProviderID.doubao.rawValue))
        XCTAssertNil(try store.apiKey(account: TTSProviderID.openai.rawValue))

        try store.setApiKey("doubao-key", account: TTSProviderID.doubao.rawValue)
        try store.setApiKey("openai-key", account: TTSProviderID.openai.rawValue)
        XCTAssertEqual(try store.apiKey(account: TTSProviderID.doubao.rawValue), "doubao-key")
        XCTAssertEqual(try store.apiKey(account: TTSProviderID.openai.rawValue), "openai-key")

        try store.delete(account: TTSProviderID.doubao.rawValue)
        XCTAssertNil(try store.apiKey(account: TTSProviderID.doubao.rawValue))
        XCTAssertEqual(try store.apiKey(account: TTSProviderID.openai.rawValue), "openai-key")
    }

    func testSettingsKeychainPersistenceTrimsAndSavesEngineKeys() throws {
        var setCalls: [(EngineID, String)] = []
        var deleteCalls: [EngineID] = []
        let persistence = SettingsKeychainPersistence(
            setEngineAPIKey: { key, engine in setCalls.append((engine, key)) },
            deleteEngineAPIKey: { engine in deleteCalls.append(engine) },
            setTTSAPIKey: { _, _ in },
            deleteTTSAPIKey: { _ in }
        )

        let result = try persistence.saveEngineAPIKeys(
            apiKeys: [
                .openai: "  openai-key  ",
                .anthropic: "   ",
                .deepseek: "deepseek-key",
            ],
            loadedKeys: [
                .openai: "",
                .anthropic: "old-key",
                .deepseek: "deepseek-key",
            ]
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.savedValues[.openai], "openai-key")
        XCTAssertEqual(result.savedValues[.anthropic], "")
        XCTAssertEqual(result.savedValues[.deepseek], "deepseek-key")
        XCTAssertEqual(setCalls.map(\.0), [.openai, .deepseek])
        XCTAssertEqual(setCalls.map(\.1), ["openai-key", "deepseek-key"])
        XCTAssertEqual(deleteCalls, [.anthropic])
    }

    func testSettingsKeychainPersistenceSurfacesEngineSaveFailure() throws {
        enum TestError: Error {
            case failed
        }

        let persistence = SettingsKeychainPersistence(
            setEngineAPIKey: { _, engine in
                if engine == .openai {
                    throw TestError.failed
                }
            },
            deleteEngineAPIKey: { _ in },
            setTTSAPIKey: { _, _ in },
            deleteTTSAPIKey: { _ in }
        )

        XCTAssertThrowsError(
            try persistence.saveEngineAPIKeys(apiKeys: [.openai: "key"], loadedKeys: [:])
        ) { error in
            XCTAssertEqual(error as? SettingsKeychainSaveError, .engine(.openai))
        }
    }

    func testSettingsKeychainPersistenceSurfacesTTSFailure() throws {
        enum TestError: Error {
            case failed
        }

        let persistence = SettingsKeychainPersistence(
            setEngineAPIKey: { _, _ in },
            deleteEngineAPIKey: { _ in },
            setTTSAPIKey: { _, _ in throw TestError.failed },
            deleteTTSAPIKey: { _ in }
        )

        XCTAssertThrowsError(
            try persistence.saveTTSAPIKey("openai-key", loadedKey: "", provider: .openai)
        ) { error in
            XCTAssertEqual(error as? SettingsKeychainSaveError, .tts(.openai))
        }
    }
}

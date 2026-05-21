import Foundation
import GRDB

actor AppDatabase {
    let pool: DatabasePool

    init(pool: DatabasePool) throws {
        self.pool = pool
        try Self.migrate(pool)
    }

    static func makeShared() throws -> AppDatabase {
        let url = try sharedDatabaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let pool = try DatabasePool(path: url.path)
        return try AppDatabase(pool: pool)
    }

    static func makeTransient() throws -> AppDatabase {
        let directory = FileManager.default.temporaryDirectory.appending(path: "LexiTests", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(UUID().uuidString).sqlite")
        let pool = try DatabasePool(path: url.path)
        return try AppDatabase(pool: pool)
    }

    func migrate() throws {
        try Self.migrate(pool)
    }

    private static func migrate(_ pool: DatabasePool) throws {
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(pool)
    }

    func insertBook(_ book: Book) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO books (
                    id, title, author, fileURL, addedAt, lastReadAt, progress, coverData, coverBg, coverInk
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    book.id,
                    book.title,
                    book.author,
                    book.fileURL.absoluteString,
                    book.addedAt.lexiTimestamp,
                    book.lastReadAt?.lexiTimestamp,
                    book.progress,
                    book.coverData,
                    book.coverBg,
                    book.coverInk,
                ]
            )
        }
    }

    func book(id: String) throws -> Book? {
        try pool.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM books WHERE id = ? LIMIT 1", arguments: [id]).map(Book.init(row:))
        }
    }

    func books() throws -> [Book] {
        try pool.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM books
                ORDER BY COALESCE(lastReadAt, addedAt) DESC, title COLLATE NOCASE ASC
                """
            ).map(Book.init(row:))
        }
    }

    func chapters(bookId: String) throws -> [Chapter] {
        try pool.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM chapters WHERE bookId = ? ORDER BY idx",
                arguments: [bookId]
            ).map(Chapter.init(row:))
        }
    }

    func paragraphs(chapterId: Int64) throws -> [Paragraph] {
        try pool.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM paragraphs WHERE chapterId = ? ORDER BY ord",
                arguments: [chapterId]
            ).map(Paragraph.init(row:))
        }
    }

    func cachedTranslations(chapterId: Int64, engine: EngineID, model: String) throws -> [Int64: String] {
        try pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT p.id AS paragraphId, t.zh AS zh
                FROM paragraphs p
                INNER JOIN translations t ON t.paragraphId = p.id
                WHERE p.chapterId = ? AND t.engine = ? AND t.model = ?
                ORDER BY p.ord
                """,
                arguments: [chapterId, engine.rawValue, model]
            )

            return Dictionary(uniqueKeysWithValues: rows.map { row in
                (row["paragraphId"] as Int64, row["zh"] as String)
            })
        }
    }

    func cachedTranslations(chapterId: Int64, preferredEngine: EngineID, preferredModel: String) throws -> [Int64: String] {
        try pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    p.id AS paragraphId,
                    COALESCE(pt.zh, at.zh) AS zh
                FROM paragraphs p
                LEFT JOIN translations pt
                    ON pt.paragraphId = p.id AND pt.engine = ? AND pt.model = ?
                LEFT JOIN translations at
                    ON at.id = (
                        SELECT t.id
                        FROM translations t
                        WHERE t.paragraphId = p.id
                        ORDER BY t.createdAt DESC, t.id DESC
                        LIMIT 1
                    )
                WHERE p.chapterId = ? AND COALESCE(pt.zh, at.zh) IS NOT NULL
                ORDER BY p.ord
                """,
                arguments: [preferredEngine.rawValue, preferredModel, chapterId]
            )

            return Dictionary(uniqueKeysWithValues: rows.map { row in
                (row["paragraphId"] as Int64, row["zh"] as String)
            })
        }
    }

    func insertChapter(_ chapter: Chapter) throws -> Int64 {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO chapters (bookId, idx, n, title)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [chapter.bookId, chapter.idx, chapter.n, chapter.title]
            )
            return db.lastInsertedRowID
        }
    }

    func insertParagraph(_ paragraph: Paragraph) throws -> Int64 {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO paragraphs (chapterId, ord, en)
                VALUES (?, ?, ?)
                """,
                arguments: [paragraph.chapterId, paragraph.ord, paragraph.en]
            )
            return db.lastInsertedRowID
        }
    }

    func importBook(_ payload: (book: Book, chapters: [(Chapter, [Paragraph])])) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO books (
                    id, title, author, fileURL, addedAt, lastReadAt, progress, coverData, coverBg, coverInk
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id)
                DO UPDATE SET
                    title = excluded.title,
                    author = excluded.author,
                    fileURL = excluded.fileURL,
                    addedAt = excluded.addedAt,
                    lastReadAt = excluded.lastReadAt,
                    progress = excluded.progress,
                    coverData = excluded.coverData,
                    coverBg = excluded.coverBg,
                    coverInk = excluded.coverInk
                """,
                arguments: [
                    payload.book.id,
                    payload.book.title,
                    payload.book.author,
                    payload.book.fileURL.absoluteString,
                    payload.book.addedAt.lexiTimestamp,
                    payload.book.lastReadAt?.lexiTimestamp,
                    payload.book.progress,
                    payload.book.coverData,
                    payload.book.coverBg,
                    payload.book.coverInk,
                ]
            )

            try db.execute(sql: "DELETE FROM chapters WHERE bookId = ?", arguments: [payload.book.id])

            for (chapter, paragraphs) in payload.chapters {
                try db.execute(
                    sql: """
                    INSERT INTO chapters (bookId, idx, n, title)
                    VALUES (?, ?, ?, ?)
                    """,
                    arguments: [payload.book.id, chapter.idx, chapter.n, chapter.title]
                )
                let chapterId = db.lastInsertedRowID

                for paragraph in paragraphs {
                    try db.execute(
                        sql: """
                        INSERT INTO paragraphs (chapterId, ord, en)
                        VALUES (?, ?, ?)
                        """,
                        arguments: [chapterId, paragraph.ord, paragraph.en]
                    )
                }
            }
        }
    }

    func touchBook(id: String, at date: Date = Date()) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE books SET lastReadAt = ? WHERE id = ?",
                arguments: [date.lexiTimestamp, id]
            )
        }
    }

    func updateBookProgress(id: String, progress: Double, at date: Date = Date()) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                UPDATE books
                SET progress = ?, lastReadAt = ?
                WHERE id = ?
                """,
                arguments: [max(0, min(1, progress)), date.lexiTimestamp, id]
            )
        }
    }

    func deleteBook(id: String) throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM books WHERE id = ?", arguments: [id])
        }
    }

    func translationCacheBytes(bookId: String) throws -> Int64 {
        try pool.read { db in
            try Int64.fetchOne(
                db,
                sql: """
                SELECT COALESCE(SUM(LENGTH(t.zh)), 0)
                FROM translations t
                INNER JOIN paragraphs p ON p.id = t.paragraphId
                INNER JOIN chapters c ON c.id = p.chapterId
                WHERE c.bookId = ?
                """,
                arguments: [bookId]
            ) ?? 0
        }
    }

    func clearTranslationCache(bookId: String) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                DELETE FROM translations
                WHERE paragraphId IN (
                    SELECT p.id
                    FROM paragraphs p
                    INNER JOIN chapters c ON c.id = p.chapterId
                    WHERE c.bookId = ?
                )
                """,
                arguments: [bookId]
            )
        }
    }

    func bookCount() throws -> Int {
        try countRows(in: "books")
    }

    func chapterCount() throws -> Int {
        try countRows(in: "chapters")
    }

    func paragraphCount() throws -> Int {
        try countRows(in: "paragraphs")
    }

    func upsertTranslation(_ translation: Translation) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO translations (paragraphId, engine, model, zh, createdAt)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(paragraphId, engine, model)
                DO UPDATE SET zh = excluded.zh, createdAt = excluded.createdAt
                """,
                arguments: [
                    translation.paragraphId,
                    translation.engine.rawValue,
                    translation.model,
                    translation.zh,
                    translation.createdAt.lexiTimestamp,
                ]
            )
        }
    }

    func cachedTranslation(paragraphId: Int64, engine: EngineID, model: String) throws -> String? {
        try pool.read { db in
            try String.fetchOne(
                db,
                sql: """
                SELECT zh FROM translations
                WHERE paragraphId = ? AND engine = ? AND model = ?
                LIMIT 1
                """,
                arguments: [paragraphId, engine.rawValue, model]
            )
        }
    }

    @discardableResult
    func upsertVocabEntry(
        word: String,
        context: String?,
        primaryZh: String,
        sensesJSON: String,
        ukIPA: String?,
        usIPA: String?,
        exampleEN: String?,
        exampleZH: String?,
        bookId: String?,
        now: Date = .init()
    ) throws -> VocabUpsertResult {
        try pool.write { db in
            let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayWord = trimmedWord.isEmpty ? word : trimmedWord
            let normalized = VocabEntry.normalized(displayWord)
            guard !normalized.isEmpty else {
                throw NSError(
                    domain: "LexiDatabase",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot add an empty vocab entry."]
                )
            }

            if let existing = try Row.fetchOne(
                db,
                sql: "SELECT id, seenInBooks FROM vocab WHERE normalizedWord = ? LIMIT 1",
                arguments: [normalized]
            ) {
                let id: Int64 = existing["id"]
                let seenInBooks: String = existing["seenInBooks"]
                let booksJSON = Self.mergedSeenInBooks(existing: seenInBooks, adding: bookId)

                try db.execute(
                    sql: """
                    UPDATE vocab
                    SET updatedAt = ?, seenInBooks = ?
                    WHERE id = ?
                    """,
                    arguments: [now.lexiTimestamp, booksJSON, id]
                )
                return .updated(id: id)
            }

            let booksJSON = Self.mergedSeenInBooks(existing: "[]", adding: bookId)
            try db.execute(
                sql: """
                INSERT INTO vocab (
                    word, normalizedWord, context, primaryZh, sensesJSON,
                    ukIPA, usIPA, exampleEN, exampleZH, seenInBooks,
                    mastered, addedAt, updatedAt
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
                """,
                arguments: [
                    displayWord,
                    normalized,
                    context,
                    primaryZh,
                    sensesJSON,
                    ukIPA,
                    usIPA,
                    exampleEN,
                    exampleZH,
                    booksJSON,
                    now.lexiTimestamp,
                    now.lexiTimestamp,
                ]
            )
            return .inserted(id: db.lastInsertedRowID)
        }
    }

    func vocabEntry(normalizedWord: String) throws -> VocabEntry? {
        try pool.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM vocab WHERE normalizedWord = ? LIMIT 1",
                arguments: [VocabEntry.normalized(normalizedWord)]
            ).map(VocabEntry.init(row:))
        }
    }

    func refreshVocabSnapshot(
        id: Int64,
        context: String?,
        snapshot: VocabSnapshot,
        now: Date = .init()
    ) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                UPDATE vocab
                SET context = ?,
                    primaryZh = ?,
                    sensesJSON = ?,
                    ukIPA = ?,
                    usIPA = ?,
                    exampleEN = ?,
                    exampleZH = ?,
                    updatedAt = ?
                WHERE id = ?
                """,
                arguments: [
                    context,
                    snapshot.primaryZh,
                    snapshot.sensesJSON,
                    snapshot.ukIPA,
                    snapshot.usIPA,
                    snapshot.exampleEN,
                    snapshot.exampleZH,
                    now.lexiTimestamp,
                    id,
                ]
            )
        }
    }

    func vocabEntries(bookId: String?) throws -> [VocabEntry] {
        try pool.read { db in
            let entries = try Row.fetchAll(db, sql: "SELECT * FROM vocab ORDER BY updatedAt DESC, id DESC")
                .map(VocabEntry.init(row:))
            if let bookId {
                return entries.filter { $0.seenInBookIds.contains(bookId) }
            }

            return entries.filter { $0.seenInBookIds.isEmpty }
        }
    }

    func allVocabEntries() throws -> [VocabEntry] {
        try pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM vocab ORDER BY addedAt DESC, id DESC")
                .map(VocabEntry.init(row:))
        }
    }

    func vocabCount() throws -> Int {
        try countRows(in: "vocab")
    }

    func deleteVocabEntries(ids: Set<Int64>) throws {
        guard !ids.isEmpty else {
            return
        }

        try pool.write { db in
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            try db.execute(
                sql: "DELETE FROM vocab WHERE id IN (\(placeholders))",
                arguments: StatementArguments(Array(ids))
            )
        }
    }

    private static func mergedSeenInBooks(existing: String, adding bookId: String?) -> String {
        var books = (try? JSONDecoder().decode([String].self, from: Data(existing.utf8))) ?? []
        if let bookId, !bookId.isEmpty, !books.contains(bookId) {
            books.append(bookId)
        }
        return (try? String(data: JSONEncoder().encode(books), encoding: .utf8)) ?? existing
    }

    func bookTitlesById() throws -> [String: String] {
        try pool.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, title FROM books")
            return Dictionary(uniqueKeysWithValues: rows.map { row in
                (row["id"] as String, row["title"] as String)
            })
        }
    }

    func translationCacheBytes() throws -> Int64 {
        try pool.read { db in
            try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(LENGTH(zh)), 0) FROM translations") ?? 0
        }
    }

    func clearTranslationCache() throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM translations")
        }
    }

    func upsertProgress(_ record: ProgressRecord) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO progress (bookId, chapterIdx, scrollPct, updatedAt)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(bookId)
                DO UPDATE SET
                    chapterIdx = excluded.chapterIdx,
                    scrollPct = excluded.scrollPct,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    record.bookId,
                    record.chapterIdx,
                    record.scrollPct,
                    record.updatedAt.lexiTimestamp,
                ]
            )
        }
    }

    func progress(for bookId: String) throws -> ProgressRecord? {
        try pool.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM progress WHERE bookId = ? LIMIT 1",
                arguments: [bookId]
            ).map(ProgressRecord.init(row:))
        }
    }

    func upsertEngineConfig(_ config: EngineConfig) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO engine_config (engine, model, lastTestedOK, lastTestedAt)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(engine)
                DO UPDATE SET
                    model = excluded.model,
                    lastTestedOK = excluded.lastTestedOK,
                    lastTestedAt = excluded.lastTestedAt
                """,
                arguments: [
                    config.id.rawValue,
                    config.model,
                    config.lastTestedOK ? 1 : 0,
                    config.lastTestedAt?.lexiTimestamp,
                ]
            )
        }
    }

    func engineConfig(for engine: EngineID) throws -> EngineConfig? {
        try pool.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM engine_config WHERE engine = ? LIMIT 1",
                arguments: [engine.rawValue]
            ).map(EngineConfig.init(row:))
        }
    }

    func tableNames() throws -> Set<String> {
        try pool.read { db in
            let names = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
            return Set(names)
        }
    }

    func indexNames(on table: String) throws -> Set<String> {
        try pool.read { db in
            let names = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?",
                arguments: [table]
            )
            return Set(names)
        }
    }

    static func sharedDatabaseURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appending(path: "Lexi", directoryHint: .isDirectory).appending(path: "lexi.sqlite")
    }

    private func countRows(in table: String) throws -> Int {
        try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
        }
    }
}

private extension Book {
    init(row: Row) {
        id = row["id"]
        title = row["title"]
        author = row["author"]
        fileURL = URL(string: row["fileURL"] as String) ?? URL(fileURLWithPath: row["fileURL"])
        addedAt = Date(lexiTimestamp: row["addedAt"])
        lastReadAt = (row["lastReadAt"] as Int64?).map(Date.init(lexiTimestamp:))
        progress = row["progress"]
        coverData = row["coverData"]
        coverBg = row["coverBg"]
        coverInk = row["coverInk"]
    }
}

private extension Chapter {
    init(row: Row) {
        id = row["id"]
        bookId = row["bookId"]
        idx = row["idx"]
        n = row["n"]
        title = row["title"]
    }
}

private extension Paragraph {
    init(row: Row) {
        id = row["id"]
        chapterId = row["chapterId"]
        ord = row["ord"]
        en = row["en"]
    }
}

private extension EngineConfig {
    init(row: Row) {
        id = EngineID(rawValue: row["engine"]) ?? .openai
        model = row["model"]
        lastTestedOK = row["lastTestedOK"] != 0
        lastTestedAt = (row["lastTestedAt"] as Int64?).map(Date.init(lexiTimestamp:))
    }
}

private extension VocabEntry {
    init(row: Row) {
        id = row["id"]
        word = row["word"]
        normalizedWord = row["normalizedWord"]
        context = row["context"]
        primaryZh = row["primaryZh"]
        sensesJSON = row["sensesJSON"]
        ukIPA = row["ukIPA"]
        usIPA = row["usIPA"]
        exampleEN = row["exampleEN"]
        exampleZH = row["exampleZH"]
        seenInBooks = row["seenInBooks"]
        mastered = row["mastered"] != 0
        addedAt = Date(lexiTimestamp: row["addedAt"])
        updatedAt = Date(lexiTimestamp: row["updatedAt"])
        masteredAt = (row["masteredAt"] as Int64?).map(Date.init(lexiTimestamp:))
    }
}

private extension ProgressRecord {
    init(row: Row) {
        bookId = row["bookId"]
        chapterIdx = row["chapterIdx"]
        scrollPct = row["scrollPct"]
        updatedAt = Date(lexiTimestamp: row["updatedAt"])
    }
}

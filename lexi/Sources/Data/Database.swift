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

    func insertVocabEntry(_ entry: VocabEntry) throws -> Int64 {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO vocab (word, context, bookId, addedAt)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [entry.word, entry.context, entry.bookId, entry.addedAt.lexiTimestamp]
            )
            return db.lastInsertedRowID
        }
    }

    func vocabEntries(bookId: String?) throws -> [VocabEntry] {
        try pool.read { db in
            if let bookId {
                return try Row.fetchAll(
                    db,
                    sql: "SELECT * FROM vocab WHERE bookId = ? ORDER BY id",
                    arguments: [bookId]
                ).map(VocabEntry.init(row:))
            }

            return try Row.fetchAll(db, sql: "SELECT * FROM vocab WHERE bookId IS NULL ORDER BY id")
                .map(VocabEntry.init(row:))
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
        context = row["context"]
        bookId = row["bookId"]
        addedAt = Date(lexiTimestamp: row["addedAt"])
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

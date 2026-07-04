import Foundation
import GRDB

extension AppDatabase {
    func insertBook(_ book: Book) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO books (
                    id, title, author, fileURL, sourceBookmark, addedAt, lastReadAt, progress, coverData, coverBg, coverInk
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    book.id,
                    book.title,
                    book.author,
                    book.fileURL.absoluteString,
                    book.sourceBookmark,
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

    func importBook(_ payload: (book: Book, chapters: [(Chapter, [Paragraph])])) throws -> ImportOutcome {
        let incomingContentHash = Self.contentHash(for: payload.chapters)
        return try pool.write { db in
            let alreadyImported = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM books WHERE id = ?)",
                arguments: [payload.book.id]
            ) ?? false

            if alreadyImported {
                try db.execute(
                    sql: """
                    UPDATE books
                    SET title = ?,
                        author = ?,
                        fileURL = ?,
                        sourceBookmark = ?,
                        coverData = ?,
                        coverBg = ?,
                        coverInk = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        payload.book.title,
                        payload.book.author,
                        payload.book.fileURL.absoluteString,
                        payload.book.sourceBookmark,
                        payload.book.coverData,
                        payload.book.coverBg,
                        payload.book.coverInk,
                        payload.book.id,
                    ]
                )
                let storedContentHash = try Self.contentHash(bookId: payload.book.id, in: db)
                guard storedContentHash != incomingContentHash else {
                    return .unchanged
                }

                try db.execute(sql: "DELETE FROM chapters WHERE bookId = ?", arguments: [payload.book.id])
                try Self.insertChapters(payload.chapters, bookId: payload.book.id, in: db)
                try Self.clampProgressAfterContentReplacement(bookId: payload.book.id, chapters: payload.chapters, in: db)
                return .contentReplaced
            }

            try db.execute(
                sql: """
                INSERT INTO books (
                    id, title, author, fileURL, sourceBookmark, addedAt, lastReadAt, progress, coverData, coverBg, coverInk
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    payload.book.id,
                    payload.book.title,
                    payload.book.author,
                    payload.book.fileURL.absoluteString,
                    payload.book.sourceBookmark,
                    payload.book.addedAt.lexiTimestamp,
                    payload.book.lastReadAt?.lexiTimestamp,
                    payload.book.progress,
                    payload.book.coverData,
                    payload.book.coverBg,
                    payload.book.coverInk,
                ]
            )

            try Self.insertChapters(payload.chapters, bookId: payload.book.id, in: db)
            return .inserted
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

    func bookTitlesById() throws -> [String: String] {
        try pool.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, title FROM books")
            return Dictionary(uniqueKeysWithValues: rows.map { row in
                (row["id"] as String, row["title"] as String)
            })
        }
    }
}

private extension AppDatabase {
    nonisolated static func insertChapters(
        _ chapters: [(Chapter, [Paragraph])],
        bookId: String,
        in db: Database
    ) throws {
        for (chapter, paragraphs) in chapters.sorted(by: { $0.0.idx < $1.0.idx }) {
            try db.execute(
                sql: """
                INSERT INTO chapters (bookId, idx, n, title)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [bookId, chapter.idx, chapter.n, chapter.title]
            )
            let chapterId = db.lastInsertedRowID

            for paragraph in paragraphs.sorted(by: { $0.ord < $1.ord }) {
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

    nonisolated static func contentHash(for chapters: [(Chapter, [Paragraph])]) -> String {
        chapters
            .sorted(by: { $0.0.idx < $1.0.idx })
            .map { _, paragraphs in
                paragraphs
                    .sorted(by: { $0.ord < $1.ord })
                    .map(\.en)
                    .joined(separator: "\u{1F}")
            }
            .joined(separator: "\u{1E}")
            .lexiSHA256
    }

    nonisolated static func contentHash(bookId: String, in db: Database) throws -> String {
        let chapterIds = try Int64.fetchAll(
            db,
            sql: "SELECT id FROM chapters WHERE bookId = ? ORDER BY idx",
            arguments: [bookId]
        )
        let chapterBodies = try chapterIds.map { chapterId in
            try String.fetchAll(
                db,
                sql: "SELECT en FROM paragraphs WHERE chapterId = ? ORDER BY ord",
                arguments: [chapterId]
            )
            .joined(separator: "\u{1F}")
        }
        return chapterBodies.joined(separator: "\u{1E}").lexiSHA256
    }

    nonisolated static func clampProgressAfterContentReplacement(
        bookId: String,
        chapters: [(Chapter, [Paragraph])],
        in db: Database
    ) throws {
        guard let progress = try Row.fetchOne(
            db,
            sql: "SELECT chapterIdx, scrollPct FROM progress WHERE bookId = ?",
            arguments: [bookId]
        ) else {
            return
        }

        let orderedChapters = chapters.sorted(by: { $0.0.idx < $1.0.idx })
        guard !orderedChapters.isEmpty else {
            try db.execute(sql: "DELETE FROM progress WHERE bookId = ?", arguments: [bookId])
            return
        }

        let chapterIndex = progress["chapterIdx"] as Int
        let scrollPct = progress["scrollPct"] as Double
        let clampedChapterIndex = min(max(0, chapterIndex), orderedChapters.count - 1)
        let paragraphCount = orderedChapters[clampedChapterIndex].1.count
        let clampedScrollPct: Double
        if scrollPct.isFinite, paragraphCount > 0 {
            clampedScrollPct = Double(min(max(0, Int(scrollPct)), paragraphCount - 1))
        } else {
            clampedScrollPct = 0
        }

        try db.execute(
            sql: """
            UPDATE progress
            SET chapterIdx = ?,
                scrollPct = ?
            WHERE bookId = ?
            """,
            arguments: [clampedChapterIndex, clampedScrollPct, bookId]
        )
    }
}

nonisolated enum BookFileStorage {
    static func booksDirectory(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support
            .appending(path: "Lexi", directoryHint: .isDirectory)
            .appending(path: "Books", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func copyIntoLibrary(
        sourceURL: URL,
        bookId: String,
        booksDirectory explicitBooksDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try (explicitBooksDirectory ?? booksDirectory(fileManager: fileManager)).standardizedFileURL
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "epub" : sourceURL.pathExtension
        let destination = directory.appending(path: "\(bookId).\(fileExtension)").standardizedFileURL
        let source = sourceURL.standardizedFileURL
        guard source.path != destination.path else {
            return destination
        }

        let replacement = directory
            .appending(path: "\(bookId)-\(UUID().uuidString).\(fileExtension).tmp")
            .standardizedFileURL
        defer {
            try? fileManager.removeItem(at: replacement)
        }
        try fileManager.copyItem(at: source, to: replacement)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: replacement)
        } else {
            try fileManager.moveItem(at: replacement, to: destination)
        }
        return destination
    }

    static func importStagingDirectory(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support
            .appending(path: "Lexi", directoryHint: .isDirectory)
            .appending(path: "BookImports", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func copyToImportStaging(
        sourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try importStagingDirectory(fileManager: fileManager)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = sourceURL.lastPathComponent.isEmpty ? "Dropped.epub" : sourceURL.lastPathComponent
        let destination = directory.appending(path: fileName).standardizedFileURL
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func removeImportStagingIfNeeded(
        at url: URL,
        fileManager: FileManager = .default
    ) {
        guard let stagingDirectory = try? importStagingDirectory(fileManager: fileManager).standardizedFileURL else {
            return
        }
        let stagedFile = url.standardizedFileURL
        guard contains(stagedFile, in: stagingDirectory) else {
            return
        }
        try? fileManager.removeItem(at: stagedFile.deletingLastPathComponent())
    }

    static func removeStoredCopy(
        at url: URL,
        booksDirectory explicitBooksDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        let directory = try (explicitBooksDirectory ?? booksDirectory(fileManager: fileManager)).standardizedFileURL
        let target = url.standardizedFileURL
        guard contains(target, in: directory), fileManager.fileExists(atPath: target.path) else {
            return
        }
        try fileManager.removeItem(at: target)
    }

    private static func contains(_ url: URL, in directory: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        return path == directoryPath || path.hasPrefix(directoryPath + "/")
    }
}

private extension Book {
    nonisolated init(row: Row) {
        id = row["id"]
        title = row["title"]
        author = row["author"]
        fileURL = URL(string: row["fileURL"] as String) ?? URL(fileURLWithPath: row["fileURL"])
        sourceBookmark = row["sourceBookmark"]
        addedAt = Date(lexiTimestamp: row["addedAt"])
        lastReadAt = (row["lastReadAt"] as Int64?).map(Date.init(lexiTimestamp:))
        progress = row["progress"]
        coverData = row["coverData"]
        coverBg = row["coverBg"]
        coverInk = row["coverInk"]
    }
}

private extension Chapter {
    nonisolated init(row: Row) {
        id = row["id"]
        bookId = row["bookId"]
        idx = row["idx"]
        n = row["n"]
        title = row["title"]
    }
}

private extension Paragraph {
    nonisolated init(row: Row) {
        id = row["id"]
        chapterId = row["chapterId"]
        ord = row["ord"]
        en = row["en"]
    }
}

import Foundation
import GRDB

extension AppDatabase {
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
                        coverData = ?,
                        coverBg = ?,
                        coverInk = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        payload.book.title,
                        payload.book.author,
                        payload.book.fileURL.absoluteString,
                        payload.book.coverData,
                        payload.book.coverBg,
                        payload.book.coverInk,
                        payload.book.id,
                    ]
                )
                return
            }

            try db.execute(
                sql: """
                INSERT INTO books (
                    id, title, author, fileURL, addedAt, lastReadAt, progress, coverData, coverBg, coverInk
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

    func bookTitlesById() throws -> [String: String] {
        try pool.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, title FROM books")
            return Dictionary(uniqueKeysWithValues: rows.map { row in
                (row["id"] as String, row["title"] as String)
            })
        }
    }
}

private extension Book {
    nonisolated init(row: Row) {
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

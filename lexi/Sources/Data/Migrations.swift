import Foundation
import GRDB

enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        registerV1Initial(in: &migrator)
        registerV2VocabEnrichment(in: &migrator)
    }

    static func registerV1Initial(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "books") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("author", .text).notNull()
                table.column("fileURL", .text).notNull()
                table.column("addedAt", .integer).notNull()
                table.column("lastReadAt", .integer)
                table.column("progress", .double).notNull()
                table.column("coverData", .blob)
                table.column("coverBg", .text)
                table.column("coverInk", .text)
            }

            try db.create(table: "chapters") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("bookId", .text)
                    .notNull()
                    .references("books", onDelete: .cascade)
                table.column("idx", .integer).notNull()
                table.column("n", .text).notNull()
                table.column("title", .text).notNull()
                table.uniqueKey(["bookId", "idx"])
            }

            try db.create(table: "paragraphs") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("chapterId", .integer)
                    .notNull()
                    .references("chapters", onDelete: .cascade)
                table.column("ord", .integer).notNull()
                table.column("en", .text).notNull()
                table.uniqueKey(["chapterId", "ord"])
            }

            try db.create(table: "translations") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("paragraphId", .integer)
                    .notNull()
                    .references("paragraphs", onDelete: .cascade)
                table.column("engine", .text).notNull()
                table.column("model", .text).notNull()
                table.column("zh", .text).notNull()
                table.column("createdAt", .integer).notNull()
                table.uniqueKey(["paragraphId", "engine", "model"])
            }

            try db.create(index: "translations_paragraph_engine_idx", on: "translations", columns: ["paragraphId", "engine"])

            try db.create(table: "vocab") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("word", .text).notNull()
                table.column("context", .text)
                table.column("bookId", .text).references("books", onDelete: .setNull)
                table.column("addedAt", .integer).notNull()
            }

            try db.create(table: "progress") { table in
                table.column("bookId", .text)
                    .primaryKey()
                    .references("books", onDelete: .cascade)
                table.column("chapterIdx", .integer).notNull()
                table.column("scrollPct", .double).notNull()
                table.column("updatedAt", .integer).notNull()
            }

            try db.create(table: "engine_config") { table in
                table.column("engine", .text).primaryKey()
                table.column("model", .text).notNull()
                table.column("lastTestedOK", .integer).notNull()
                table.column("lastTestedAt", .integer)
            }
        }
    }

    private static func registerV2VocabEnrichment(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2_vocab_enrichment") { db in
            try db.create(table: "vocab_new") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("word", .text).notNull()
                table.column("normalizedWord", .text).notNull().unique()
                table.column("context", .text)
                table.column("primaryZh", .text).notNull().defaults(to: "")
                table.column("sensesJSON", .text).notNull().defaults(to: "[]")
                table.column("ukIPA", .text)
                table.column("usIPA", .text)
                table.column("exampleEN", .text)
                table.column("exampleZH", .text)
                table.column("seenInBooks", .text).notNull().defaults(to: "[]")
                table.column("mastered", .integer).notNull().defaults(to: 0)
                table.column("addedAt", .integer).notNull()
                table.column("updatedAt", .integer).notNull()
                table.column("masteredAt", .integer)
            }
            let legacyRows = try Row.fetchAll(
                db,
                sql: "SELECT id, word, context, bookId, addedAt FROM vocab ORDER BY id ASC"
            ).compactMap(LegacyVocabRow.init(row:))

            let grouped = Dictionary(grouping: legacyRows, by: \.normalizedWord)
            for normalized in grouped.keys.sorted() {
                guard let rows = grouped[normalized], let first = rows.first else {
                    continue
                }

                var bookIds: [String] = []
                for row in rows {
                    guard let bookId = row.bookId, !bookId.isEmpty, !bookIds.contains(bookId) else {
                        continue
                    }
                    bookIds.append(bookId)
                }

                let booksJSON = LegacyVocabRow.encodeBookIds(bookIds)
                let lastAddedAt = rows.last?.addedAt ?? first.addedAt

                try db.execute(
                    sql: """
                    INSERT INTO vocab_new (
                        word, normalizedWord, context, primaryZh, sensesJSON,
                        seenInBooks, mastered, addedAt, updatedAt
                    )
                    VALUES (?, ?, ?, '', '[]', ?, 0, ?, ?)
                    """,
                    arguments: [
                        first.word,
                        normalized,
                        first.context,
                        booksJSON,
                        first.addedAt,
                        lastAddedAt,
                    ]
                )
            }

            try db.execute(sql: "DROP TABLE vocab")
            try db.rename(table: "vocab_new", to: "vocab")
            try db.create(index: "vocab_mastered_updated_idx", on: "vocab", columns: ["mastered", "updatedAt"])
            try db.create(index: "vocab_added_idx", on: "vocab", columns: ["addedAt"])
        }
    }
}

private struct LegacyVocabRow {
    let word: String
    let normalizedWord: String
    let context: String?
    let bookId: String?
    let addedAt: Int64

    init?(row: Row) {
        let rawWord: String = row["word"]
        let normalized = VocabEntry.normalized(rawWord)
        guard !normalized.isEmpty else {
            return nil
        }

        word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? normalized : rawWord
        normalizedWord = normalized
        context = row["context"]
        bookId = row["bookId"]
        addedAt = row["addedAt"]
    }

    static func encodeBookIds(_ bookIds: [String]) -> String {
        (try? String(data: JSONEncoder().encode(bookIds), encoding: .utf8)) ?? "[]"
    }
}

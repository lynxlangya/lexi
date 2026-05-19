import GRDB

enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
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
}

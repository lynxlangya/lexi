import Foundation
import GRDB

extension AppDatabase {
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
                let markGlobal = bookId == nil ? 1 : 0

                try db.execute(
                    sql: """
                    UPDATE vocab
                    SET updatedAt = ?,
                        seenInBooks = ?,
                        seenGlobally = CASE WHEN ? THEN 1 ELSE seenGlobally END
                    WHERE id = ?
                    """,
                    arguments: [now.lexiTimestamp, booksJSON, markGlobal, id]
                )
                return .updated(id: id)
            }

            let booksJSON = Self.mergedSeenInBooks(existing: "[]", adding: bookId)
            let seenGlobally = bookId == nil ? 1 : 0
            try db.execute(
                sql: """
                INSERT INTO vocab (
                    word, normalizedWord, context, primaryZh, sensesJSON,
                    ukIPA, usIPA, exampleEN, exampleZH, seenInBooks,
                    seenGlobally, mastered, addedAt, updatedAt
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
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
                    seenGlobally,
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

    func setVocabEntryMastered(id: Int64, mastered: Bool, now: Date = .init()) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                UPDATE vocab
                SET mastered = ?, masteredAt = ?, updatedAt = ?
                WHERE id = ?
                """,
                arguments: [
                    mastered ? 1 : 0,
                    mastered ? now.lexiTimestamp : nil,
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

            return entries.filter(\.seenGlobally)
        }
    }

    func allVocabEntries() throws -> [VocabEntry] {
        try pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM vocab ORDER BY addedAt DESC, id DESC")
                .map(VocabEntry.init(row:))
        }
    }

    func vocabCount() throws -> Int {
        try countRows(in: .vocab)
    }

    func unmasteredVocabCount() throws -> Int {
        try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM vocab WHERE mastered = 0") ?? 0
        }
    }

    func vocabStats(now: Date = .init(), calendar: Calendar = .current) throws -> VocabStats {
        let startOfToday = calendar.startOfDay(for: now).lexiTimestamp
        return try pool.read { db in
            let total = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM vocab") ?? 0
            let addedToday = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM vocab WHERE addedAt >= ?",
                arguments: [startOfToday]
            ) ?? 0
            let unmastered = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM vocab WHERE mastered = 0") ?? 0
            return VocabStats(total: total, addedToday: addedToday, unmastered: unmastered)
        }
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
}

private extension VocabEntry {
    nonisolated init(row: Row) {
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
        seenGlobally = row["seenGlobally"] != 0
        mastered = row["mastered"] != 0
        addedAt = Date(lexiTimestamp: row["addedAt"])
        updatedAt = Date(lexiTimestamp: row["updatedAt"])
        masteredAt = (row["masteredAt"] as Int64?).map(Date.init(lexiTimestamp:))
    }
}

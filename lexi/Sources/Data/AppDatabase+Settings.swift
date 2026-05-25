import Foundation
import GRDB

extension AppDatabase {
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
}

private extension ProgressRecord {
    nonisolated init(row: Row) {
        bookId = row["bookId"]
        chapterIdx = row["chapterIdx"]
        scrollPct = row["scrollPct"]
        updatedAt = Date(lexiTimestamp: row["updatedAt"])
    }
}

private extension EngineConfig {
    nonisolated init(row: Row) {
        id = EngineID(rawValue: row["engine"]) ?? .openai
        model = row["model"]
        lastTestedOK = row["lastTestedOK"] != 0
        lastTestedAt = (row["lastTestedAt"] as Int64?).map(Date.init(lexiTimestamp:))
    }
}

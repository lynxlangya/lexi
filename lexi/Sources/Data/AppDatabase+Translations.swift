import Foundation
import GRDB

extension AppDatabase {
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
}

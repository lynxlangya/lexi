import Foundation
import GRDB

extension AppDatabase {
    func audioCacheFileURLs(bookId: String) throws -> [URL] {
        try pool.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT fileURL FROM audio_cache WHERE bookId = ?",
                arguments: [bookId]
            ).compactMap { row in
                let raw: String = row["fileURL"]
                return URL(string: raw) ?? URL(fileURLWithPath: raw)
            }
        }
    }

    func upsertAudioCacheRecord(_ record: AudioCacheRecord) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO audio_cache (
                    cacheKey, bookId, chapterId, paragraphStart, paragraphEnd,
                    language, provider, resourceId, speaker, speechRate,
                    profileHash, textHash, fileURL, byteCount, durationSeconds,
                    createdAt, lastAccessedAt
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(cacheKey)
                DO UPDATE SET
                    fileURL = excluded.fileURL,
                    byteCount = excluded.byteCount,
                    durationSeconds = excluded.durationSeconds,
                    lastAccessedAt = excluded.lastAccessedAt
                """,
                arguments: [
                    record.cacheKey,
                    record.bookId,
                    record.chapterId,
                    record.paragraphStart,
                    record.paragraphEnd,
                    record.language.rawValue,
                    record.provider.rawValue,
                    record.resourceId,
                    record.speaker,
                    record.speechRate,
                    record.profileHash,
                    record.textHash,
                    record.fileURL.absoluteString,
                    record.byteCount,
                    record.durationSeconds,
                    record.createdAt.lexiTimestamp,
                    record.lastAccessedAt.lexiTimestamp,
                ]
            )
        }
    }

    func audioCacheRecord(cacheKey: String, accessedAt: Date? = Date()) throws -> AudioCacheRecord? {
        try pool.write { db in
            if let accessedAt {
                try db.execute(
                    sql: "UPDATE audio_cache SET lastAccessedAt = ? WHERE cacheKey = ?",
                    arguments: [accessedAt.lexiTimestamp, cacheKey]
                )
            }
            return try Row.fetchOne(
                db,
                sql: "SELECT * FROM audio_cache WHERE cacheKey = ? LIMIT 1",
                arguments: [cacheKey]
            ).map(AudioCacheRecord.init(row:))
        }
    }

    func audioCacheBytes() throws -> Int64 {
        try pool.read { db in
            try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(byteCount), 0) FROM audio_cache") ?? 0
        }
    }

    func pruneAudioCache(maxBytes: Int64, cacheDirectory: URL? = try? AudioCacheLocation.directory()) throws -> [URL] {
        let targetBytes = max(0, maxBytes * 9 / 10)
        let standardizedCacheDirectory = cacheDirectory?.standardizedFileURL

        return try pool.write { db in
            var removedFiles: [URL] = []
            var removedPaths = Set<String>()
            func appendRemovedFile(_ url: URL) {
                if removedPaths.insert(url.standardizedFileURL.path).inserted {
                    removedFiles.append(url)
                }
            }
            var totalBytes = try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(byteCount), 0) FROM audio_cache") ?? 0

            if totalBytes > maxBytes {
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT cacheKey, fileURL, byteCount
                    FROM audio_cache
                    ORDER BY lastAccessedAt ASC, createdAt ASC, cacheKey ASC
                    """
                )
                for row in rows where totalBytes > targetBytes {
                    let cacheKey: String = row["cacheKey"]
                    let rawFileURL: String = row["fileURL"]
                    let byteCount: Int64 = row["byteCount"]
                    appendRemovedFile(audioCacheURL(from: rawFileURL))
                    totalBytes -= byteCount
                    try db.execute(sql: "DELETE FROM audio_cache WHERE cacheKey = ?", arguments: [cacheKey])
                }
            }

            if let standardizedCacheDirectory,
               let files = try? FileManager.default.contentsOfDirectory(
                   at: standardizedCacheDirectory,
                   includingPropertiesForKeys: nil
               ) {
                let recordedPaths = Set(try String.fetchAll(db, sql: "SELECT fileURL FROM audio_cache").map {
                    audioCacheURL(from: $0).standardizedFileURL.path
                })
                for file in files where !recordedPaths.contains(file.standardizedFileURL.path) {
                    appendRemovedFile(file)
                }
            }

            return removedFiles
        }
    }

    func clearAudioCache() throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM audio_cache")
        }
    }

    func clearAudioCache(bookId: String) throws -> [URL] {
        try pool.write { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT fileURL FROM audio_cache WHERE bookId = ?",
                arguments: [bookId]
            )
            try db.execute(sql: "DELETE FROM audio_cache WHERE bookId = ?", arguments: [bookId])
            return rows.compactMap { row in
                let raw: String = row["fileURL"]
                return URL(string: raw) ?? URL(fileURLWithPath: raw)
            }
        }
    }

    func upsertNarrationProfile(_ profile: NarrationProfile) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO narration_profiles (
                    bookId, provider, profileHash, genre, tone, pace,
                    pronunciationHints, summary, createdAt, updatedAt
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(bookId)
                DO UPDATE SET
                    provider = excluded.provider,
                    profileHash = excluded.profileHash,
                    genre = excluded.genre,
                    tone = excluded.tone,
                    pace = excluded.pace,
                    pronunciationHints = excluded.pronunciationHints,
                    summary = excluded.summary,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    profile.bookId,
                    profile.provider.rawValue,
                    profile.profileHash,
                    profile.genre,
                    profile.tone,
                    profile.pace,
                    profile.pronunciationHints,
                    profile.summary,
                    profile.createdAt.lexiTimestamp,
                    profile.updatedAt.lexiTimestamp,
                ]
            )
        }
    }

    func narrationProfile(bookId: String) throws -> NarrationProfile? {
        try pool.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM narration_profiles WHERE bookId = ? LIMIT 1",
                arguments: [bookId]
            ).map(NarrationProfile.init(row:))
        }
    }
}

nonisolated private func audioCacheURL(from raw: String) -> URL {
    URL(string: raw) ?? URL(fileURLWithPath: raw)
}

private extension AudioCacheRecord {
    nonisolated init(row: Row) {
        cacheKey = row["cacheKey"]
        bookId = row["bookId"]
        chapterId = row["chapterId"]
        paragraphStart = row["paragraphStart"]
        paragraphEnd = row["paragraphEnd"]
        language = TTSAudioLanguage(rawValue: row["language"]) ?? .source
        provider = TTSProviderID(rawValue: row["provider"]) ?? .doubao
        resourceId = row["resourceId"]
        speaker = row["speaker"]
        speechRate = row["speechRate"]
        profileHash = row["profileHash"]
        textHash = row["textHash"]
        fileURL = audioCacheURL(from: row["fileURL"])
        byteCount = row["byteCount"]
        durationSeconds = row["durationSeconds"]
        createdAt = Date(lexiTimestamp: row["createdAt"])
        lastAccessedAt = Date(lexiTimestamp: row["lastAccessedAt"])
    }
}

private extension NarrationProfile {
    nonisolated init(row: Row) {
        bookId = row["bookId"]
        provider = TTSProviderID(rawValue: row["provider"]) ?? .doubao
        profileHash = row["profileHash"]
        genre = row["genre"]
        tone = row["tone"]
        pace = row["pace"]
        pronunciationHints = row["pronunciationHints"]
        summary = row["summary"]
        createdAt = Date(lexiTimestamp: row["createdAt"])
        updatedAt = Date(lexiTimestamp: row["updatedAt"])
    }
}

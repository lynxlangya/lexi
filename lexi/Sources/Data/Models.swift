import Foundation

enum EngineID: String, Codable, CaseIterable, Sendable {
    case openai
    case anthropic
    case deepseek
}

struct Book: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var author: String
    var fileURL: URL
    var sourceBookmark: Data?
    var addedAt: Date
    var lastReadAt: Date?
    var progress: Double
    var coverData: Data?
    var coverBg: String?
    var coverInk: String?

    init(
        id: String,
        title: String,
        author: String,
        fileURL: URL,
        sourceBookmark: Data? = nil,
        addedAt: Date,
        lastReadAt: Date?,
        progress: Double,
        coverData: Data?,
        coverBg: String?,
        coverInk: String?
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileURL = fileURL
        self.sourceBookmark = sourceBookmark
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
        self.progress = progress
        self.coverData = coverData
        self.coverBg = coverBg
        self.coverInk = coverInk
    }
}

struct Chapter: Codable, Equatable, Identifiable, Sendable {
    var id: Int64?
    var bookId: String
    var idx: Int
    var n: String
    var title: String
}

struct Paragraph: Codable, Equatable, Identifiable, Sendable {
    var id: Int64?
    var chapterId: Int64
    var ord: Int
    var en: String
}

struct Translation: Codable, Equatable, Identifiable, Sendable {
    var id: Int64?
    var paragraphId: Int64
    var engine: EngineID
    var model: String
    var zh: String
    var createdAt: Date
}

struct VocabEntry: Codable, Equatable, Identifiable, Sendable {
    var id: Int64?
    var word: String
    var normalizedWord: String
    var context: String?
    var primaryZh: String
    var sensesJSON: String
    var ukIPA: String?
    var usIPA: String?
    var exampleEN: String?
    var exampleZH: String?
    var seenInBooks: String
    var seenGlobally: Bool
    var mastered: Bool
    var addedAt: Date
    var updatedAt: Date
    var masteredAt: Date?
}

struct VocabStats: Equatable, Sendable {
    var total: Int
    var addedToday: Int
    var unmastered: Int
}

enum VocabUpsertResult: Equatable, Sendable {
    case inserted(id: Int64)
    case updated(id: Int64)
}

enum ImportOutcome: Equatable, Sendable {
    case inserted
    case contentReplaced
    case unchanged
}

extension VocabEntry {
    nonisolated static func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated var seenInBookIds: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(seenInBooks.utf8))) ?? []
    }

    nonisolated var isGlobalSource: Bool {
        seenGlobally
    }
}

struct ProgressRecord: Codable, Equatable, Sendable {
    var bookId: String
    var chapterIdx: Int
    /// v1 stores the 0-based visible paragraph index in this existing column.
    var scrollPct: Double
    var updatedAt: Date
}

struct EngineConfig: Codable, Equatable, Identifiable, Sendable {
    var id: EngineID
    var model: String
    var lastTestedOK: Bool
    var lastTestedAt: Date?
}

struct AudioCacheRecord: Codable, Equatable, Sendable {
    var cacheKey: String
    var bookId: String
    var chapterId: Int64?
    var paragraphStart: Int
    var paragraphEnd: Int
    var language: TTSAudioLanguage
    var provider: TTSProviderID
    var resourceId: String
    var speaker: String
    var speechRate: Int
    var profileHash: String
    var textHash: String
    var fileURL: URL
    var byteCount: Int64
    var durationSeconds: Double?
    var createdAt: Date
    var lastAccessedAt: Date
}

struct NarrationProfile: Codable, Equatable, Sendable {
    var bookId: String
    var provider: TTSProviderID
    var profileHash: String
    var genre: String
    var tone: String
    var pace: String
    var pronunciationHints: String
    var summary: String
    var createdAt: Date
    var updatedAt: Date
}

extension Date {
    nonisolated init(lexiTimestamp: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(lexiTimestamp))
    }

    nonisolated var lexiTimestamp: Int64 {
        Int64(timeIntervalSince1970.rounded())
    }
}

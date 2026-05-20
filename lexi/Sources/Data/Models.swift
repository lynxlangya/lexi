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
    var addedAt: Date
    var lastReadAt: Date?
    var progress: Double
    var coverData: Data?
    var coverBg: String?
    var coverInk: String?
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
    var context: String?
    var bookId: String?
    var addedAt: Date
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

extension Date {
    init(lexiTimestamp: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(lexiTimestamp))
    }

    var lexiTimestamp: Int64 {
        Int64(timeIntervalSince1970.rounded())
    }
}

import Foundation
import XCTest
@testable import lexi

final class ReaderReadAloudTests: XCTestCase {
    func testChunkPlannerStartsFromVisibleParagraphAndPreservesBoundaries() {
        let chapter = makeChapter(paragraphTexts: [
            "One.",
            "Two.",
            String(repeating: "Three ", count: 80),
            "Four.",
        ])
        let chunks = ReadAloudChunkPlanner.chunks(
            for: chapter,
            snapshot: ChapterTranslationSnapshot(),
            language: .source,
            startParagraphId: 2,
            minCharacters: 20,
            maxCharacters: 60,
            maxParagraphs: 1
        )

        XCTAssertEqual(chunks.map(\.paragraphIds), [[2], [3], [4]])
        XCTAssertEqual(chunks.first?.paragraphStart, 1)
        XCTAssertEqual(chunks.first?.paragraphEnd, 1)
        XCTAssertEqual(chunks.first?.text, "Two.")
    }

    func testChunkPlannerUsesCachedTranslationsAndStopsAtMissingTarget() {
        let chapter = makeChapter(paragraphTexts: ["One.", "Two.", "Three."])
        let snapshot = ChapterTranslationSnapshot(
            chapterState: .translating(done: 2),
            paragraphStates: [
                1: .cached("一。"),
                2: .cached("二。"),
                3: .translating,
            ]
        )

        let chunks = ReadAloudChunkPlanner.chunks(
            for: chapter,
            snapshot: snapshot,
            language: .target,
            startParagraphId: 1,
            minCharacters: 1,
            maxCharacters: 50,
            maxParagraphs: 3
        )

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first?.text, "一。\n\n二。")
        XCTAssertEqual(chunks.first?.paragraphIds, [1, 2])
        XCTAssertEqual(
            ReadAloudChunkPlanner.unavailableReason(
                for: .target,
                chapter: chapter,
                snapshot: snapshot,
                startParagraphId: 3
            ),
            "当前段落译文还未缓存，先完成本段翻译后再朗读译文"
        )
    }

    func testAudioResolverUsesCacheHitBeforeProviderCall() async throws {
        let database = try AppDatabase.makeTransient()
        let book = Book(
            id: "book",
            title: "Book",
            author: "Author",
            fileURL: URL(fileURLWithPath: "/tmp/book.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            lastReadAt: nil,
            progress: 0,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        )
        try await database.insertBook(book)
        let chapterId = try await database.insertChapter(Chapter(id: nil, bookId: book.id, idx: 0, n: "1", title: "One"))
        _ = try await database.insertParagraph(Paragraph(id: nil, chapterId: chapterId, ord: 0, en: "Hello."))

        let chunk = ReadAloudChunk(
            bookId: book.id,
            chapterId: chapterId,
            paragraphStart: 0,
            paragraphEnd: 0,
            language: .source,
            text: "Hello.",
            paragraphIds: [1]
        )
        let config = TTSProviderConfig(
            provider: .doubao,
            resourceId: "seed-tts-2.0",
            speaker: "voice",
            speechRate: 0,
            format: "mp3",
            sampleRate: 24_000
        )
        let key = DefaultReadAloudAudioResolver.audioCacheKey(for: chunk, config: config)
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).mp3")
        try Data([0x01, 0x02]).write(to: fileURL)
        let now = Date(lexiTimestamp: 1_800_000_010)
        try await database.upsertAudioCacheRecord(AudioCacheRecord(
            cacheKey: key.value,
            bookId: book.id,
            chapterId: chapterId,
            paragraphStart: chunk.paragraphStart,
            paragraphEnd: chunk.paragraphEnd,
            language: chunk.language,
            provider: config.provider,
            resourceId: config.resourceId,
            speaker: config.speaker,
            speechRate: config.speechRate,
            profileHash: key.profileHash,
            textHash: key.textHash,
            fileURL: fileURL,
            byteCount: 2,
            durationSeconds: nil,
            createdAt: now,
            lastAccessedAt: now
        ))

        let client = ReadAloudFailIfCalledHTTPClient()
        let registry = TTSRegistry(client: client, apiKeyProvider: { _ in "key" })
        let resolvedURL = try await DefaultReadAloudAudioResolver().resolveAudioURL(
            for: chunk,
            database: database,
            registry: registry,
            config: config
        )

        XCTAssertEqual(resolvedURL, fileURL)
        XCTAssertEqual(client.callCount, 0)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func makeChapter(paragraphTexts: [String]) -> ReaderChapter {
        ReaderChapter(
            id: 10,
            bookId: "book",
            idx: 0,
            n: "1",
            title: "Chapter",
            paragraphs: paragraphTexts.enumerated().map { index, text in
                ReaderParagraph(id: Int64(index + 1), ord: index, en: text)
            }
        )
    }
}

private final class ReadAloudFailIfCalledHTTPClient: EngineHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.withLock { _callCount }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { _callCount += 1 }
        throw TTSProviderError.invalidResponse
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        lock.withLock { _callCount += 1 }
        throw TTSProviderError.invalidResponse
    }
}

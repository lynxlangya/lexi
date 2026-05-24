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

    func testPlaybackProgressUsesChunkPositionSemantics() {
        XCTAssertEqual(ReadAloudPlaybackProgress.empty.displayText, "等待")
        XCTAssertEqual(ReadAloudPlaybackProgress.empty.fraction, 0)
        XCTAssertFalse(ReadAloudPlaybackProgress.empty.canMovePrevious)
        XCTAssertFalse(ReadAloudPlaybackProgress.empty.canMoveNext)

        let first = ReadAloudPlaybackProgress(
            currentIndex: 0,
            totalCount: 3,
            currentRange: "段落 1"
        )
        XCTAssertEqual(first.fraction, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(first.displayText, "1 / 3")
        XCTAssertFalse(first.canMovePrevious)
        XCTAssertTrue(first.canMoveNext)

        let last = ReadAloudPlaybackProgress(
            currentIndex: 2,
            totalCount: 3,
            currentRange: "段落 5"
        )
        XCTAssertEqual(last.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(last.displayText, "3 / 3")
        XCTAssertTrue(last.canMovePrevious)
        XCTAssertFalse(last.canMoveNext)
    }

    func testFallbackStatusKeepsConfigurationReasonVisible() {
        let status = ReadAloudPlaybackStatus.fallback("段落 1", "请先配置豆包语音音色 ID")

        XCTAssertEqual(status.label, "系统朗读 · 段落 1 · 请先配置豆包语音音色 ID")
        XCTAssertTrue(status.isActive)
    }

    func testHighlightTargetMatchesOnlyExactChapterParagraphAndLanguage() {
        let target = ReadAloudHighlightTarget(
            chapterId: 10,
            language: .target,
            paragraphIds: [2, 3],
            text: "二。\n\n三。",
            displayRange: "段落 2-3"
        )

        XCTAssertTrue(target.matches(chapterId: 10, paragraphId: 2, language: .target))
        XCTAssertTrue(target.matches(chapterId: 10, paragraphId: 3, language: .target))
        XCTAssertFalse(target.matches(chapterId: 10, paragraphId: 2, language: .source))
        XCTAssertFalse(target.matches(chapterId: 11, paragraphId: 2, language: .target))
        XCTAssertFalse(target.matches(chapterId: 10, paragraphId: 4, language: .target))
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
            paragraphIds: [1],
            profile: nil
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

    func testNarrationPromptInputSamplesMetadataWithoutWholeBook() {
        let longParagraph = String(repeating: "Long sample ", count: 120)
        let book = ReaderBook(
            id: "book",
            title: "  Co-Intelligence\n",
            author: " Ethan Mollick ",
            fileURL: URL(fileURLWithPath: "/tmp/book.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            lastReadAt: nil,
            progress: 0,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        )
        let chapters = (0..<30).map { index in
            ReaderChapter(
                id: Int64(index + 1),
                bookId: book.id,
                idx: index,
                n: "\(index + 1)",
                title: "Chapter \(index + 1)",
                paragraphs: [
                    ReaderParagraph(id: Int64(index + 100), ord: 0, en: longParagraph),
                ]
            )
        }

        let input = NarrationProfilePromptInput.make(
            book: book,
            chapters: chapters,
            currentChapter: chapters[5]
        )

        XCTAssertEqual(input.title, "Co-Intelligence")
        XCTAssertEqual(input.author, "Ethan Mollick")
        XCTAssertEqual(input.chapterTitles.count, 24)
        XCTAssertEqual(input.sampleParagraphs.count, 8)
        XCTAssertTrue(input.sampleParagraphs.allSatisfy { $0.count <= 600 })
        XCTAssertEqual(input.currentChapterTitle, "Chapter 6")
    }

    func testNarrationProfilePayloadDecodesWrappedJSONAndBuildsInstruction() throws {
        let payload = try NarrationProfilePayload.decode("""
        Here is the profile:
        {"genre":"business","tone":"warm explanatory","pace":"natural","pronunciationHints":"AI as A I","summary":"A concise book about working with AI."}
        """)
        let profile = NarrationProfile(
            bookId: "book",
            provider: .doubao,
            profileHash: NarrationProfile.profileHash(provider: .doubao, payload: payload),
            genre: payload.genre,
            tone: payload.tone,
            pace: payload.pace,
            pronunciationHints: payload.pronunciationHints,
            summary: payload.summary,
            createdAt: Date(lexiTimestamp: 1_800_000_000),
            updatedAt: Date(lexiTimestamp: 1_800_000_000)
        )

        XCTAssertEqual(payload.genre, "business")
        XCTAssertTrue(profile.ttsContextInstruction.contains("warm explanatory"))
        XCTAssertTrue(profile.ttsContextInstruction.contains("AI as A I"))
    }

    func testAudioCacheKeyIncludesNarrationProfileHash() {
        let baseProfile = NarrationProfile.neutral(
            bookId: "book",
            provider: .doubao,
            now: Date(lexiTimestamp: 1_800_000_000)
        )
        var expressiveProfile = baseProfile
        expressiveProfile.profileHash = "expressive-profile"
        let baseChunk = ReadAloudChunk(
            bookId: "book",
            chapterId: 1,
            paragraphStart: 0,
            paragraphEnd: 0,
            language: .source,
            text: "Hello.",
            paragraphIds: [1],
            profile: baseProfile
        )
        var expressiveChunk = baseChunk
        expressiveChunk.profile = expressiveProfile
        let config = TTSProviderConfig(
            provider: .doubao,
            resourceId: "seed-tts-2.0",
            speaker: "voice",
            speechRate: 0,
            format: "mp3",
            sampleRate: 24_000
        )

        let baseKey = DefaultReadAloudAudioResolver.audioCacheKey(for: baseChunk, config: config)
        let expressiveKey = DefaultReadAloudAudioResolver.audioCacheKey(for: expressiveChunk, config: config)

        XCTAssertNotEqual(baseKey.value, expressiveKey.value)
        XCTAssertEqual(baseKey.profileHash, baseProfile.profileHash)
    }

    func testNarrationResolverUsesCachedProfileUnlessRefreshIsForced() async throws {
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
        let cached = NarrationProfile(
            bookId: book.id,
            provider: .doubao,
            profileHash: "cached-profile",
            genre: "business",
            tone: "calm",
            pace: "natural",
            pronunciationHints: "",
            summary: "cached",
            createdAt: Date(lexiTimestamp: 1_800_000_001),
            updatedAt: Date(lexiTimestamp: 1_800_000_001)
        )
        try await database.upsertNarrationProfile(cached)
        let readerBook = ReaderBook(
            id: book.id,
            title: book.title,
            author: book.author,
            fileURL: book.fileURL,
            addedAt: book.addedAt,
            lastReadAt: book.lastReadAt,
            progress: book.progress,
            coverData: nil,
            coverBg: nil,
            coverInk: nil
        )
        let chapter = makeChapter(paragraphTexts: ["New sample."])
        let resolver = DefaultNarrationProfileResolver()
        let failingRegistry = EngineRegistry(client: ReadAloudFailIfCalledHTTPClient(), apiKeyProvider: { _ in nil })
        let config = EngineConfig(id: .deepseek, model: "model", lastTestedOK: false, lastTestedAt: nil)

        let reused = await resolver.profile(
            book: readerBook,
            chapters: [chapter],
            currentChapter: chapter,
            provider: .doubao,
            forceRefresh: false,
            database: database,
            engineConfig: config,
            engineRegistry: failingRegistry
        )
        let refreshed = await resolver.profile(
            book: readerBook,
            chapters: [chapter],
            currentChapter: chapter,
            provider: .doubao,
            forceRefresh: true,
            database: database,
            engineConfig: config,
            engineRegistry: failingRegistry
        )

        XCTAssertEqual(reused, cached)
        XCTAssertEqual(refreshed, NarrationProfile.neutral(bookId: book.id, provider: .doubao, now: refreshed.createdAt))
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

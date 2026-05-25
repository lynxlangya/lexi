import Foundation
import XCTest
@testable import lexi

@MainActor
final class ReaderTranslationControllerTests: XCTestCase {
    func testStreamingChapterPersistsChunksAndMarksChapterCached() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["first", "second"])
        let client = ReaderMockEngineHTTPClient(streamResponses: [
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"first "}}]}"#,
                #"data: {"choices":[{"delta":{"content":"zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"second zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
        ])
        let controller = makeController(database: database, client: client)

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("chapter reaches cached state") {
            controller.chapterState(for: chapter.id) == .cached
        }

        let firstTranslation = try await database.cachedTranslation(
            paragraphId: chapter.paragraphs[0].id,
            engine: .deepseek,
            model: "deepseek-chat"
        )
        let secondTranslation = try await database.cachedTranslation(
            paragraphId: chapter.paragraphs[1].id,
            engine: .deepseek,
            model: "deepseek-chat"
        )

        XCTAssertEqual(firstTranslation, "first zh")
        XCTAssertEqual(secondTranslation, "second zh")
        XCTAssertEqual(client.requestCount, 2)
    }

    func testStreamingParagraphPersistsOnlyAfterStreamFinishes() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["streaming"])
        let client = ControlledReaderEngineHTTPClient()
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)
        await waitUntil("stream starts") {
            client.hasStream
        }

        client.yield(#"data: {"choices":[{"delta":{"content":"partial "}}]}"#)
        await waitUntil("partial text is visible in memory") {
            controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id) == .streaming("partial ")
        }

        let partialTranslation = try await database.cachedTranslation(
            paragraphId: chapter.paragraphs[0].id,
            engine: .deepseek,
            model: "deepseek-chat"
        )
        XCTAssertNil(partialTranslation)

        client.yield(#"data: {"choices":[{"delta":{"content":"done"}}]}"#)
        client.yield("data: [DONE]")
        client.finish()

        await waitUntilAsync("final translation is persisted") {
            let stored = try? await database.cachedTranslation(
                paragraphId: chapter.paragraphs[0].id,
                engine: .deepseek,
                model: "deepseek-chat"
            )
            return stored == "partial done"
        }
    }

    func testPartialStreamWithoutCompletionMarkerDoesNotPersistAsCached() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(
            database: database,
            paragraphTexts: ["Talking about AI can be confusing, in part because AI has meant many things."]
        )
        let client = ControlledReaderEngineHTTPClient()
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)
        await waitUntil("stream starts") {
            client.hasStream
        }

        client.yield(#"data: {"choices":[{"delta":{"content":"谈论人工智能可能会令人"}}]}"#)
        await waitUntil("partial text is visible but not cached") {
            controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id) == .streaming("谈论人工智能可能会令人")
        }
        client.finish()

        await waitUntil("partial stream is marked as error") {
            if case .error = controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id) {
                return true
            }
            return false
        }

        let stored = try await database.cachedTranslation(
            paragraphId: chapter.paragraphs[0].id,
            engine: .deepseek,
            model: "deepseek-chat"
        )
        XCTAssertNil(stored)
    }

    func testCachedChapterDoesNotCallEngine() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["cached"])
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .deepseek,
                model: "deepseek-chat",
                zh: "cached zh",
                createdAt: Date()
            )
        )
        let client = ReaderMockEngineHTTPClient()
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("cached chapter remains cached") {
            controller.chapterState(for: chapter.id) == .cached
        }
        XCTAssertEqual(client.requestCount, 0)
    }

    func testCachedParagraphFromDifferentEngineIsPreservedOnEngineSwitch() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["old engine"])
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .openai,
                model: "gpt-5.4-mini",
                zh: "old engine zh",
                createdAt: Date()
            )
        )
        let client = ReaderMockEngineHTTPClient()
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("chapter remains cached using previous engine translation") {
            controller.chapterState(for: chapter.id) == .cached
        }

        XCTAssertEqual(
            controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id),
            .cached("old engine zh")
        )
        XCTAssertEqual(client.requestCount, 0)
    }

    func testParagraphContextUsesBookChapterAndExactPreviousTranslation() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["cached", "missing"])
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .deepseek,
                model: "deepseek-chat",
                zh: "上一段当前引擎译文",
                createdAt: Date()
            )
        )
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .openai,
                model: "gpt-5.4-mini",
                zh: "上一段其他引擎译文",
                createdAt: Date()
            )
        )
        let client = ReaderMockEngineHTTPClient(streamResponses: [
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"missing zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
        ])
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0, bookTitle: "Test Book")

        await waitUntil("chapter reaches cached state") {
            controller.chapterState(for: chapter.id) == .cached
        }

        let request = try XCTUnwrap(client.requestsSnapshot.first)
        let payload = try decodedJSONObject(try XCTUnwrap(request.httpBody))
        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertTrue((messages[0]["content"] as? String)?.contains("Current work: \"Test Book\"") == true)
        XCTAssertTrue((messages[0]["content"] as? String)?.contains("Chapter: \"Chapter 1\"") == true)
        XCTAssertTrue((messages[1]["content"] as? String)?.contains("cached") == true)
        XCTAssertEqual(messages[2]["content"] as? String, "上一段当前引擎译文")
        XCTAssertTrue((messages[3]["content"] as? String)?.contains("missing") == true)
    }

    func testParagraphContextDoesNotUsePreviousFallbackFromDifferentEngine() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["fallback only", "missing"])
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .openai,
                model: "gpt-5.4-mini",
                zh: "上一段其他引擎译文",
                createdAt: Date()
            )
        )
        let client = ReaderMockEngineHTTPClient(streamResponses: [
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"missing zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
        ])
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0, bookTitle: "Test Book")

        await waitUntil("chapter reaches cached state") {
            controller.chapterState(for: chapter.id) == .cached
        }

        let request = try XCTUnwrap(client.requestsSnapshot.first)
        let payload = try decodedJSONObject(try XCTUnwrap(request.httpBody))
        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user"])
        XCTAssertFalse(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)?.contains("上一段其他引擎译文") == true)
    }

    func testParagraphFailureMapsToMissingParagraphIndex() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["cached", "fails", "blocked"])
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .deepseek,
                model: "deepseek-chat",
                zh: "cached zh",
                createdAt: Date()
            )
        )
        let client = ReaderMockEngineHTTPClient(streamResponses: [
            .success((readerSSEStream([]), readerResponse(status: 500))),
        ])
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("missing paragraphs reach error state") {
            if case .error = controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id),
               case .error = controller.paragraphState(for: chapter.paragraphs[2], in: chapter.id) {
                return true
            }
            return false
        }

        XCTAssertEqual(
            controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id),
            .cached("cached zh")
        )
        if case .error = controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected second paragraph to be marked as error")
        }
        if case .error = controller.paragraphState(for: chapter.paragraphs[2], in: chapter.id) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected third paragraph to be marked as error")
        }
        if case .error = controller.chapterState(for: chapter.id) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected chapter to stay in error state")
        }
    }

    func testEngineSetupFailureMarksMissingParagraphsAsError() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["first", "second"])
        let registry = EngineRegistry(client: ReaderMockEngineHTTPClient(), apiKeyProvider: { _ in nil })
        let controller = ChapterTranslationController(
            database: database,
            engineConfig: EngineConfig(id: .deepseek, model: "deepseek-chat", lastTestedOK: false, lastTestedAt: nil),
            registry: registry
        )
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("missing paragraphs reach error state") {
            if case .error = controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id),
               case .error = controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id) {
                return true
            }
            return false
        }

        if case .error = controller.chapterState(for: chapter.id) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected chapter to be marked as error")
        }
    }

    func testSwitchingChapterCancelsOldStreamBeforePersistingLateChunks() async throws {
        let database = try AppDatabase.makeTransient()
        let first = try await makeReaderChapter(
            database: database,
            bookId: "book-cancel",
            chapterIndex: 0,
            paragraphTexts: ["stale"]
        )
        let second = try await makeReaderChapter(
            database: database,
            bookId: "book-cancel",
            chapterIndex: 1,
            paragraphTexts: ["cached next"]
        )
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: second.paragraphs[0].id,
                engine: .deepseek,
                model: "deepseek-chat",
                zh: "cached next zh",
                createdAt: Date()
            )
        )
        let client = ControlledReaderEngineHTTPClient()
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [first, second])

        controller.selectChapter(first, chapters: [first, second], prefetchCount: 0)
        await waitUntil("first chapter starts streaming") {
            client.hasStream
        }

        controller.selectChapter(second, chapters: [first, second], prefetchCount: 0)
        await waitUntil("second chapter is cached") {
            controller.chapterState(for: second.id) == .cached
        }

        client.yield(#"data: {"choices":[{"delta":{"content":"late zh"}}]}"#)
        client.finish()
        await waitUntil("old stream observes cancellation") {
            client.didObserveCancellation
        }

        let staleTranslation = try await database.cachedTranslation(
            paragraphId: first.paragraphs[0].id,
            engine: .deepseek,
            model: "deepseek-chat"
        )
        XCTAssertNil(staleTranslation)
    }

    func testRetryParagraphRecoversFromErrorAndUpdatesChapterState() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["cached", "retry"])
        try await database.upsertTranslation(
            Translation(
                id: nil,
                paragraphId: chapter.paragraphs[0].id,
                engine: .deepseek,
                model: "deepseek-chat",
                zh: "cached zh",
                createdAt: Date()
            )
        )
        let client = ReaderMockEngineHTTPClient(streamResponses: [
            .success((readerSSEStream([]), readerResponse(status: 500))),
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"retry zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
        ])
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("chapter reaches error state") {
            if case .error = controller.chapterState(for: chapter.id) {
                return true
            }
            return false
        }

        controller.retryParagraph(chapter.paragraphs[1], in: chapter)

        await waitUntil("retry recovers chapter") {
            controller.chapterState(for: chapter.id) == .cached
        }

        XCTAssertEqual(
            controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id),
            .cached("retry zh")
        )
        let retryTranslation = try await database.cachedTranslation(
            paragraphId: chapter.paragraphs[1].id,
            engine: .deepseek,
            model: "deepseek-chat"
        )
        XCTAssertEqual(retryTranslation, "retry zh")
    }

    func testRetryDoesNotCancelOngoingChapterStream() async throws {
        let database = try AppDatabase.makeTransient()
        let chapter = try await makeReaderChapter(database: database, paragraphTexts: ["first", "retry", "still streaming"])
        let client = ReaderMockEngineHTTPClient(streamResponses: [
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"first zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
            .success((readerSSEStream([]), readerResponse(status: 500))),
            .success((readerSSEStream([
                #"data: {"choices":[{"delta":{"content":"retry zh"}}]}"#,
                "data: [DONE]",
            ]), readerResponse(status: 200))),
        ])
        let controller = makeController(database: database, client: client)
        await controller.prepare(chapters: [chapter])

        controller.selectChapter(chapter, chapters: [chapter], prefetchCount: 0)

        await waitUntil("paragraph failure closes remaining missing paragraphs") {
            if case .cached("first zh") = controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id),
               case .error = controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id),
               case .error = controller.paragraphState(for: chapter.paragraphs[2], in: chapter.id) {
                return true
            }
            return false
        }

        controller.retryParagraph(chapter.paragraphs[1], in: chapter)

        await waitUntil("retry updates only the requested paragraph") {
            if case .cached("retry zh") = controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id) {
                return true
            }
            return false
        }

        XCTAssertEqual(
            controller.paragraphState(for: chapter.paragraphs[0], in: chapter.id),
            .cached("first zh")
        )
        XCTAssertEqual(
            controller.paragraphState(for: chapter.paragraphs[1], in: chapter.id),
            .cached("retry zh")
        )
        if case .error = controller.paragraphState(for: chapter.paragraphs[2], in: chapter.id) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected non-retried paragraph to remain error")
        }
        if case .error = controller.chapterState(for: chapter.id) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected chapter to stay error while another paragraph is unresolved")
        }
    }

    private func makeController(database: AppDatabase, client: EngineHTTPClient) -> ChapterTranslationController {
        ChapterTranslationController(
            database: database,
            engineConfig: EngineConfig(id: .deepseek, model: "deepseek-chat", lastTestedOK: false, lastTestedAt: nil),
            registry: EngineRegistry(client: client, apiKeyProvider: { _ in "test-key" })
        )
    }

    private func makeReaderChapter(
        database: AppDatabase,
        bookId: String = "book",
        chapterIndex: Int = 0,
        paragraphTexts: [String]
    ) async throws -> ReaderChapter {
        if try await database.book(id: bookId) == nil {
            try await database.insertBook(
                Book(
                    id: bookId,
                    title: "Test Book",
                    author: "Test Author",
                    fileURL: URL(fileURLWithPath: "/tmp/test.epub"),
                    addedAt: Date(),
                    lastReadAt: nil,
                    progress: 0,
                    coverData: nil,
                    coverBg: nil,
                    coverInk: nil
                )
            )
        }

        let chapterId = try await database.insertChapter(
            Chapter(id: nil, bookId: bookId, idx: chapterIndex, n: "\(chapterIndex + 1)", title: "Chapter \(chapterIndex + 1)")
        )
        let paragraphs = try await paragraphTexts.asyncEnumeratedMap { index, text -> ReaderParagraph in
            let paragraphId = try await database.insertParagraph(
                Paragraph(id: nil, chapterId: chapterId, ord: index, en: text)
            )
            return ReaderParagraph(id: paragraphId, ord: index, en: text)
        }

        return ReaderChapter(
            id: chapterId,
            bookId: bookId,
            idx: chapterIndex,
            n: "\(chapterIndex + 1)",
            title: "Chapter \(chapterIndex + 1)",
            paragraphs: paragraphs
        )
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for \(description)")
    }

    private func waitUntilAsync(
        _ description: String,
        timeout: TimeInterval = 2,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for \(description)")
    }
}

private final class ReaderMockEngineHTTPClient: EngineHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var streamResponses: [Result<(AsyncThrowingStream<Data, Error>, HTTPURLResponse), Error>]
    private var requests: [URLRequest] = []

    init(streamResponses: [Result<(AsyncThrowingStream<Data, Error>, HTTPURLResponse), Error>] = []) {
        self.streamResponses = streamResponses
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    var requestsSnapshot: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw EngineError.invalidResponse
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        let response = streamResponses.isEmpty ? nil : streamResponses.removeFirst()
        lock.unlock()

        guard let response else {
            throw EngineError.invalidResponse
        }
        return try response.get()
    }
}

private final class ControlledReaderEngineHTTPClient: EngineHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var requests: [URLRequest] = []
    private var observedCancellation = false

    var hasStream: Bool {
        lock.lock()
        defer { lock.unlock() }
        return continuation != nil
    }

    var didObserveCancellation: Bool {
        lock.lock()
        defer { lock.unlock() }
        return observedCancellation
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw EngineError.invalidResponse
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        lock.unlock()

        let stream = AsyncThrowingStream<Data, Error> { continuation in
            self.lock.lock()
            self.continuation = continuation
            self.lock.unlock()
            continuation.onTermination = { termination in
                guard case .cancelled = termination else {
                    return
                }
                self.lock.lock()
                self.observedCancellation = true
                self.continuation = nil
                self.lock.unlock()
            }
        }
        return (stream, readerResponse(status: 200))
    }

    func yield(_ event: String) {
        lock.lock()
        let continuation = continuation
        lock.unlock()
        continuation?.yield(Data("\(event)\n\n".utf8))
    }

    func finish() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.finish()
    }
}

private func readerSSEStream(_ events: [String]) -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
        for event in events {
            continuation.yield(Data("\(event)\n\n".utf8))
        }
        continuation.finish()
    }
}

private func readerResponse(status: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://example.test")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
}

private func decodedJSONObject(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private extension Array {
    func asyncEnumeratedMap<T>(_ transform: (Int, Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        for (index, element) in enumerated() {
            values.append(try await transform(index, element))
        }
        return values
    }
}

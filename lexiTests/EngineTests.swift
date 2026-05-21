import Foundation
import XCTest
@testable import lexi

final class EngineTests: XCTestCase {
    func testOpenAIPingMapsAllStates() async throws {
        let okClient = MockEngineHTTPClient(dataResponses: [
            .success((Data(#"{"data":[{"id":"gpt-5.4-mini"}]}"#.utf8), response(status: 200))),
        ])
        let ok = try await OpenAIEngine(apiKey: "key", client: okClient).ping(model: "gpt-5.4-mini")
        XCTAssertEqual(ok, .ok)

        let unknownClient = MockEngineHTTPClient(dataResponses: [
            .success((Data(#"{"data":[{"id":"gpt-4o"}]}"#.utf8), response(status: 200))),
        ])
        let unknown = try await OpenAIEngine(apiKey: "key", client: unknownClient).ping(model: "gpt-5.4-mini")
        XCTAssertEqual(unknown, .keyOkModelUnknown)

        let failClient = MockEngineHTTPClient(dataResponses: [
            .success((Data(#"{"error":{"message":"invalid api key"}}"#.utf8), response(status: 401))),
        ])
        let fail = try await OpenAIEngine(apiKey: "key", client: failClient).ping(model: "gpt-5.4-mini")
        XCTAssertEqual(fail, .fail(reason: "invalid api key"))
    }

    func testOpenAIStreamProducesOrderedChunksWithParagraphIndexes() async throws {
        let client = MockEngineHTTPClient(streamResponses: [
            .success((sseStream([
                #"data: {"choices":[{"delta":{"content":"你好"}}]}"#,
                #"data: {"choices":[{"delta":{"content":"，世界"}}]}"#,
                "data: [DONE]",
            ]), response(status: 200))),
            .success((sseStream([
                #"data: {"choices":[{"delta":{"content":"第二段"}}]}"#,
                "data: [DONE]",
            ]), response(status: 200))),
        ])
        let engine = OpenAIEngine(apiKey: "key", client: client)

        let chunks = try await collect(engine.translate(
            [
                .paragraph(text: "hello world", context: ParagraphContext()),
                .paragraph(text: "second", context: ParagraphContext()),
            ],
            model: "gpt-5.4-mini"
        ))

        XCTAssertEqual(chunks, [
            TranslationChunk(index: 0, text: "你好"),
            TranslationChunk(index: 0, text: "，世界"),
            TranslationChunk(index: 1, text: "第二段"),
        ])
        XCTAssertEqual(client.requests.map { $0.url?.path }, ["/v1/chat/completions", "/v1/chat/completions"])
    }

    func testOpenAIParagraphContextAddsSystemMetadataAndPreviousTurns() async throws {
        let client = MockEngineHTTPClient(streamResponses: [
            .success((sseStream([
                #"data: {"choices":[{"delta":{"content":"当前译文"}}]}"#,
                "data: [DONE]",
            ]), response(status: 200))),
        ])
        let engine = OpenAIEngine(apiKey: "key", client: client)

        _ = try await collect(engine.translate(
            [
                .paragraph(
                    text: "Current paragraph.",
                    context: ParagraphContext(
                        bookTitle: "Co-Intelligence",
                        chapterTitle: "Chapter 2",
                        previousEN: "Previous English.",
                        previousZH: "上一段中文。"
                    )
                ),
            ],
            model: "gpt-5.4-mini"
        ))

        let body = try XCTUnwrap(client.requests.first?.httpBody)
        let payload = try decodedJSONObject(body)
        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])

        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user", "assistant", "user"])
        XCTAssertTrue((messages[0]["content"] as? String)?.contains("Current work: \"Co-Intelligence\"") == true)
        XCTAssertTrue((messages[0]["content"] as? String)?.contains("Chapter: \"Chapter 2\"") == true)
        XCTAssertTrue((messages[1]["content"] as? String)?.contains("Previous English.") == true)
        XCTAssertEqual(messages[2]["content"] as? String, "上一段中文。")
        XCTAssertTrue((messages[3]["content"] as? String)?.contains("Current paragraph.") == true)
    }

    func testAnthropicStreamProducesOrderedChunksWithParagraphIndexes() async throws {
        let client = MockEngineHTTPClient(streamResponses: [
            .success((sseStream([
                #"data: {"type":"content_block_delta","delta":{"text":"甲"}}"#,
                #"data: {"type":"content_block_delta","delta":{"text":"乙"}}"#,
            ]), response(status: 200))),
            .success((sseStream([
                #"data: {"type":"content_block_delta","delta":{"text":"丙"}}"#,
            ]), response(status: 200))),
        ])
        let engine = AnthropicEngine(apiKey: "key", client: client)

        let chunks = try await collect(engine.translate(
            [
                .paragraph(text: "a", context: ParagraphContext()),
                .paragraph(text: "b", context: ParagraphContext()),
            ],
            model: "claude-sonnet-4-6"
        ))

        XCTAssertEqual(chunks, [
            TranslationChunk(index: 0, text: "甲"),
            TranslationChunk(index: 0, text: "乙"),
            TranslationChunk(index: 1, text: "丙"),
        ])
        XCTAssertEqual(client.requests.map { $0.url?.path }, ["/v1/messages", "/v1/messages"])
    }

    func testAnthropicParagraphContextAddsSystemMetadataAndPreviousTurns() async throws {
        let client = MockEngineHTTPClient(streamResponses: [
            .success((sseStream([
                #"data: {"type":"content_block_delta","delta":{"text":"当前译文"}}"#,
            ]), response(status: 200))),
        ])
        let engine = AnthropicEngine(apiKey: "key", client: client)

        _ = try await collect(engine.translate(
            [
                .paragraph(
                    text: "Current paragraph.",
                    context: ParagraphContext(
                        bookTitle: "Co-Intelligence",
                        chapterTitle: "Chapter 2",
                        previousEN: "Previous English.",
                        previousZH: "上一段中文。"
                    )
                ),
            ],
            model: "claude-sonnet-4-6"
        ))

        let body = try XCTUnwrap(client.requests.first?.httpBody)
        let payload = try decodedJSONObject(body)
        let system = try XCTUnwrap(payload["system"] as? String)
        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])

        XCTAssertTrue(system.contains("Current work: \"Co-Intelligence\""))
        XCTAssertTrue(system.contains("Chapter: \"Chapter 2\""))
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["user", "assistant", "user"])
        XCTAssertTrue((messages[0]["content"] as? String)?.contains("Previous English.") == true)
        XCTAssertEqual(messages[1]["content"] as? String, "上一段中文。")
        XCTAssertTrue((messages[2]["content"] as? String)?.contains("Current paragraph.") == true)
    }

    func testParagraphPreviousSourceIsTruncatedFromEnd() {
        let previous = String(repeating: "a", count: 4_010) + "tail"
        let messages = Prompts.conversationMessages(
            for: .paragraph(
                text: "Current.",
                context: ParagraphContext(previousEN: previous, previousZH: "上一段。")
            )
        )

        XCTAssertEqual(messages.count, 3)
        XCTAssertFalse(messages[0].content.contains(String(repeating: "a", count: 4_010)))
        XCTAssertTrue(messages[0].content.contains(String(repeating: "a", count: 3_996) + "tail"))
    }

    func testFailedTaskMapsToTaskFailed() async throws {
        let client = MockEngineHTTPClient(streamResponses: [
            .success((sseStream([
                #"data: {"choices":[{"delta":{"content":"第一段"}}]}"#,
            ]), response(status: 200))),
            .success((sseStream([]), response(status: 500))),
        ])
        let engine = OpenAIEngine(apiKey: "key", client: client)

        do {
            _ = try await collect(engine.translate(
                [
                    .paragraph(text: "first", context: ParagraphContext()),
                    .paragraph(text: "second", context: ParagraphContext()),
                ],
                model: "gpt-5.4-mini"
            ))
            XCTFail("Expected paragraph failure")
        } catch let error as EngineError {
            guard case .taskFailed(let index, _) = error else {
                return XCTFail("Expected taskFailed, got \(error)")
            }
            XCTAssertEqual(index, 1)
        }
    }

    func testFailedSentenceTaskMapsToTaskFailed() async throws {
        let client = MockEngineHTTPClient(streamResponses: [
            .success((sseStream([]), response(status: 500))),
        ])
        let engine = OpenAIEngine(apiKey: "key", client: client)

        do {
            _ = try await collect(engine.translate(
                [
                    .sentence(text: "selected text", context: nil),
                ],
                model: "gpt-5.4-mini"
            ))
            XCTFail("Expected task failure")
        } catch let error as EngineError {
            guard case .taskFailed(let index, _) = error else {
                return XCTFail("Expected taskFailed, got \(error)")
            }
            XCTAssertEqual(index, 0)
        }
    }

    func testAnthropicPingMapsModelUnknown() async throws {
        let client = MockEngineHTTPClient(dataResponses: [
            .success((Data(#"{"error":{"message":"model not found"}}"#.utf8), response(status: 404))),
        ])
        let result = try await AnthropicEngine(apiKey: "key", client: client).ping(model: "bad-model")

        XCTAssertEqual(result, .keyOkModelUnknown)
    }

    func testDeepSeekUsesOpenAICompatibleEndpoint() async throws {
        let client = MockEngineHTTPClient(dataResponses: [
            .success((Data(#"{"data":[{"id":"deepseek-chat"}]}"#.utf8), response(status: 200))),
        ])
        let result = try await DeepSeekEngine(apiKey: "key", client: client).ping(model: "deepseek-chat")

        XCTAssertEqual(result, .ok)
        XCTAssertEqual(client.requests.first?.url?.host, "api.deepseek.com")
        XCTAssertEqual(client.requests.first?.url?.path, "/v1/models")
    }

    func testSSEParserPreservesUTF8SplitAcrossChunks() throws {
        var parser = SSEParser()
        let event = Data((#"data: {"choices":[{"delta":{"content":"你好"}}]}"# + "\n\n").utf8)
        let splitIndex = event.firstIndex(of: 0xE5)! + 1

        XCTAssertEqual(parser.feed(Data(event[..<splitIndex])), [])

        let payloads = parser.feed(Data(event[splitIndex...]))
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(try SSEParser.openAIText(from: payloads[0]), "你好")
    }

    func testEngineRegistryBuildsConfiguredEngineFromKeychainProvider() throws {
        let registry = EngineRegistry(
            client: MockEngineHTTPClient(),
            apiKeyProvider: { engine in
                engine == .deepseek ? "deepseek-key" : nil
            }
        )

        let engine = try registry.engine(
            for: EngineConfig(id: .deepseek, model: "deepseek-chat", lastTestedOK: false, lastTestedAt: nil)
        )

        XCTAssertEqual(engine.id, .deepseek)
    }

    func testEngineRegistryWithoutConfiguredKeyFails() throws {
        let registry = EngineRegistry(client: MockEngineHTTPClient(), apiKeyProvider: { _ in nil })

        XCTAssertThrowsError(
            try registry.engine(for: EngineConfig(id: .deepseek, model: "deepseek-chat", lastTestedOK: false, lastTestedAt: nil))
        ) { error in
            XCTAssertEqual(error as? EngineError, .missingAPIKey(.deepseek))
        }
    }
}

private final class MockEngineHTTPClient: EngineHTTPClient, @unchecked Sendable {
    private var dataResponses: [Result<(Data, HTTPURLResponse), Error>]
    private var streamResponses: [Result<(AsyncThrowingStream<Data, Error>, HTTPURLResponse), Error>]
    private(set) var requests: [URLRequest] = []

    init(
        dataResponses: [Result<(Data, HTTPURLResponse), Error>] = [],
        streamResponses: [Result<(AsyncThrowingStream<Data, Error>, HTTPURLResponse), Error>] = []
    ) {
        self.dataResponses = dataResponses
        self.streamResponses = streamResponses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !dataResponses.isEmpty else {
            throw EngineError.invalidResponse
        }
        return try dataResponses.removeFirst().get()
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        requests.append(request)
        guard !streamResponses.isEmpty else {
            throw EngineError.invalidResponse
        }
        return try streamResponses.removeFirst().get()
    }
}

private func sseStream(_ events: [String]) -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
        for event in events {
            continuation.yield(Data("\(event)\n\n".utf8))
        }
        continuation.finish()
    }
}

private func response(status: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://example.test")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
}

private func collect(_ stream: AsyncThrowingStream<TranslationChunk, Error>) async throws -> [TranslationChunk] {
    var chunks: [TranslationChunk] = []
    for try await chunk in stream {
        chunks.append(chunk)
    }
    return chunks
}

private func decodedJSONObject(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

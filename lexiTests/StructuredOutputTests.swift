import Foundation
import XCTest
@testable import lexi

final class StructuredOutputTests: XCTestCase {
    func testOpenAILookupRequestUsesStrictJSONSchemaResponseFormat() async throws {
        let client = MockLookupHTTPClient(dataResponses: [
            .success((Data(#"{"choices":[{"message":{"content":"{\"senses\":[{\"pos\":\"v\",\"zh\":\"观察\"}],\"contextualMeaning\":\"遵守\",\"synonyms\":[\"watch\"],\"example\":{\"en\":\"They observe the Sabbath.\",\"zh\":\"他们遵守安息日。\"}}"}}]}"#.utf8), lookupResponse(status: 200))),
        ])
        let engine = OpenAIEngine(apiKey: "key", client: client)

        let result = try await engine.lookup(TranslationTask.wordLookup(word: "observe", context: nil), model: "gpt-5.4-mini")

        XCTAssertEqual(result.senses, [LookupSense(pos: .v, zh: "观察")])
        let body = try XCTUnwrap(client.requests.first?.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let responseFormat = try XCTUnwrap(object["response_format"] as? [String: Any])
        XCTAssertEqual(responseFormat["type"] as? String, "json_schema")
        let jsonSchema = try XCTUnwrap(responseFormat["json_schema"] as? [String: Any])
        XCTAssertEqual(jsonSchema["name"] as? String, "lookup")
        XCTAssertEqual(jsonSchema["strict"] as? Bool, true)
    }

    func testAnthropicLookupRequestForcesToolUseAndDecodesToolInput() async throws {
        let client = MockLookupHTTPClient(dataResponses: [
            .success((Data(#"{"content":[{"type":"tool_use","name":"emit_lookup","input":{"senses":[{"pos":"phr","zh":"查找"}],"contextualMeaning":null,"synonyms":null,"example":null}}]}"#.utf8), lookupResponse(status: 200))),
        ])
        let engine = AnthropicEngine(apiKey: "key", client: client)

        let result = try await engine.lookup(TranslationTask.phraseLookup(phrase: "look up", context: nil), model: "claude-sonnet-4-6")

        XCTAssertEqual(result.senses, [LookupSense(pos: .phr, zh: "查找")])
        let body = try XCTUnwrap(client.requests.first?.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let toolChoice = try XCTUnwrap(object["tool_choice"] as? [String: Any])
        XCTAssertEqual(toolChoice["type"] as? String, "tool")
        XCTAssertEqual(toolChoice["name"] as? String, "emit_lookup")
        let tools = try XCTUnwrap(object["tools"] as? [[String: Any]])
        let firstTool = try XCTUnwrap(tools.first)
        XCTAssertEqual(firstTool["name"] as? String, "emit_lookup")
    }

    func testLookupDecoderExtractsJSONObjectWithBraceInsideString() throws {
        let result = try LookupSchema.decode(
            #"prefix {"senses":[{"pos":"v","zh":"好的}"}],"contextualMeaning":null,"synonyms":null,"example":null} suffix"#
        )

        XCTAssertEqual(result.senses, [LookupSense(pos: .v, zh: "好的}")])
    }

    func testLookupDecoderExtractsJSONObjectWithEscapedQuotesInsideString() throws {
        let result = try LookupSchema.decode(
            #"prefix {"senses":[{"pos":"v","zh":"\"观察\""}],"contextualMeaning":null,"synonyms":null,"example":null} suffix"#
        )

        XCTAssertEqual(result.senses, [LookupSense(pos: .v, zh: "\"观察\"")])
    }
}

private final class MockLookupHTTPClient: EngineHTTPClient, @unchecked Sendable {
    private var dataResponses: [Result<(Data, HTTPURLResponse), Error>]
    private(set) var requests: [URLRequest] = []

    init(dataResponses: [Result<(Data, HTTPURLResponse), Error>]) {
        self.dataResponses = dataResponses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try dataResponses.removeFirst().get()
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        throw EngineError.invalidResponse
    }
}

private func lookupResponse(status: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://example.test")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
}

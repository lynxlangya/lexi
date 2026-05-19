//
//  TranslationServiceCacheTests.swift
//  LexiTests
//
//  Created by Codex on 05/19/26.
//

import XCTest
@testable import Lexi

final class TranslationServiceCacheTests: XCTestCase {
    func test_cancelledStreamDoesNotWriteCache() async throws {
        let cache = MockTranslationCache()
        let key = TranslationCacheKey(
            text: "hello",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans",
            engineID: "gpt-4o",
            modelID: "gpt-4o",
            promptVersion: "word-or-phrase-v1"
        )
        let sourceStream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("partial")
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                continuation.yield(" rest")
                continuation.finish()
            }
        }
        let mappedStream = await TranslationService.shared.mapErrors(
            from: sourceStream,
            cache: cache,
            cacheKey: key
        )
        let receivedFirstToken = expectation(description: "received first token")

        let consumer = Task {
            for try await token in mappedStream {
                if token == "partial" {
                    receivedFirstToken.fulfill()
                }
            }
        }

        await fulfillment(of: [receivedFirstToken], timeout: 1)
        consumer.cancel()
        try await Task.sleep(nanoseconds: 500_000_000)

        let cached = await cache.cachedValue(for: key)
        let writeCount = await cache.writeCount()
        XCTAssertNil(cached)
        XCTAssertEqual(writeCount, 0)
    }
}

private actor MockTranslationCache: TranslationCache {
    private var values: [TranslationCacheKey: String] = [:]
    private var writes = 0

    func get(_ key: TranslationCacheKey) async -> String? {
        values[key]
    }

    func set(_ key: TranslationCacheKey, value: String) async {
        writes += 1
        values[key] = value
    }

    func cachedValue(for key: TranslationCacheKey) async -> String? {
        values[key]
    }

    func writeCount() async -> Int {
        writes
    }
}

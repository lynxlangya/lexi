//
//  TranslationCacheKeyTests.swift
//  LexiTests
//
//  Created by Codex on 05/19/26.
//

import XCTest
@testable import Lexi

final class TranslationCacheKeyTests: XCTestCase {
    func test_sameInputsHashEqual() {
        let first = TranslationCacheKey(
            text: "hello",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans",
            engineID: "gpt-4o",
            modelID: "gpt-4o",
            promptVersion: "word-or-phrase-v1"
        )
        let second = TranslationCacheKey(
            text: "hello",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans",
            engineID: "gpt-4o",
            modelID: "gpt-4o",
            promptVersion: "word-or-phrase-v1"
        )

        XCTAssertEqual(first.textHash, second.textHash)
        XCTAssertEqual(first, second)
    }
}

//
//  LanguageDetectorTests.swift
//  LexiTests
//
//  Created by Codex on 05/19/26.
//

import XCTest
@testable import Lexi

final class LanguageDetectorTests: XCTestCase {
    func test_chineseInput_returnsZhHans() {
        XCTAssertEqual(LanguageDetector.detectPrimaryLanguageCode(for: "你好，Lexi"), "zh-Hans")
    }

    func test_singleEnglishWord_returnsTrue() {
        XCTAssertTrue(LanguageDetector.isEnglishWordQuery("Hello"))
    }

    func test_chineseWord_returnsFalse() {
        XCTAssertFalse(LanguageDetector.isEnglishWordQuery("你好"))
    }
}

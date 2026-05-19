//
//  EngineStoreTests.swift
//  LexiTests
//
//  Created by Codex on 05/19/26.
//

import XCTest
@testable import Lexi

final class EngineStoreTests: XCTestCase {
    func test_microsoftIdMigratesToGoogle() {
        XCTAssertEqual(EngineStore.normalizedEngineId("microsoft"), "google")
    }
}

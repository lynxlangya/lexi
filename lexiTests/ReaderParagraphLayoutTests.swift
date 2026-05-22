import Foundation
import XCTest
@testable import lexi

final class ReaderParagraphLayoutTests: XCTestCase {
    func testDefaultValueIsDualColumn() {
        XCTAssertEqual(ReaderParagraphLayout.defaultValue, .dual)
    }

    func testStorageRoundTripUsesRawValue() {
        let suiteName = "lexi.ReaderParagraphLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(ReaderParagraphLayout.stacked.rawValue, forKey: LexiDefaultsKey.readerParagraphLayout)
        XCTAssertEqual(
            ReaderParagraphLayout(storageValue: defaults.string(forKey: LexiDefaultsKey.readerParagraphLayout) ?? ""),
            .stacked
        )

        defaults.set(ReaderParagraphLayout.dual.rawValue, forKey: LexiDefaultsKey.readerParagraphLayout)
        XCTAssertEqual(
            ReaderParagraphLayout(storageValue: defaults.string(forKey: LexiDefaultsKey.readerParagraphLayout) ?? ""),
            .dual
        )
    }

    func testInvalidStorageValueFallsBackToDefault() {
        XCTAssertEqual(ReaderParagraphLayout(storageValue: "side-by-side"), .dual)
    }
}

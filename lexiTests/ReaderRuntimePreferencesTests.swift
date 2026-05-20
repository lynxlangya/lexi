import XCTest
@testable import lexi

final class ReaderRuntimePreferencesTests: XCTestCase {
    func testReaderFontChoiceFallsBackToNewYorkForUnknownStorageValue() {
        XCTAssertEqual(ReaderFontChoice(storageValue: "unknown"), .newYork)
    }

    func testReaderLineHeightChoiceKeepsNormalSpacingAsCurrentDefault() {
        let lineHeight = ReaderLineHeightChoice(storageValue: "normal")

        XCTAssertEqual(lineHeight.englishSpacingRatio, 0.72, accuracy: 0.001)
        XCTAssertEqual(lineHeight.chineseSpacingRatio, 0.78, accuracy: 0.001)
    }

    func testReaderLineHeightChoiceFallsBackToNormalForUnknownStorageValue() {
        XCTAssertEqual(ReaderLineHeightChoice(storageValue: "unknown"), .normal)
    }
}

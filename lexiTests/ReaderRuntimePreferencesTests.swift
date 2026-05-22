import XCTest
import SwiftUI
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

    func testSystemColorSchemeResolverTreatsMissingGlobalStyleAsLight() {
        XCTAssertEqual(SystemColorSchemeResolver.colorScheme(appleInterfaceStyle: nil), .light)
    }

    func testSystemColorSchemeResolverMapsDarkGlobalStyleToDark() {
        XCTAssertEqual(SystemColorSchemeResolver.colorScheme(appleInterfaceStyle: "Dark"), .dark)
    }

    func testSystemThemeUsesResolvedSystemScheme() {
        XCTAssertFalse(ReaderThemeChoice(mode: .system, systemColorScheme: .light).isDark)
        XCTAssertTrue(ReaderThemeChoice(mode: .system, systemColorScheme: .dark).isDark)
    }

    func testExplicitThemeIgnoresResolvedSystemScheme() {
        XCTAssertFalse(ReaderThemeChoice(mode: .day, systemColorScheme: .dark).isDark)
        XCTAssertTrue(ReaderThemeChoice(mode: .night, systemColorScheme: .light).isDark)
    }
}

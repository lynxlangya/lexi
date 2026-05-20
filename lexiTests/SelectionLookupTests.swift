import XCTest
@testable import lexi

final class SelectionLookupTests: XCTestCase {
    func testClassifierTreatsSingleEnglishTokenAsWord() {
        XCTAssertTrue(SelectionLookupClassifier.isWord("language"))
        XCTAssertTrue(SelectionLookupClassifier.isWord("can't"))
        XCTAssertTrue(SelectionLookupClassifier.isWord("reader\u{2019}s"))
    }

    func testClassifierTreatsPhrasesSentencesAndChineseAsNonWord() {
        XCTAssertFalse(SelectionLookupClassifier.isWord("hello world"))
        XCTAssertFalse(SelectionLookupClassifier.isWord("hello."))
        XCTAssertFalse(SelectionLookupClassifier.isWord("你好"))
    }

    func testCanTranslateRejectsEmptyAndOneCharacterSelections() {
        XCTAssertFalse(SelectionLookupClassifier.canTranslate(""))
        XCTAssertFalse(SelectionLookupClassifier.canTranslate(" a "))
        XCTAssertTrue(SelectionLookupClassifier.canTranslate("AI"))
    }
}

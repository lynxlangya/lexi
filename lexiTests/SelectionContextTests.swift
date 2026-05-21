import XCTest
@testable import lexi

final class SelectionContextTests: XCTestCase {
    func testSentenceContainingSelectionExpandsToNearestSentenceBoundaries() {
        let source = "He waited. They observe the Sabbath in silence! Then they left."

        let sentence = SelectionMonitor.sentenceContainingSelection("observe", in: source)

        XCTAssertEqual(sentence, "They observe the Sabbath in silence!")
    }

    func testSentenceContainingSelectionReturnsNilWhenSelectionIsMissing() {
        let sentence = SelectionMonitor.sentenceContainingSelection("missing", in: "He waited.")

        XCTAssertNil(sentence)
    }
}

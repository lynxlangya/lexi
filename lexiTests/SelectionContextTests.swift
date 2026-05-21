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

    func testExpandedSelectionWindowSupportsSentenceFallbackAroundRange() throws {
        let prefix = String(repeating: "x", count: 260)
        let sentence = "They observe the Sabbath in silence."
        let suffix = String(repeating: "y", count: 260)
        let source = "\(prefix). \(sentence) \(suffix)"
        let nsRange = try XCTUnwrap(source.range(of: "observe").map { NSRange($0, in: source) })

        let window = try XCTUnwrap(SelectionMonitor.expandedSelectionWindow(in: source, selectedRange: nsRange))
        let extracted = SelectionMonitor.sentenceContainingSelection("observe", in: window)

        XCTAssertEqual(extracted, sentence)
        XCTAssertLessThan(window.count, source.count)
    }
}

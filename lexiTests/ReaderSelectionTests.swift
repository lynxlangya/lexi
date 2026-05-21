import AppKit
import XCTest
@testable import lexi

final class ReaderSelectionTests: XCTestCase {
    func testContextTextViewDoesNotOverrideAccessibilityValue() {
        let textView = ContextTextView(frame: .zero)
        textView.string = "中文译文"
        textView.selectionContext = {
            SentenceContext(fullSentence: "Original English paragraph.")
        }

        XCTAssertEqual(textView.accessibilityValue() as? String, "中文译文")
        XCTAssertEqual(textView.accessibilityHelp(), "Original English paragraph.")
    }
}

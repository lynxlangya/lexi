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

    func testContextTextViewReportsSelectionFromDelegateChanges() {
        let textView = ContextTextView(frame: .zero)
        textView.string = "Large Language Models help readers."
        var selected: SelectedTextContext?
        textView.onSelectionChange = { selected = $0 }

        textView.setSelectedRange(NSRange(location: 0, length: "Large Language Models".count))
        textView.textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification, object: textView))

        XCTAssertEqual(selected?.text, "Large Language Models")
    }

    func testContextTextViewCanSuppressProgrammaticSelectionNotifications() {
        let textView = ContextTextView(frame: .zero)
        textView.string = "Large Language Models help readers."
        var callCount = 0
        textView.onSelectionChange = { _ in callCount += 1 }

        textView.performWithoutSelectionNotification {
            textView.setSelectedRange(NSRange(location: 0, length: "Large Language Models".count))
            textView.textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification, object: textView))
        }

        XCTAssertEqual(callCount, 0)
    }
}

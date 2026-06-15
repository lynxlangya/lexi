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

    func testReaderTextSelectionCoordinatorMergesSelectionAcrossParagraphViews() {
        let coordinator = ReaderTextSelectionCoordinator()
        let first = ContextTextView(frame: .zero)
        first.string = "alpha beta"
        first.configureReaderSelectionAppearance(
            backgroundColor: NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.60, alpha: 0.28),
            foregroundColor: .black
        )
        first.configureSelectionCoordinator(coordinator, order: 0)
        first.selectionContext = {
            SentenceContext(fullSentence: "alpha beta")
        }

        let second = ContextTextView(frame: .zero)
        second.string = "gamma delta"
        second.configureReaderSelectionAppearance(
            backgroundColor: NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.60, alpha: 0.28),
            foregroundColor: .black
        )
        second.configureSelectionCoordinator(coordinator, order: 1)
        second.selectionContext = {
            SentenceContext(fullSentence: "gamma delta")
        }

        let context = coordinator.applySelection(
            from: ReaderTextSelectionEndpoint(textView: first, characterIndex: 6),
            to: ReaderTextSelectionEndpoint(textView: second, characterIndex: 5)
        )

        XCTAssertEqual(context?.text, "beta\n\ngamma")
        XCTAssertEqual(first.selectedRange(), NSRange(location: 6, length: 4))
        XCTAssertEqual(second.selectedRange(), NSRange(location: 0, length: 5))
        XCTAssertEqual(first.accessibilitySelectedText(), "beta\n\ngamma")
        XCTAssertTrue(first.isDrawingReaderSelectionHighlight)
        XCTAssertTrue(second.isDrawingReaderSelectionHighlight)
        XCTAssertEqual(first.readerSelectionHighlightColor, second.readerSelectionHighlightColor)
        XCTAssertEqual(
            first.selectedTextAttributes[.backgroundColor] as? NSColor,
            NSColor.clear
        )
        XCTAssertEqual(
            second.selectedTextAttributes[.backgroundColor] as? NSColor,
            NSColor.clear
        )
    }

    func testTextReplacementClearsCachedCrossParagraphSelection() {
        let coordinator = ReaderTextSelectionCoordinator()
        let first = ContextTextView(frame: .zero)
        first.string = "alpha beta"
        first.configureSelectionCoordinator(coordinator, order: 0)

        let second = ContextTextView(frame: .zero)
        second.string = "gamma delta"
        second.configureSelectionCoordinator(coordinator, order: 1)

        var reportedContext: SelectedTextContext? = SelectedTextContext(text: "stale", anchor: .zero)
        first.onSelectionChange = { reportedContext = $0 }

        coordinator.applySelection(
            from: ReaderTextSelectionEndpoint(textView: first, characterIndex: 6),
            to: ReaderTextSelectionEndpoint(textView: second, characterIndex: 5)
        )

        first.setReaderAttributedString(NSAttributedString(string: "alpha replaced"))

        XCTAssertNil(first.accessibilitySelectedText())
        XCTAssertEqual(first.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(second.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertNil(reportedContext)
        XCTAssertFalse(first.isDrawingReaderSelectionHighlight)
        XCTAssertFalse(second.isDrawingReaderSelectionHighlight)
        XCTAssertNotEqual(
            first.selectedTextAttributes[.backgroundColor] as? NSColor,
            NSColor.clear
        )
        XCTAssertNotEqual(
            second.selectedTextAttributes[.backgroundColor] as? NSColor,
            NSColor.clear
        )
    }

    func testNativeSelectionChangeClearsSiblingCrossParagraphHighlights() {
        let coordinator = ReaderTextSelectionCoordinator()
        let first = ContextTextView(frame: .zero)
        first.string = "alpha beta"
        first.configureSelectionCoordinator(coordinator, order: 0)

        let second = ContextTextView(frame: .zero)
        second.string = "gamma delta"
        second.configureSelectionCoordinator(coordinator, order: 1)

        coordinator.applySelection(
            from: ReaderTextSelectionEndpoint(textView: first, characterIndex: 6),
            to: ReaderTextSelectionEndpoint(textView: second, characterIndex: 5)
        )

        second.setSelectedRange(NSRange(location: 6, length: 5))
        second.handleNativeSelectionChange()

        XCTAssertFalse(first.isDrawingReaderSelectionHighlight)
        XCTAssertFalse(second.isDrawingReaderSelectionHighlight)
        XCTAssertEqual(first.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(second.selectedRange(), NSRange(location: 6, length: 5))
        XCTAssertNotEqual(
            second.selectedTextAttributes[.backgroundColor] as? NSColor,
            NSColor.clear
        )
        XCTAssertEqual(second.accessibilitySelectedText(), "delta")
    }
}

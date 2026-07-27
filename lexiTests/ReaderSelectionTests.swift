import AppKit
import XCTest
@testable import lexi

private final class ReaderSelectionTestWindow: NSWindow {
    override var isKeyWindow: Bool { true }
}

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
        let selectionBackgroundColor = NSColor(
            calibratedRed: 0.20,
            green: 0.40,
            blue: 0.60,
            alpha: 0.28
        )
        let first = ContextTextView(frame: .zero)
        first.string = "alpha beta"
        first.configureReaderSelectionAppearance(
            backgroundColor: selectionBackgroundColor,
            foregroundColor: .black
        )
        first.configureSelectionCoordinator(coordinator, order: 0)
        first.selectionContext = {
            SentenceContext(fullSentence: "alpha beta")
        }

        let second = ContextTextView(frame: .zero)
        second.string = "gamma delta"
        second.configureReaderSelectionAppearance(
            backgroundColor: selectionBackgroundColor,
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
        XCTAssertTrue(first.layoutManager is ReaderSelectionLayoutManager)
        XCTAssertTrue(second.layoutManager is ReaderSelectionLayoutManager)
        XCTAssertEqual(
            first.selectedTextAttributes[.backgroundColor] as? NSColor,
            selectionBackgroundColor
        )
        XCTAssertEqual(
            second.selectedTextAttributes[.backgroundColor] as? NSColor,
            selectionBackgroundColor
        )
    }

    func testCoordinatedSelectionRendersSameAccentAcrossTextViews() throws {
        let window = ReaderSelectionTestWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let contentView = NSView(frame: window.contentLayoutRect)
        window.contentView = contentView

        let selectionColor = NSColor(
            calibratedRed: 0.20,
            green: 0.55,
            blue: 0.30,
            alpha: 1
        )
        let coordinator = ReaderTextSelectionCoordinator()
        let first = makeTextView(
            frame: NSRect(x: 20, y: 78, width: 300, height: 34),
            order: 0,
            selectionColor: selectionColor,
            coordinator: coordinator
        )
        let second = makeTextView(
            frame: NSRect(x: 20, y: 28, width: 300, height: 34),
            order: 1,
            selectionColor: selectionColor,
            coordinator: coordinator
        )
        contentView.addSubview(first)
        contentView.addSubview(second)

        XCTAssertTrue(window.makeFirstResponder(first))
        coordinator.applySelection(
            from: ReaderTextSelectionEndpoint(textView: first, characterIndex: 0),
            to: ReaderTextSelectionEndpoint(textView: second, characterIndex: second.utf16Length)
        )

        let whitespaceRange = NSRange(location: 9, length: 1)
        let firstColor = try sampledColor(in: first, characterRange: whitespaceRange)
        let secondColor = try sampledColor(in: second, characterRange: whitespaceRange)
        XCTAssertLessThan(colorDistance(firstColor, secondColor), 0.03)
        XCTAssertGreaterThan(firstColor.greenComponent - firstColor.redComponent, 0.10)
        XCTAssertGreaterThan(secondColor.greenComponent - secondColor.redComponent, 0.10)
    }

    func testReaderSelectionDoesNotRecolorBackgroundOutsideSelectedRange() throws {
        let window = ReaderSelectionTestWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 130),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: window.contentLayoutRect)
        window.contentView = contentView

        let selectionColor = NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.30, alpha: 1)
        let backgroundColor = NSColor(calibratedRed: 0.90, green: 0.70, blue: 0.10, alpha: 1)
        let coordinator = ReaderTextSelectionCoordinator()
        let controlCoordinator = ReaderTextSelectionCoordinator()
        let textView = makeTextView(
            frame: NSRect(x: 20, y: 76, width: 300, height: 34),
            order: 0,
            selectionColor: selectionColor,
            coordinator: coordinator,
            backgroundColor: backgroundColor
        )
        let control = makeTextView(
            frame: NSRect(x: 20, y: 20, width: 300, height: 34),
            order: 0,
            selectionColor: selectionColor,
            coordinator: controlCoordinator,
            backgroundColor: backgroundColor
        )
        contentView.addSubview(textView)
        contentView.addSubview(control)
        XCTAssertTrue(window.makeFirstResponder(textView))

        let selectedRange = NSRange(location: 10, length: 6)
        textView.setReaderSelectionRange(selectedRange)

        let unselectedColor = try sampledColor(
            in: textView,
            characterRange: NSRange(location: 9, length: 1)
        )
        let selectedColor = try sampledColor(
            in: textView,
            characterRange: NSRange(location: 15, length: 1)
        )
        let controlColor = try sampledColor(
            in: control,
            characterRange: NSRange(location: 9, length: 1)
        )
        XCTAssertLessThan(colorDistance(unselectedColor, controlColor), 0.03)
        XCTAssertGreaterThan(colorDistance(selectedColor, controlColor), 0.15)
        XCTAssertGreaterThan(selectedColor.greenComponent - selectedColor.redComponent, 0.10)
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

    private func makeTextView(
        frame: NSRect,
        order: Int,
        selectionColor: NSColor,
        coordinator: ReaderTextSelectionCoordinator,
        backgroundColor: NSColor? = nil
    ) -> ContextTextView {
        let textView = ContextTextView(frame: frame)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.configureReaderSelectionAppearance(backgroundColor: selectionColor, foregroundColor: .black)
        textView.configureSelectionCoordinator(coordinator, order: order)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20),
            .foregroundColor: NSColor.black,
        ]
        if let backgroundColor {
            attributes[.backgroundColor] = backgroundColor
        }
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Selection probe text",
                attributes: attributes
            )
        )
        return textView
    }

    private func sampledColor(in textView: ContextTextView, characterRange: NSRange) throws -> NSColor {
        let textContainer = try XCTUnwrap(textView.textContainer)
        let layoutManager = try XCTUnwrap(textView.layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: characterRange,
            actualCharacterRange: nil
        )
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            .offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)

        let bitmap = try XCTUnwrap(textView.bitmapImageRepForCachingDisplay(in: textView.bounds))
        textView.cacheDisplay(in: textView.bounds, to: bitmap)
        let samplePoint = NSPoint(x: rect.midX, y: rect.midY)
        let xScale = CGFloat(bitmap.pixelsWide) / textView.bounds.width
        let yScale = CGFloat(bitmap.pixelsHigh) / textView.bounds.height
        let pixelX = Int((samplePoint.x - textView.bounds.minX) * xScale)
        let pixelY = Int((samplePoint.y - textView.bounds.minY) * yScale)
        let sampledColor = try XCTUnwrap(bitmap.colorAt(x: pixelX, y: pixelY))
        return try XCTUnwrap(sampledColor.usingColorSpace(.deviceRGB))
    }

    private func colorDistance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
        hypot(
            hypot(lhs.redComponent - rhs.redComponent, lhs.greenComponent - rhs.greenComponent),
            lhs.blueComponent - rhs.blueComponent
        )
    }
}

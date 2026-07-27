import AppKit
import SwiftUI

struct SelectableReaderText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let lineSpacing: CGFloat
    let foregroundColor: Color
    let selectionColor: Color
    var selectionCoordinator: ReaderTextSelectionCoordinator?
    var selectionOrder: Int = 0
    var selectionContext: (() -> SentenceContext?)?
    var onSelectionChange: ((SelectedTextContext?) -> Void)?

    func makeNSView(context: Context) -> NSTextView {
        let textView = ContextTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.selectionContext = selectionContext
        textView.onSelectionChange = onSelectionChange
        textView.configureSelectionCoordinator(selectionCoordinator, order: selectionOrder)
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        if let textView = textView as? ContextTextView {
            textView.selectionContext = selectionContext
            textView.onSelectionChange = onSelectionChange
            textView.configureSelectionCoordinator(selectionCoordinator, order: selectionOrder)
        }
        let attributed = attributedString()
        if let textView = textView as? ContextTextView {
            textView.setReaderAttributedString(attributed)
        } else if textView.attributedString() != attributed {
            textView.textStorage?.setAttributedString(attributed)
        }
        textView.typingAttributes = attributes()
        let selectionBackgroundColor = NSColor(selectionColor)
        if let textView = textView as? ContextTextView {
            textView.configureReaderSelectionAppearance(
                backgroundColor: selectionBackgroundColor,
                foregroundColor: NSColor(foregroundColor)
            )
        } else {
            textView.selectedTextAttributes = [
                .backgroundColor: selectionBackgroundColor,
                .foregroundColor: NSColor(foregroundColor)
            ]
        }
        textView.insertionPointColor = selectionBackgroundColor
    }

    static func dismantleNSView(_ textView: NSTextView, coordinator: ()) {
        (textView as? ContextTextView)?.configureSelectionCoordinator(nil, order: 0)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? nsView.bounds.width
        guard width.isFinite, width > 0 else {
            return nil
        }

        return CGSize(
            width: width,
            height: measuredHeight(for: width)
        )
    }

    private func attributedString() -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes())
    }

    private func attributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: font,
            .foregroundColor: NSColor(foregroundColor),
            .paragraphStyle: paragraphStyle
        ]
    }

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(attributedString: attributedString())
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        return ceil(layoutManager.usedRect(for: textContainer).height)
    }
}

struct ReaderTextSelectionEndpoint {
    let textView: ContextTextView
    let characterIndex: Int
}

final class ReaderTextSelectionCoordinator {
    private static weak var activeCoordinator: ReaderTextSelectionCoordinator?

    private let textViews = NSHashTable<ContextTextView>.weakObjects()
    private var currentSelectedText = ""

    func register(_ textView: ContextTextView) {
        textViews.add(textView)
    }

    func unregister(_ textView: ContextTextView) {
        textViews.remove(textView)
    }

    func clearSelection(notify: Bool = false) {
        for textView in orderedTextViews() {
            textView.clearReaderSelection()
        }
        currentSelectedText = ""
        if notify {
            orderedTextViews().first?.onSelectionChange?(nil)
        }
    }

    func clearCoordinatedSelection(preservingNativeSelectionIn preservedTextView: ContextTextView) {
        for textView in orderedTextViews() {
            if textView === preservedTextView {
                textView.clearReaderSelectionHighlight()
            } else {
                textView.clearReaderSelection()
            }
        }
        currentSelectedText = ""
    }

    func trackSelection(from origin: ContextTextView, mouseDown event: NSEvent) {
        guard let window = origin.window else {
            return
        }

        if Self.activeCoordinator !== self {
            Self.activeCoordinator?.clearSelection()
            Self.activeCoordinator = self
        }

        window.makeFirstResponder(origin)
        guard let anchor = endpoint(for: event, preferredView: origin) else {
            return
        }

        var latest = anchor
        var didDrag = false

        while let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            switch nextEvent.type {
            case .leftMouseDragged:
                didDrag = true
                origin.autoscroll(with: nextEvent)
                if let endpoint = endpoint(for: nextEvent, preferredView: origin) {
                    latest = endpoint
                    _ = applySelection(from: anchor, to: latest)
                }
            case .leftMouseUp:
                if didDrag {
                    let context = applySelection(from: anchor, to: latest)
                    origin.onSelectionChange?(context)
                } else {
                    clearSelection()
                    origin.setSelectedRange(NSRange(location: anchor.characterIndex, length: 0))
                    origin.onSelectionChange?(nil)
                }
                return
            default:
                continue
            }
        }
    }

    @discardableResult
    func applySelection(
        from anchor: ReaderTextSelectionEndpoint,
        to focus: ReaderTextSelectionEndpoint
    ) -> SelectedTextContext? {
        let ordered = orderedTextViews()
        guard let anchorPosition = position(of: anchor.textView, in: ordered),
              let focusPosition = position(of: focus.textView, in: ordered) else {
            clearSelection()
            return nil
        }

        let lower: ReaderTextSelectionEndpoint
        let upper: ReaderTextSelectionEndpoint
        if isBefore(anchor, at: anchorPosition, focus, at: focusPosition) {
            lower = anchor
            upper = focus
        } else {
            lower = focus
            upper = anchor
        }

        guard let lowerPosition = position(of: lower.textView, in: ordered),
              let upperPosition = position(of: upper.textView, in: ordered) else {
            clearSelection()
            return nil
        }

        var selectedSegments: [(textView: ContextTextView, range: NSRange)] = []
        for (index, textView) in ordered.enumerated() {
            let range = selectedRange(
                for: textView,
                at: index,
                lower: lower,
                lowerPosition: lowerPosition,
                upper: upper,
                upperPosition: upperPosition
            )
            textView.setReaderSelectionRange(range)
            if range.length > 0 {
                selectedSegments.append((textView, range))
            }
        }

        let selected = selectedText(from: selectedSegments)
        currentSelectedText = selected
        guard !selected.isEmpty else {
            return nil
        }

        return SelectedTextContext(
            text: selected,
            anchor: anchorRect(from: selectedSegments),
            source: .reader,
            sentenceContext: sentenceContext(for: selectedSegments, selectedText: selected)
        )
    }

    func selectedText(containing textView: ContextTextView) -> String? {
        guard textViews.contains(textView), !currentSelectedText.isEmpty else {
            return nil
        }
        return currentSelectedText
    }

    private func endpoint(for event: NSEvent, preferredView: ContextTextView) -> ReaderTextSelectionEndpoint? {
        guard let textView = textView(closestTo: event.locationInWindow, preferredView: preferredView) else {
            return nil
        }
        return ReaderTextSelectionEndpoint(
            textView: textView,
            characterIndex: characterIndex(for: event.locationInWindow, in: textView)
        )
    }

    private func textView(closestTo locationInWindow: NSPoint, preferredView: ContextTextView) -> ContextTextView? {
        let ordered = orderedTextViews()
        guard !ordered.isEmpty else {
            return nil
        }

        let frames = ordered.map { textView in
            (textView: textView, frame: textView.convert(textView.bounds, to: nil))
        }
        if let containing = frames
            .filter({ $0.frame.insetBy(dx: -24, dy: 0).contains(locationInWindow) })
            .min(by: { distance(from: locationInWindow, to: $0.frame) < distance(from: locationInWindow, to: $1.frame) }) {
            return containing.textView
        }

        return frames.min { lhs, rhs in
            let lhsDistance = distance(from: locationInWindow, to: lhs.frame)
            let rhsDistance = distance(from: locationInWindow, to: rhs.frame)
            if lhsDistance == rhsDistance {
                return lhs.textView === preferredView
            }
            return lhsDistance < rhsDistance
        }?.textView
    }

    private func characterIndex(for locationInWindow: NSPoint, in textView: ContextTextView) -> Int {
        let location = textView.convert(locationInWindow, from: nil)
        let index = textView.characterIndexForInsertion(at: location)
        return min(max(0, index), textView.utf16Length)
    }

    private func orderedTextViews() -> [ContextTextView] {
        textViews.allObjects.sorted {
            if $0.selectionOrder == $1.selectionOrder {
                return ObjectIdentifier($0) < ObjectIdentifier($1)
            }
            return $0.selectionOrder < $1.selectionOrder
        }
    }

    private func position(of textView: ContextTextView, in ordered: [ContextTextView]) -> Int? {
        ordered.firstIndex { $0 === textView }
    }

    private func isBefore(
        _ lhs: ReaderTextSelectionEndpoint,
        at lhsPosition: Int,
        _ rhs: ReaderTextSelectionEndpoint,
        at rhsPosition: Int
    ) -> Bool {
        if lhsPosition == rhsPosition {
            return lhs.characterIndex <= rhs.characterIndex
        }
        return lhsPosition < rhsPosition
    }

    private func selectedRange(
        for textView: ContextTextView,
        at position: Int,
        lower: ReaderTextSelectionEndpoint,
        lowerPosition: Int,
        upper: ReaderTextSelectionEndpoint,
        upperPosition: Int
    ) -> NSRange {
        let length = textView.utf16Length
        guard lowerPosition...upperPosition ~= position else {
            return NSRange(location: 0, length: 0)
        }

        if lowerPosition == upperPosition {
            let start = min(max(0, lower.characterIndex), length)
            let end = min(max(0, upper.characterIndex), length)
            return NSRange(location: start, length: max(0, end - start))
        }

        if position == lowerPosition {
            let start = min(max(0, lower.characterIndex), length)
            return NSRange(location: start, length: max(0, length - start))
        }

        if position == upperPosition {
            let end = min(max(0, upper.characterIndex), length)
            return NSRange(location: 0, length: end)
        }

        return NSRange(location: 0, length: length)
    }

    private func selectedText(from segments: [(textView: ContextTextView, range: NSRange)]) -> String {
        SelectionLookupClassifier.normalizedText(
            segments.compactMap { textView, range in
                guard range.length > 0,
                      let stringRange = Range(range, in: textView.string) else {
                    return nil
                }
                return String(textView.string[stringRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        )
    }

    private func anchorRect(from segments: [(textView: ContextTextView, range: NSRange)]) -> CGRect {
        let rect = segments.reduce(CGRect.null) { partial, segment in
            let next = segment.textView.firstRect(forCharacterRange: segment.range, actualRange: nil)
            guard !next.isNull, !next.isEmpty else {
                return partial
            }
            return partial.isNull ? next : partial.union(next)
        }
        return rect.isNull ? .zero : rect
    }

    private func sentenceContext(
        for segments: [(textView: ContextTextView, range: NSRange)],
        selectedText: String
    ) -> SentenceContext? {
        guard let first = segments.first?.textView else {
            return nil
        }
        if segments.count == 1 {
            return first.selectionContext?()
        }
        return SentenceContext(fullSentence: selectedText)
    }

    private func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        if rect.contains(point) {
            return 0
        }

        let dx: CGFloat
        if point.x < rect.minX {
            dx = rect.minX - point.x
        } else if point.x > rect.maxX {
            dx = point.x - rect.maxX
        } else {
            dx = 0
        }

        let dy: CGFloat
        if point.y < rect.minY {
            dy = rect.minY - point.y
        } else if point.y > rect.maxY {
            dy = point.y - rect.maxY
        } else {
            dy = 0
        }

        return hypot(dx, dy)
    }
}

final class ReaderSelectionLayoutManager: NSLayoutManager {
    var readerSelectionRange: NSRange?
    var readerSelectionBackgroundColor = NSColor.selectedTextBackgroundColor

    override func fillBackgroundRectArray(
        _ rectArray: UnsafePointer<NSRect>,
        count rectCount: Int,
        forCharacterRange charRange: NSRange,
        color: NSColor
    ) {
        guard let readerSelectionRange,
              readerSelectionRange.length > 0,
              NSEqualRanges(NSIntersectionRange(readerSelectionRange, charRange), charRange) else {
            super.fillBackgroundRectArray(
                rectArray,
                count: rectCount,
                forCharacterRange: charRange,
                color: color
            )
            return
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        readerSelectionBackgroundColor.setFill()
        super.fillBackgroundRectArray(
            rectArray,
            count: rectCount,
            forCharacterRange: charRange,
            color: readerSelectionBackgroundColor
        )
    }
}

final class ContextTextView: NSTextView {
    var selectionContext: (() -> SentenceContext?)?
    var onSelectionChange: ((SelectedTextContext?) -> Void)?
    private(set) var selectionOrder = 0
    private weak var selectionCoordinator: ReaderTextSelectionCoordinator?
    private var readerSelectionBackgroundColor = NSColor.selectedTextBackgroundColor
    private var readerSelectionForegroundColor = NSColor.textColor
    private var readerSelectionRange: NSRange?

    override init(frame frameRect: NSRect) {
        let textStorage = NSTextStorage()
        let layoutManager = ReaderSelectionLayoutManager()
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        super.init(frame: frameRect, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var utf16Length: Int {
        (string as NSString).length
    }

    var isDrawingReaderSelectionHighlight: Bool {
        guard let readerSelectionRange else {
            return false
        }
        return readerSelectionRange.length > 0
    }

    var readerSelectionHighlightColor: NSColor? {
        isDrawingReaderSelectionHighlight ? readerSelectionBackgroundColor : nil
    }

    func configureSelectionCoordinator(_ coordinator: ReaderTextSelectionCoordinator?, order: Int) {
        if selectionCoordinator !== coordinator {
            selectionCoordinator?.unregister(self)
            selectionCoordinator = coordinator
            coordinator?.register(self)
        }
        selectionOrder = order
    }

    func configureReaderSelectionAppearance(backgroundColor: NSColor, foregroundColor: NSColor) {
        readerSelectionBackgroundColor = backgroundColor
        readerSelectionForegroundColor = foregroundColor
        readerSelectionLayoutManager?.readerSelectionBackgroundColor = backgroundColor
        applyNativeSelectedTextAttributes()
        needsDisplay = true
    }

    func setReaderAttributedString(_ attributed: NSAttributedString) {
        guard attributedString() != attributed else {
            return
        }

        textStorage?.setAttributedString(attributed)
        selectionCoordinator?.clearSelection(notify: true)
    }

    func setReaderSelectionRange(_ range: NSRange) {
        let boundedRange = boundedReaderRange(range)
        readerSelectionRange = boundedRange.length > 0 ? boundedRange : nil
        readerSelectionLayoutManager?.readerSelectionRange = readerSelectionRange
        setSelectedRange(boundedRange)
        applyNativeSelectedTextAttributes()
        needsDisplay = true
    }

    func clearReaderSelection() {
        readerSelectionRange = nil
        readerSelectionLayoutManager?.readerSelectionRange = nil
        setSelectedRange(NSRange(location: 0, length: 0))
        applyNativeSelectedTextAttributes()
        needsDisplay = true
    }

    func clearReaderSelectionHighlight() {
        guard readerSelectionRange != nil else {
            return
        }

        readerSelectionRange = nil
        readerSelectionLayoutManager?.readerSelectionRange = nil
        applyNativeSelectedTextAttributes()
        needsDisplay = true
    }

    deinit {
        selectionCoordinator?.unregister(self)
    }

    override func accessibilityHelp() -> String? {
        selectionContext?()?.fullSentence ?? super.accessibilityHelp()
    }

    override func accessibilitySelectedText() -> String? {
        if let selectedText = selectionCoordinator?.selectedText(containing: self) {
            return selectedText
        }

        let range = selectedRange()
        guard range.location != NSNotFound, range.length > 0 else {
            return nil
        }
        return super.accessibilitySelectedText()
    }

    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 1,
              let selectionCoordinator else {
            selectionCoordinator?.clearSelection()
            super.mouseDown(with: event)
            handleNativeSelectionChange()
            return
        }

        selectionCoordinator.trackSelection(from: self, mouseDown: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        handleNativeSelectionChange()
    }

    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        handleNativeSelectionChange()
    }

    override func copy(_ sender: Any?) {
        if let selectedText = selectionCoordinator?.selectedText(containing: self), !selectedText.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(selectedText, forType: .string)
            return
        }

        super.copy(sender)
    }

    func handleNativeSelectionChange() {
        selectionCoordinator?.clearCoordinatedSelection(preservingNativeSelectionIn: self)
        let range = selectedRange()
        guard range.location != NSNotFound,
              range.length > 0,
              let stringRange = Range(range, in: string) else {
            onSelectionChange?(nil)
            return
        }

        let selected = SelectionLookupClassifier.normalizedText(String(string[stringRange]))
        guard !selected.isEmpty else {
            onSelectionChange?(nil)
            return
        }

        onSelectionChange?(
            SelectedTextContext(
                text: selected,
                anchor: firstRect(forCharacterRange: range, actualRange: nil),
                source: .reader,
                sentenceContext: selectionContext?()
            )
        )
    }

    private func applyNativeSelectedTextAttributes() {
        selectedTextAttributes = [
            .backgroundColor: readerSelectionBackgroundColor,
            .foregroundColor: readerSelectionForegroundColor
        ]
    }

    private var readerSelectionLayoutManager: ReaderSelectionLayoutManager? {
        layoutManager as? ReaderSelectionLayoutManager
    }

    private func boundedReaderRange(_ range: NSRange) -> NSRange {
        guard range.location != NSNotFound else {
            return NSRange(location: 0, length: 0)
        }

        let textRange = NSRange(location: 0, length: utf16Length)
        let bounded = NSIntersectionRange(range, textRange)
        if bounded.location == NSNotFound {
            return NSRange(location: 0, length: 0)
        }
        return bounded
    }
}

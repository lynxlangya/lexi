import AppKit
import ApplicationServices

struct SelectedTextContext: Equatable {
    var text: String
    var anchor: CGRect
    var source: SelectionSource = .global
    var sentenceContext: SentenceContext?
}

enum SelectionSource: Equatable {
    case global
    case reader
}

enum SelectionReadFailure: Error, Equatable {
    case accessibilityDenied
    case emptySelection
}

@MainActor
final class SelectionMonitor {
    private var mouseUpMonitor: Any?
    private var localMouseUpMonitor: Any?
    var onSelection: ((SelectedTextContext) -> Void)?

    func start() {
        if mouseUpMonitor == nil {
            mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
                Task { @MainActor in
                    guard let self,
                          case .success(let context) = Self.currentSelectionResult(promptForPermission: false),
                          !context.text.isEmpty else {
                        return
                    }
                    self.onSelection?(context)
                }
            }
        }

        if localMouseUpMonitor == nil {
            localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                Task { @MainActor in
                    guard let self,
                          case .success(let context) = Self.currentSelectionResult(promptForPermission: false),
                          context.source == .reader,
                          !context.text.isEmpty else {
                        return
                    }
                    self.onSelection?(context)
                }
                return event
            }
        }
    }

    func stop() {
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }
    }

    static func currentSelection(promptForPermission: Bool = true) -> SelectedTextContext? {
        try? currentSelectionResult(promptForPermission: promptForPermission).get()
    }

    static func currentSelectionResult(promptForPermission: Bool = true) -> Result<SelectedTextContext, SelectionReadFailure> {
        guard ensureAccessibilityPermission(prompt: promptForPermission) else {
            return .failure(.accessibilityDenied)
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        var focusedElement: CFTypeRef?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        let appElement: AXUIElement = if let focusedApp {
            focusedApp as! AXUIElement
        } else {
            systemWide
        }
        let source = selectionSource(from: focusedApp)
        AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard let focusedElement else {
            return fallbackSelectionContext(source: source, anchor: fallbackAnchor())
        }
        let element = focusedElement as! AXUIElement

        var selectedText: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        let anchor = selectionFrame(from: element)

        if let rawText = selectedText as? String,
           let context = context(
            rawText: rawText,
            anchor: anchor,
            source: source,
            sentenceContext: sentenceContext(from: element, selectedText: rawText)
           ) {
            return .success(context)
        }

        return fallbackSelectionContext(source: source, anchor: anchor)
    }

    private static func fallbackSelectionContext(source: SelectionSource, anchor: CGRect) -> Result<SelectedTextContext, SelectionReadFailure> {
        guard source != .reader,
              let copiedText = selectedTextFromCopyShortcut(),
              let context = context(
                rawText: copiedText,
                anchor: anchor,
                source: source,
                sentenceContext: SentenceContext(fullSentence: sentenceContainingSelection(copiedText, in: copiedText))
              ) else {
            return .failure(.emptySelection)
        }

        return .success(context)
    }

    static func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func context(
        rawText: String,
        anchor: CGRect,
        source: SelectionSource,
        sentenceContext: SentenceContext? = nil
    ) -> SelectedTextContext? {
        let text = SelectionLookupClassifier.normalizedText(rawText)
        guard SelectionLookupClassifier.canTranslate(text) else {
            return nil
        }

        return SelectedTextContext(text: text, anchor: anchor, source: source, sentenceContext: sentenceContext)
    }

    private static func sentenceContext(from element: AXUIElement, selectedText: String) -> SentenceContext? {
        let fullText = stringAttribute(element, attribute: kAXHelpAttribute)
            ?? stringAttribute(element, attribute: kAXValueAttribute)
            ?? stringAttribute(element, attribute: kAXDescriptionAttribute)
            ?? stringAttribute(element, attribute: kAXTitleAttribute)

        if let fullText,
           let sentence = sentenceContainingSelection(selectedText, in: fullText) {
            return SentenceContext(fullSentence: sentence)
        }

        return expandedSelectionContext(from: element, selectedText: selectedText)
    }

    private static func stringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    static func sentenceContainingSelection(_ selectedText: String, in sourceText: String) -> String? {
        let normalizedSelection = SelectionLookupClassifier.normalizedText(selectedText)
        let normalizedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSelection.isEmpty,
              !normalizedSource.isEmpty,
              let selectedRange = normalizedSource.range(of: normalizedSelection, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let sentenceStart = sentenceBoundaryBefore(selectedRange.lowerBound, in: normalizedSource)
        let sentenceEnd = sentenceBoundaryAfter(selectedRange.upperBound, in: normalizedSource)
        let sentence = String(normalizedSource[sentenceStart..<sentenceEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? nil : sentence
    }

    static func expandedSelectionWindow(in text: String, selectedRange: NSRange, radius: Int = 200) -> String? {
        guard selectedRange.location >= 0,
              selectedRange.length > 0,
              let range = Range(selectedRange, in: text) else {
            return nil
        }

        let startOffset = max(0, text.distance(from: text.startIndex, to: range.lowerBound) - radius)
        let endOffset = min(text.count, text.distance(from: text.startIndex, to: range.upperBound) + radius)
        let start = text.index(text.startIndex, offsetBy: startOffset)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        return String(text[start..<end])
    }

    private static func expandedSelectionContext(from element: AXUIElement, selectedText: String) -> SentenceContext? {
        guard let range = selectedTextRange(from: element),
              let expandedText = stringForExpandedRange(from: element, selectedRange: range),
              let sentence = sentenceContainingSelection(selectedText, in: expandedText) else {
            return nil
        }

        return SentenceContext(fullSentence: sentence)
    }

    private static func selectedTextRange(from element: AXUIElement) -> CFRange? {
        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard rangeResult == .success, let rangeValue else {
            return nil
        }

        let axRange = rangeValue as! AXValue
        var range = CFRange()
        return AXValueGetValue(axRange, .cfRange, &range) ? range : nil
    }

    private static func stringForExpandedRange(from element: AXUIElement, selectedRange: CFRange) -> String? {
        guard selectedRange.location >= 0, selectedRange.length > 0 else {
            return nil
        }

        let radius = 200
        let textLength = numberAttribute(element, attribute: kAXNumberOfCharactersAttribute)
        let start = max(0, selectedRange.location - radius)
        let uncappedEnd = selectedRange.location + selectedRange.length + radius
        let end = textLength.map { min($0, uncappedEnd) } ?? uncappedEnd
        var expandedRange = CFRange(location: start, length: end - start)
        guard let parameter = AXValueCreate(.cfRange, &expandedRange) else {
            return nil
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            parameter,
            &value
        )
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private static func numberAttribute(_ element: AXUIElement, attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? Int
    }

    private static func sentenceBoundaryBefore(_ index: String.Index, in text: String) -> String.Index {
        var cursor = index
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            if isSentenceTerminator(text[previous]) {
                return cursor
            }
            cursor = previous
        }
        return text.startIndex
    }

    private static func sentenceBoundaryAfter(_ index: String.Index, in text: String) -> String.Index {
        var cursor = index
        while cursor < text.endIndex {
            if isSentenceTerminator(text[cursor]) {
                return text.index(after: cursor)
            }
            cursor = text.index(after: cursor)
        }
        return text.endIndex
    }

    private static func isSentenceTerminator(_ character: Character) -> Bool {
        ".!?。！？".contains(character)
    }

    private static func selectedTextFromCopyShortcut() -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        let previousItems = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        sendCopyShortcut()
        let deadline = Date().addingTimeInterval(0.70)
        while pasteboard.changeCount == previousChangeCount, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        let didCopy = pasteboard.changeCount != previousChangeCount
        let copied = pasteboard.string(forType: .string)

        if let previousItems {
            pasteboard.clearContents()
            pasteboard.writeObjects(previousItems)
        } else if didCopy {
            pasteboard.clearContents()
        }

        guard didCopy,
              let copied,
              !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return copied
    }

    private static func sendCopyShortcut() {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.08))
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func selectionFrame(from element: AXUIElement) -> CGRect {
        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        if rangeResult == .success, let rangeValue {
            let axRange = rangeValue as! AXValue
            var range = CFRange()
            if AXValueGetValue(axRange, .cfRange, &range) {
                var boundsValue: CFTypeRef?
                let parameter = AXValueCreate(.cfRange, &range)
                let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                    element,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    parameter!,
                    &boundsValue
                )
                if boundsResult == .success, let boundsValue {
                    let axBounds = boundsValue as! AXValue
                    var rect = CGRect.zero
                    if AXValueGetValue(axBounds, .cgRect, &rect) {
                        return rect
                    }
                }
            }
        }

        return fallbackAnchor()
    }

    private static func fallbackAnchor() -> CGRect {
        if let mouse = NSEvent.mouseLocationOnMainScreen {
            return CGRect(x: mouse.x - 18, y: mouse.y - 12, width: 36, height: 24)
        }
        return CGRect(x: 400, y: 400, width: 36, height: 24)
    }

    private static func selectionSource(from focusedApp: CFTypeRef?) -> SelectionSource {
        guard let focusedApp else {
            return .global
        }

        let app = focusedApp as! AXUIElement
        var pid = pid_t()
        guard AXUIElementGetPid(app, &pid) == .success,
              pid == NSRunningApplication.current.processIdentifier else {
            return .global
        }

        return .reader
    }
}

private extension NSEvent {
    static var mouseLocationOnMainScreen: CGPoint? {
        guard let screen = NSScreen.main else {
            return nil
        }
        let location = NSEvent.mouseLocation
        return CGPoint(
            x: location.x.clamped(to: screen.visibleFrame.minX...screen.visibleFrame.maxX),
            y: location.y.clamped(to: screen.visibleFrame.minY...screen.visibleFrame.maxY)
        )
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

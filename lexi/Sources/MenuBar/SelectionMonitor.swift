import AppKit
import ApplicationServices

struct SelectedTextContext: Equatable {
    var text: String
    var anchor: CGRect
}

@MainActor
final class SelectionMonitor {
    private var mouseUpMonitor: Any?
    var onSelection: ((SelectedTextContext) -> Void)?

    func start() {
        guard mouseUpMonitor == nil else {
            return
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      let context = Self.currentSelection(promptForPermission: false),
                      !context.text.isEmpty else {
                    return
                }
                self.onSelection?(context)
            }
        }
    }

    func stop() {
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
    }

    static func currentSelection(promptForPermission: Bool = true) -> SelectedTextContext? {
        guard ensureAccessibilityPermission(prompt: promptForPermission) else {
            return nil
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
        AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard let focusedElement else {
            return nil
        }
        let element = focusedElement as! AXUIElement

        var selectedText: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        guard let rawText = selectedText as? String else {
            return nil
        }

        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        return SelectedTextContext(text: text, anchor: selectionFrame(from: element))
    }

    static func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

        if let mouse = NSEvent.mouseLocationOnMainScreen {
            return CGRect(x: mouse.x - 18, y: mouse.y - 12, width: 36, height: 24)
        }
        return CGRect(x: 400, y: 400, width: 36, height: 24)
    }
}

private extension NSEvent {
    static var mouseLocationOnMainScreen: CGPoint? {
        guard let screen = NSScreen.main else {
            return nil
        }
        let location = NSEvent.mouseLocation
        return CGPoint(x: location.x, y: location.y.clamped(to: screen.visibleFrame.minY...screen.visibleFrame.maxY))
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

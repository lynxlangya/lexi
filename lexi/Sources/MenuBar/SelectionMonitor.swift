import AppKit
import ApplicationServices

struct SelectedTextContext: Equatable {
    var text: String
    var anchor: CGRect
    var source: SelectionSource = .global
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
        AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard let focusedElement else {
            return .failure(.emptySelection)
        }
        let element = focusedElement as! AXUIElement

        var selectedText: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        guard let rawText = selectedText as? String else {
            return .failure(.emptySelection)
        }

        let text = SelectionLookupClassifier.normalizedText(rawText)
        guard SelectionLookupClassifier.canTranslate(text) else {
            return .failure(.emptySelection)
        }

        return .success(
            SelectedTextContext(
                text: text,
                anchor: selectionFrame(from: element),
                source: selectionSource(from: focusedApp)
            )
        )
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

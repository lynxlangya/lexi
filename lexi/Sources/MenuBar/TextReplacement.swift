import AppKit
import ApplicationServices

enum TextReplacement {
    @MainActor
    static func replaceSelection(with text: String) -> Bool {
        guard SelectionMonitor.ensureAccessibilityPermission(prompt: true),
              case .success(let context) = SelectionMonitor.currentSelectionResult(promptForPermission: false),
              context.source != .reader else {
            return false
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
            return false
        }
        let element = focusedElement as! AXUIElement

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if result == .success {
            return true
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return false
    }
}

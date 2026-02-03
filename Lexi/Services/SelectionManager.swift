//
//  SelectionManager.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum SelectionError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "需要辅助功能权限才能读取选中文本。"
        }
    }
}

final class SelectionManager {
    static let shared = SelectionManager()

    @discardableResult
    func requestAccessibilityIfNeeded(prompt: Bool = true) -> Bool {
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func getSelectedText() async throws -> String? {
        guard AXIsProcessTrusted() else {
            _ = requestAccessibilityIfNeeded(prompt: true)
            throw SelectionError.notAuthorized
        }

        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusedError = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        if focusedError == .success, let focusedElement {
            let element = focusedElement as! AXUIElement

            if let selected = try copyAttribute(element, kAXSelectedTextAttribute) as? String, !selected.isEmpty {
                return selected
            }

            if let rangeObject = try copyAttribute(element, kAXSelectedTextRangeAttribute),
               CFGetTypeID(rangeObject) == AXValueGetTypeID() {
                let rangeValue = unsafeBitCast(rangeObject, to: AXValue.self)
                if AXValueGetType(rangeValue) == .cfRange {
                    var cfRange = CFRange()
                    AXValueGetValue(rangeValue, .cfRange, &cfRange)
                    if let fullValue = try copyAttribute(element, kAXValueAttribute) as? String {
                        let nsRange = NSRange(location: cfRange.location, length: cfRange.length)
                        if let swiftRange = Range(nsRange, in: fullValue) {
                            let slice = fullValue[swiftRange]
                            if !slice.isEmpty {
                                return String(slice)
                            }
                        }
                    }
                }
            }
        }

        // Fallback: simulate Cmd+C then read pasteboard. Many apps don't expose AX selected text.
        return try await copySelectedTextFromPasteboard()
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) throws -> AnyObject? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if error == .success {
            return value
        }
        return nil
    }

    private func copySelectedTextFromPasteboard() async throws -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        let previousSnapshot = snapshotPasteboard(pasteboard)
        let previousString = pasteboard.string(forType: .string)

        await MainActor.run {
            sendCopyShortcut()
        }

        try await Task.sleep(nanoseconds: 180_000_000)

        let newString = pasteboard.string(forType: .string)
        let didChange = pasteboard.changeCount != previousChangeCount || newString != previousString

        if didChange {
            restorePasteboard(pasteboard, snapshot: previousSnapshot, fallbackString: previousString)
        }

        if didChange, let newString, !newString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return newString
        }

        return nil
    }

    private func sendCopyShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private typealias PasteboardSnapshot = [[NSPasteboard.PasteboardType: Data]]

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else {
            return []
        }

        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private func restorePasteboard(
        _ pasteboard: NSPasteboard,
        snapshot: PasteboardSnapshot,
        fallbackString: String?
    ) {
        guard !snapshot.isEmpty else {
            if let fallbackString {
                pasteboard.clearContents()
                pasteboard.setString(fallbackString, forType: .string)
            }
            return
        }

        let newItems: [NSPasteboardItem] = snapshot.compactMap { itemData in
            guard !itemData.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        guard !newItems.isEmpty else {
            if let fallbackString {
                pasteboard.clearContents()
                pasteboard.setString(fallbackString, forType: .string)
            }
            return
        }

        pasteboard.clearContents()
        _ = pasteboard.writeObjects(newItems)
    }
}
#endif

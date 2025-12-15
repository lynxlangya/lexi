//
//  StatusBarManager.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

#if os(macOS)
import AppKit

@MainActor
final class StatusBarManager {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Lexi")
        item.button?.imagePosition = .imageOnly

        menu.addItem(makeItem(title: "Show Popup", action: #selector(showPopup)))
        menu.addItem(makeItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Quit Lexi", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func showPopup() {
        NSApp.activate(ignoringOtherApps: true)
        WindowManager.shared.showPopupNearMouse()
    }

    @objc private func openSettings() {
        AppKitHelpers.openSettingsWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }
}
#endif


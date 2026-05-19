//
//  AppKitHelpers.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import AppKit
import Foundation

enum AppKitHelpers {
    static func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
#endif

//
//  AppKitHelpers.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import AppKit

enum AppKitHelpers {
    static func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
#endif

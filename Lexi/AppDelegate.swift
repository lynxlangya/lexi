//
//  AppDelegate.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let hotKey = loadHotKeyFromDefaults()
        HotKeyManager.shared.registerHotKey(hotKey) {
            NotificationCenter.default.post(name: .lexiHotKeyPressed, object: nil)
        }

        SelectionManager.shared.requestAccessibilityIfNeeded(prompt: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WindowManager.shared.hidePopup()
        }
    }

    private func loadHotKeyFromDefaults() -> HotKey {
        let defaults = UserDefaults.standard
        let storedCode = defaults.object(forKey: "hotKeyCode") as? Int
        let storedModifiers = defaults.object(forKey: "hotKeyModifiers") as? Int

        let keyCode = storedCode ?? Int(HotKey.default.keyCode)
        let modifiers = storedModifiers ?? Int(HotKey.default.modifiers)
        return HotKey(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }
}
#endif

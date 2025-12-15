//
//  AppDelegate.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let automaticTerminationReason = "Lexi keeps a global hotkey listener active."

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination(automaticTerminationReason)

        let hotKey = loadHotKeyFromDefaults()
        HotKeyManager.shared.registerHotKey(hotKey) {
            NotificationCenter.default.post(name: .lexiHotKeyPressed, object: nil)
        }

        SelectionManager.shared.requestAccessibilityIfNeeded(prompt: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WindowManager.shared.hidePopup()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        WindowManager.shared.prepareForTermination()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProcessInfo.processInfo.enableAutomaticTermination(automaticTerminationReason)
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

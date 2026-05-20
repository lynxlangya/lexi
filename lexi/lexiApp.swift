//
//  lexiApp.swift
//  lexi
//
//  Created by 琅邪 on 5/19/26.
//

import SwiftUI

@main
struct LexiApp: App {
    @NSApplicationDelegateAdaptor(LexiAppDelegate.self) private var appDelegate
    @StateObject private var menuBarCoordinator = LexiMenuBarCoordinator()

    var body: some Scene {
        ReaderWindow(coordinator: menuBarCoordinator)

        LexiMenuBarExtra(coordinator: menuBarCoordinator)
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("设置…") {
                        menuBarCoordinator.openSettings()
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                }
            }
    }
}

@MainActor
final class LexiAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if UserDefaults.standard.string(forKey: "general.onClose") == "quit" {
            return true
        }
        sender.setActivationPolicy(.accessory)
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}

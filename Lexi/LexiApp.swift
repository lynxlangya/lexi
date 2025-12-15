//
//  LexiApp.swift
//  Lexi
//
//  Created by 琅邪 on 12/11/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct LexiApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 180)

        #if os(macOS)
        MenuBarExtra("Lexi", systemImage: "sparkles") {
            Button {
                WindowManager.shared.showPopupNearMouse()
            } label: {
                Label("Show Popup", systemImage: "rectangle.on.rectangle")
            }

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Lexi", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        #endif

        Settings {
            SettingsView()
        }
    }
}

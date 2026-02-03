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
                Label("显示翻译", systemImage: "rectangle.on.rectangle")
            }

            SettingsLink {
                Label("设置…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出 Lexi", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        #endif

        Settings {
            SettingsView()
        }
    }
}

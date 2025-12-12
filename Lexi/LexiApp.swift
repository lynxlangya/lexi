//
//  LexiApp.swift
//  Lexi
//
//  Created by 琅邪 on 12/11/25.
//

import SwiftUI

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
        Settings {
            SettingsView()
        }
    }
}

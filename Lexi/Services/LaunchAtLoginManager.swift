//
//  LaunchAtLoginManager.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

#if os(macOS)
import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false

    private let service = SMAppService.mainApp
    private var didBecomeActiveObserver: Any?

    private init() {
        refresh()

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

    func refresh() {
        isEnabled = (service.status == .enabled)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("LaunchAtLogin error: \(error)")
        }
        refresh()
    }
}
#endif

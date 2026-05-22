import AppKit
import Combine
import SwiftUI

enum SystemColorSchemeResolver {
    nonisolated static func current(userDefaults: UserDefaults = .standard) -> ColorScheme {
        colorScheme(appleInterfaceStyle: userDefaults.string(forKey: "AppleInterfaceStyle"))
    }

    nonisolated static func colorScheme(appleInterfaceStyle: String?) -> ColorScheme {
        appleInterfaceStyle == "Dark" ? .dark : .light
    }
}

@MainActor
final class SystemColorSchemeObserver: ObservableObject {
    @Published private(set) var colorScheme: ColorScheme

    private let resolve: () -> ColorScheme
    private var observer: NSObjectProtocol?

    init(resolve: @escaping () -> ColorScheme = { SystemColorSchemeResolver.current() }) {
        self.resolve = resolve
        self.colorScheme = resolve()
        self.observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func refresh() {
        let next = resolve()
        if colorScheme != next {
            colorScheme = next
        }
    }
}

struct WindowAppearanceUpdater: NSViewRepresentable {
    let colorScheme: ColorScheme?

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            let appearance = nsAppearance
            if view.appearance?.name != appearance?.name {
                view.appearance = appearance
            }
            if view.window?.appearance?.name != appearance?.name {
                view.window?.appearance = appearance
            }
        }
    }

    private var nsAppearance: NSAppearance? {
        switch colorScheme {
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        case nil:
            return nil
        @unknown default:
            return nil
        }
    }
}

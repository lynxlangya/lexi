import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let translateSelection = Self("global.translateSelection", default: .init(.l, modifiers: [.command, .shift]))
    static let translateAndReplaceSelection = Self("global.translateAndReplaceSelection", default: .init(.t, modifiers: [.command, .shift]))
    static let toggleReaderWindow = Self("global.toggleReaderWindow", default: .init(.k, modifiers: [.command, .shift]))
}

@MainActor
final class GlobalShortcuts {
    private let translateSelection: () -> Void
    private let translateAndReplace: () -> Void
    private let toggleReader: () -> Void

    init(
        translateSelection: @escaping () -> Void,
        translateAndReplace: @escaping () -> Void,
        toggleReader: @escaping () -> Void
    ) {
        self.translateSelection = translateSelection
        self.translateAndReplace = translateAndReplace
        self.toggleReader = toggleReader
    }

    func register() {
        KeyboardShortcuts.removeAllHandlers()
        KeyboardShortcuts.onKeyUp(for: .translateSelection) { [weak self] in
            Task { @MainActor in self?.translateSelection() }
        }
        KeyboardShortcuts.onKeyUp(for: .translateAndReplaceSelection) { [weak self] in
            Task { @MainActor in self?.translateAndReplace() }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleReaderWindow) { [weak self] in
            Task { @MainActor in self?.toggleReader() }
        }
    }
}

import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let readerToggleTranslationMode = Self("reader.toggleTranslationMode", default: .init(.b, modifiers: [.command]))
    static let readerPreviousChapter = Self("reader.previousChapter", default: .init(.leftBracket, modifiers: [.command]))
    static let readerNextChapter = Self("reader.nextChapter", default: .init(.rightBracket, modifiers: [.command]))
    static let readerIncreaseFontSize = Self("reader.increaseFontSize", default: .init(.equal, modifiers: [.command, .shift]))
    static let readerDecreaseFontSize = Self("reader.decreaseFontSize", default: .init(.minus, modifiers: [.command]))
    static let readerToggleSidebar = Self("reader.toggleSidebar", default: .init(.zero, modifiers: [.command]))
}

struct ReaderShortcuts: ViewModifier {
    let toggleTranslationMode: () -> Void
    let previousChapter: () -> Void
    let nextChapter: () -> Void
    let increaseFontSize: () -> Void
    let decreaseFontSize: () -> Void
    let toggleSidebar: () -> Void
    let addWordToVocab: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyboardShortcut(.readerToggleTranslationMode, type: .keyUp, perform: toggleTranslationMode)
            .onKeyboardShortcut(.readerPreviousChapter, type: .keyUp, perform: previousChapter)
            .onKeyboardShortcut(.readerNextChapter, type: .keyUp, perform: nextChapter)
            .onKeyboardShortcut(.readerIncreaseFontSize, type: .keyUp, perform: increaseFontSize)
            .onKeyboardShortcut(.readerDecreaseFontSize, type: .keyUp, perform: decreaseFontSize)
            .onKeyboardShortcut(.readerToggleSidebar, type: .keyUp, perform: toggleSidebar)
            .background(ReaderAddWordShortcutBridge(perform: addWordToVocab))
    }
}

private struct ReaderAddWordShortcutBridge: NSViewRepresentable {
    let perform: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(perform: perform)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.installIfNeeded()
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.perform = perform
        context.coordinator.view = view
    }

    final class Coordinator {
        var perform: () -> Void
        weak var view: NSView?
        private var monitor: Any?

        init(perform: @escaping () -> Void) {
            self.perform = perform
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installIfNeeded() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                guard let self,
                      self.shouldHandle(event) else {
                    return event
                }

                self.perform()
                return nil
            }
        }

        private func shouldHandle(_ event: NSEvent) -> Bool {
            guard view?.window === NSApp.keyWindow else {
                return false
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers == .command else {
                return false
            }

            return event.charactersIgnoringModifiers?.lowercased() == "d"
        }
    }
}

extension View {
    func readerShortcuts(
        toggleTranslationMode: @escaping () -> Void,
        previousChapter: @escaping () -> Void,
        nextChapter: @escaping () -> Void,
        increaseFontSize: @escaping () -> Void,
        decreaseFontSize: @escaping () -> Void,
        toggleSidebar: @escaping () -> Void,
        addWordToVocab: @escaping () -> Void
    ) -> some View {
        modifier(
            ReaderShortcuts(
                toggleTranslationMode: toggleTranslationMode,
                previousChapter: previousChapter,
                nextChapter: nextChapter,
                increaseFontSize: increaseFontSize,
                decreaseFontSize: decreaseFontSize,
                toggleSidebar: toggleSidebar,
                addWordToVocab: addWordToVocab
            )
        )
    }
}

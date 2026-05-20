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

    func body(content: Content) -> some View {
        content
            .onKeyboardShortcut(.readerToggleTranslationMode, type: .keyUp, perform: toggleTranslationMode)
            .onKeyboardShortcut(.readerPreviousChapter, type: .keyUp, perform: previousChapter)
            .onKeyboardShortcut(.readerNextChapter, type: .keyUp, perform: nextChapter)
            .onKeyboardShortcut(.readerIncreaseFontSize, type: .keyUp, perform: increaseFontSize)
            .onKeyboardShortcut(.readerDecreaseFontSize, type: .keyUp, perform: decreaseFontSize)
            .onKeyboardShortcut(.readerToggleSidebar, type: .keyUp, perform: toggleSidebar)
    }
}

extension View {
    func readerShortcuts(
        toggleTranslationMode: @escaping () -> Void,
        previousChapter: @escaping () -> Void,
        nextChapter: @escaping () -> Void,
        increaseFontSize: @escaping () -> Void,
        decreaseFontSize: @escaping () -> Void,
        toggleSidebar: @escaping () -> Void
    ) -> some View {
        modifier(
            ReaderShortcuts(
                toggleTranslationMode: toggleTranslationMode,
                previousChapter: previousChapter,
                nextChapter: nextChapter,
                increaseFontSize: increaseFontSize,
                decreaseFontSize: decreaseFontSize,
                toggleSidebar: toggleSidebar
            )
        )
    }
}

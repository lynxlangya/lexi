import AppKit
import Combine
import SwiftUI

struct LexiMenuBarExtra: Scene {
    @ObservedObject var coordinator: LexiMenuBarCoordinator

    var body: some Scene {
        MenuBarExtra {
            LexiMenuPanel(
                vocabCount: coordinator.vocabCount,
                todayCount: coordinator.todayQueryCount,
                translateSelection: coordinator.translateCurrentSelection,
                translateAndReplace: coordinator.translateAndReplaceSelection,
                toggleReader: coordinator.toggleReaderWindow,
                openVocab: coordinator.openVocab,
                openSettings: coordinator.openSettings,
                quit: { NSApp.terminate(nil) }
            )
        } label: {
            LexiGlyph(
                color: coordinator.popupVisible ? .lexiAccent : .primary,
                size: 14
            )
            .padding(.horizontal, 4)
            .frame(height: 20)
            .background(coordinator.popupVisible ? Color.lexiAccentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .help("Lexi · ⌘⇧L")
        }
        .menuBarExtraStyle(.window)
    }
}

struct LexiMenuBarBootstrap: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var coordinator: LexiMenuBarCoordinator

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                coordinator.setOpenReaderAction {
                    openWindow(id: "reader")
                }
                coordinator.start()
            }
    }
}

@MainActor
final class LexiMenuBarCoordinator: ObservableObject {
    @Published var vocabCount = 0
    @Published var todayQueryCount = 0
    @Published var popupVisible = false

    private let panel = PopupPanel()
    private let selectionMonitor = SelectionMonitor()
    private let speech = Speech()
    private let toast = MenuBarToast()
    private var shortcuts: GlobalShortcuts?
    private var database: AppDatabase?
    private var pinned = false
    private var activeKind: PopupKind?
    private var activeAnchor = CGRect(x: 600, y: 480, width: 36, height: 24)
    private var currentEngine = ReaderFixtureStore.defaultConfig()
    private var recentWords: [String] = []
    private var openReaderAction: (() -> Void)?
    private var started = false

    init() {
        panel.onDismiss = { [weak self] in
            self?.popupVisible = false
        }
    }

    func start() {
        guard !started else {
            refreshVocabCount()
            return
        }
        started = true

        NSApp.setActivationPolicy(.regular)
        ensureDatabase()
        refreshVocabCount()
        Task {
            currentEngine = await EnginePreferences.popupConfig(database: database)
        }

        selectionMonitor.onSelection = { [weak self] context in
            self?.showChip(for: context)
        }
        selectionMonitor.start()

        let shortcuts = GlobalShortcuts(
            translateSelection: { [weak self] in self?.translateCurrentSelection() },
            translateAndReplace: { [weak self] in self?.translateAndReplaceSelection() },
            toggleReader: { [weak self] in self?.toggleReaderWindow() }
        )
        shortcuts.register()
        self.shortcuts = shortcuts
    }

    func setOpenReaderAction(_ action: @escaping () -> Void) {
        openReaderAction = action
    }

    func translateCurrentSelection() {
        guard let context = selectedTextContext(promptForPermission: true) else {
            showPermissionError()
            return
        }
        translate(context.text, anchor: context.anchor)
    }

    func translateAndReplaceSelection() {
        guard let context = selectedTextContext(promptForPermission: true) else {
            showPermissionError()
            return
        }

        let anchor = context.anchor
        show(kind: .loading(text: context.text, isWord: false, engine: currentEngine.id), near: anchor)
        Task {
            do {
                let translated = try await translateText(context.text)
                if TextReplacement.replaceSelection(with: translated) {
                    closePopup()
                } else {
                    show(kind: .sentence(SentenceLookup(text: context.text, zh: translated, engine: currentEngine.id)), near: anchor)
                    showToast("已复制译文")
                }
            } catch {
                show(kind: .error(text: context.text, reason: error.localizedDescription), near: anchor)
            }
        }
    }

    func toggleReaderWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "Lexi" || $0.title == "书架" || $0.title.contains(" · Chapter ") }) {
            if window.isVisible && window.isKeyWindow {
                window.orderOut(nil)
            } else {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
            }
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        openReaderAction?()
    }

    func openVocab() {
        toggleReaderWindow()
        NotificationCenter.default.post(name: .lexiOpenVocab, object: nil)
    }

    func openSettings() {
        toggleReaderWindow()
        NotificationCenter.default.post(name: .lexiOpenSettings, object: nil)
    }

    private func selectedTextContext(promptForPermission: Bool) -> SelectedTextContext? {
        SelectionMonitor.currentSelection(promptForPermission: promptForPermission)
    }

    private func showChip(for context: SelectedTextContext) {
        guard UserDefaults.standard.string(forKey: "menubar.triggerStyle") != "instant" else {
            translate(context.text, anchor: context.anchor)
            return
        }

        activeKind = .chip(text: context.text)
        activeAnchor = context.anchor
        show(kind: .chip(text: context.text), near: context.anchor)
    }

    private func translate(_ text: String, anchor: CGRect) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let word = isWord(trimmed)
        Task {
            do {
                currentEngine = await EnginePreferences.popupConfig(database: database)
                show(kind: .loading(text: trimmed, isWord: word, engine: currentEngine.id), near: anchor)
                let translated = try await translateText(trimmed)
                todayQueryCount += 1
                if word {
                    let lookup = WordLookup(
                        word: trimmed,
                        ukIPA: "/\(trimmed.lowercased())/",
                        usIPA: "/\(trimmed.lowercased())/",
                        senses: [
                            WordSense(partOfSpeech: "n.", en: trimmed, zh: translated)
                        ],
                        example: WordExample(en: trimmed, zh: translated),
                        related: relatedWords(for: trimmed),
                        engine: currentEngine.id,
                        history: recentWords
                    )
                    remember(word: trimmed)
                    show(kind: .word(lookup), near: anchor)
                } else {
                    show(kind: .sentence(SentenceLookup(text: trimmed, zh: translated, engine: currentEngine.id)), near: anchor)
                }
            } catch {
                show(kind: .error(text: trimmed, reason: error.localizedDescription), near: anchor)
            }
        }
    }

    private func translateText(_ text: String) async throws -> String {
        let engine = try EngineRegistry.shared.engine(for: currentEngine)
        var result = ""
        for try await chunk in engine.translate([text], model: currentEngine.model) {
            result += chunk.text
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func show(kind: PopupKind, near anchor: CGRect) {
        activeKind = kind
        activeAnchor = anchor
        panel.show(kind: kind, near: anchor, actions: popupActions, pinned: pinned)
        popupVisible = true
    }

    private var popupActions: PopupActions {
        PopupActions(
            close: { [weak self] in self?.closePopup() },
            togglePin: { [weak self] in self?.togglePin() },
            translateChip: { [weak self] in self?.translateChip() },
            retry: { [weak self] in self?.retryActive() },
            addVocab: { [weak self] in self?.addActiveWordToVocab() },
            speak: { [weak self] text in self?.speech.speak(text) },
            selectEngine: { [weak self] engine in self?.selectEngine(engine) }
        )
    }

    private func closePopup() {
        panel.close()
        popupVisible = false
    }

    private func togglePin() {
        pinned.toggle()
        panel.setPinned(pinned)
        if let activeKind {
            show(kind: activeKind, near: activeAnchor)
        }
    }

    private func translateChip() {
        guard case .chip(let text) = activeKind else {
            return
        }
        translate(text, anchor: activeAnchor)
    }

    private func retryActive() {
        switch activeKind {
        case .error(let text, _):
            translate(text, anchor: activeAnchor)
        case .sentence(let lookup):
            translate(lookup.text, anchor: activeAnchor)
        case .word(let lookup):
            translate(lookup.word, anchor: activeAnchor)
        default:
            break
        }
    }

    private func addActiveWordToVocab() {
        guard case .word(let lookup) = activeKind else {
            return
        }
        ensureDatabase()
        guard let database else {
            return
        }
        Task {
            _ = try? await database.insertVocabEntry(
                VocabEntry(id: nil, word: lookup.word, context: lookup.example?.en, bookId: nil, addedAt: Date())
            )
            refreshVocabCount()
            showToast("已加入生词本")
        }
    }

    private func selectEngine(_ engine: EngineID) {
        currentEngine = EngineConfig(id: engine, model: ReaderFixtureStore.defaultModel(for: engine), lastTestedOK: false, lastTestedAt: nil)
        retryActive()
    }

    private func ensureDatabase() {
        guard database == nil else {
            return
        }
        database = try? AppDatabase.makeShared()
    }

    private func refreshVocabCount() {
        ensureDatabase()
        guard let database else {
            return
        }
        Task {
            vocabCount = (try? await database.vocabCount()) ?? 0
        }
    }

    func refreshCounts() {
        refreshVocabCount()
    }

    private func showPermissionError() {
        let reason = "需要在系统设置 → 隐私与安全 → 辅助功能中允许 Lexi。"
        show(kind: .error(text: "", reason: reason), near: activeAnchor)
    }

    private func showToast(_ message: String) {
        toast.show(message)
        NotificationCenter.default.post(name: .lexiMenuBarToast, object: message)
    }

    private func isWord(_ text: String) -> Bool {
        text.range(of: #"^[a-zA-Z'\u{2019}-]+$"#, options: .regularExpression) != nil
    }

    private func relatedWords(for word: String) -> [String] {
        let lower = word.lowercased()
        return [lower + "s", lower + "ed", lower + "ing"].filter { $0 != lower }
    }

    private func remember(word: String) {
        recentWords.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
        recentWords.insert(word, at: 0)
        recentWords = Array(recentWords.prefix(5))
    }
}

extension Notification.Name {
    static let lexiOpenSettings = Notification.Name("lexi.openSettings")
    static let lexiOpenVocab = Notification.Name("lexi.openVocab")
    static let lexiMenuBarToast = Notification.Name("lexi.menuBarToast")
}

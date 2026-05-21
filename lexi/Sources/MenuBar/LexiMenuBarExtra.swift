import AppKit
import Combine
import SwiftUI

struct LexiMenuBarExtra: Scene {
    @ObservedObject var coordinator: LexiMenuBarCoordinator
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

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
                color: coordinator.popupVisible ? accentChoice.primary : .primary,
                size: 14
            )
            .padding(.horizontal, 4)
            .frame(height: 20)
            .background(coordinator.popupVisible ? accentChoice.soft : Color.clear)
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
    private let speech = Speech()
    private let toast = MenuBarToast()
    private var shortcuts: GlobalShortcuts?
    private var database: AppDatabase?
    private var pinned = false
    private var activeKind: PopupKind?
    private var activeAnchor = CGRect(x: 600, y: 480, width: 36, height: 24)
    private var currentEngine = EngineConfig(id: .deepseek, model: ReaderFixtureStore.defaultModel(for: .deepseek), lastTestedOK: false, lastTestedAt: nil)
    private var popupEngineOverride: EngineConfig?
    private var recentWords: [String] = []
    private var openReaderAction: (() -> Void)?
    private var popupEngineSettingsObserver: NSObjectProtocol?
    private var started = false

    init() {
        panel.onDismiss = { [weak self] in
            self?.popupVisible = false
        }
    }

    deinit {
        if let popupEngineSettingsObserver {
            NotificationCenter.default.removeObserver(popupEngineSettingsObserver)
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

        popupEngineSettingsObserver = NotificationCenter.default.addObserver(
            forName: .lexiPopupEngineSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.applyPopupEngineSettings()
            }
        }

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
        switch selectedTextContext(promptForPermission: true) {
        case .success(let context):
            popupEngineOverride = nil
            translate(context.text, anchor: context.anchor)
        case .failure(.accessibilityDenied):
            showPermissionError()
        case .failure(.emptySelection):
            showEmptySelection()
        }
    }

    func translateAndReplaceSelection() {
        switch selectedTextContext(promptForPermission: true) {
        case .success(let context):
            guard context.source != .reader else {
                popupEngineOverride = nil
                translate(context.text, anchor: context.anchor)
                showToast("阅读器正文不可替换，已改为划词翻译")
                return
            }

            let anchor = context.anchor
            popupEngineOverride = nil
            Task {
                do {
                    currentEngine = await popupEngineConfig()
                    show(kind: .loading(text: context.text, isWord: false, engine: currentEngine.id), near: anchor)
                    let translated = try await translateText(context.text)
                    if TextReplacement.replaceSelection(with: translated) {
                        closePopup()
                    } else {
                        show(
                            kind: .sentence(
                                SentenceLookup(text: context.text, zh: translated, engine: currentEngine.id, model: currentEngine.model)
                            ),
                            near: anchor
                        )
                        showToast("已复制译文")
                    }
                } catch {
                    show(kind: .error(text: context.text, reason: error.localizedDescription), near: anchor)
                }
            }
        case .failure(.accessibilityDenied):
            showPermissionError()
        case .failure(.emptySelection):
            showEmptySelection()
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

    private func selectedTextContext(promptForPermission: Bool) -> Result<SelectedTextContext, SelectionReadFailure> {
        SelectionMonitor.currentSelectionResult(promptForPermission: promptForPermission)
    }

    private func translate(_ text: String, anchor: CGRect) {
        let trimmed = SelectionLookupClassifier.normalizedText(text)
        guard SelectionLookupClassifier.canTranslate(trimmed) else {
            showEmptySelection()
            return
        }

        let word = SelectionLookupClassifier.isWord(trimmed)
        Task {
            do {
                currentEngine = await popupEngineConfig()
                show(kind: .loading(text: trimmed, isWord: word, engine: currentEngine.id), near: anchor)
                let requestText = word ? Prompts.wordLookupPayload(word: trimmed) : trimmed
                let translated = try await translateText(requestText)
                todayQueryCount += 1
                if word {
                    let lookup = makeWordLookup(word: trimmed, dictionaryText: translated)
                    remember(word: trimmed)
                    show(kind: .word(lookup), near: anchor)
                } else {
                    show(
                        kind: .sentence(SentenceLookup(text: trimmed, zh: translated, engine: currentEngine.id, model: currentEngine.model)),
                        near: anchor
                    )
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

    private func makeWordLookup(word: String, dictionaryText: String) -> WordLookup {
        let senses = parseWordSenses(from: dictionaryText, word: word)
        let primaryMeaning = senses.first?.zh ?? dictionaryText

        return WordLookup(
            word: word,
            ukIPA: "/\(word.lowercased())/",
            usIPA: "/\(word.lowercased())/",
            senses: senses,
            example: WordExample(en: word, zh: primaryMeaning),
            related: relatedWords(for: word),
            engine: currentEngine.id,
            model: currentEngine.model,
            history: recentWords
        )
    }

    private func parseWordSenses(from text: String, word: String) -> [WordSense] {
        let cleaned = text
            .replacingOccurrences(of: "：", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = cleaned
            .split(whereSeparator: \.isNewline)
            .map { stripListPrefix(String($0)) }
            .filter { !$0.isEmpty }

        let parsed = lines.compactMap { parseSenseLine($0, word: word) }
        if !parsed.isEmpty {
            return Array(parsed.prefix(4))
        }

        let pieces = splitMeanings(cleaned)
        if pieces.isEmpty {
            return [WordSense(partOfSpeech: "释.", en: word, zh: cleaned)]
        }

        let labels = ["释.", "近.", "义.", "web."]
        return Array(pieces.prefix(4).enumerated()).map { index, meaning in
            WordSense(partOfSpeech: labels[index], en: word, zh: meaning)
        }
    }

    private func parseSenseLine(_ line: String, word: String) -> WordSense? {
        let labels = ["v.", "n.", "adj.", "adv.", "prep.", "conj.", "pron.", "web.", "phr.", "释.", "近.", "义."]
        guard let label = labels.first(where: { line.lowercased().hasPrefix($0) }) else {
            return nil
        }

        let body = String(line.dropFirst(label.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: " :.-\t"))
        guard !body.isEmpty else {
            return nil
        }

        return WordSense(partOfSpeech: label, en: word, zh: body)
    }

    private func splitMeanings(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n;；、/，,")
        return text
            .components(separatedBy: separators)
            .map { stripListPrefix($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func stripListPrefix(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["-", "•", "*"]
        while let prefix = prefixes.first(where: { value.hasPrefix($0) }) {
            value = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dotIndex = value.firstIndex(of: "."),
           value[..<dotIndex].allSatisfy(\.isNumber),
           value.distance(from: value.startIndex, to: dotIndex) <= 2 {
            value = String(value[value.index(after: dotIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
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
            retry: { [weak self] in self?.retryActive() },
            addVocab: { [weak self] in self?.addActiveWordToVocab() },
            speak: { [weak self] text in self?.speech.speak(text) },
            selectEngine: { [weak self] engine in self?.selectEngine(engine) },
            openSettings: { [weak self] in self?.openSettings() },
            openAccessibilitySettings: { [weak self] in self?.openAccessibilitySettings() }
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
        Task {
            let config = await engineConfig(for: engine)
            currentEngine = config
            popupEngineOverride = config
            retryActive()
        }
    }

    private func popupEngineConfig() async -> EngineConfig {
        if let popupEngineOverride {
            return popupEngineOverride
        }
        return await EnginePreferences.popupConfig(database: database)
    }

    private func engineConfig(for engine: EngineID) async -> EngineConfig {
        ensureDatabase()
        if let stored = try? await database?.engineConfig(for: engine) {
            return stored
        }
        return EngineConfig(
            id: engine,
            model: ReaderFixtureStore.defaultModel(for: engine),
            lastTestedOK: false,
            lastTestedAt: nil
        )
    }

    private func applyPopupEngineSettings() async {
        popupEngineOverride = nil
        currentEngine = await EnginePreferences.popupConfig(database: database)
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
        show(kind: .permissionError(reason: reason), near: activeAnchor)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showEmptySelection() {
        showToast("请先选中要翻译的文字")
    }

    private func showToast(_ message: String) {
        toast.show(message)
        NotificationCenter.default.post(name: .lexiMenuBarToast, object: message)
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

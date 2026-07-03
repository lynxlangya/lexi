import AppKit
import Combine
import SwiftUI

struct LexiMenuBarExtra: Scene {
    @ObservedObject var coordinator: LexiMenuBarCoordinator
    @AppStorage(LexiDefaultsKey.readerAccent) private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some Scene {
        MenuBarExtra {
            LexiMenuPanel(
                vocabCount: coordinator.vocabCount,
                unmasteredCount: coordinator.unmasteredCount,
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
    @Published var unmasteredCount = 0
    @Published var todayQueryCount = 0
    @Published var popupVisible = false
    @Published private(set) var hasPendingVocabOpenRequest = false

    private let panel = PopupPanel()
    private let speech = Speech()
    private let toast = MenuBarToast()
    private var shortcuts: GlobalShortcuts?
    private var database: AppDatabase?
    private var pinned = false
    private var activeKind: PopupKind?
    private var activeAnchor = CGRect(x: 600, y: 480, width: 36, height: 24)
    private var activeSentenceContext: SentenceContext?
    private var activeSelectionSource = SelectionSource.global
    private var activeVocabBookId: String?
    private var activeReaderBookId: String?
    private var activeReaderBookTitle: String?
    private var currentEngine = EngineConfig(id: .deepseek, model: ReaderFixtureStore.defaultModel(for: .deepseek), lastTestedOK: false, lastTestedAt: nil)
    private var popupEngineOverride: EngineConfig?
    private var activeLookupTask: Task<Void, Never>?
    private var lookupGeneration: UInt64 = 0
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
        activeLookupTask?.cancel()
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

    func setActiveReaderBook(id: String, title: String) {
        activeReaderBookId = id
        activeReaderBookTitle = title
    }

    func clearActiveReaderBook() {
        activeReaderBookId = nil
        activeReaderBookTitle = nil
    }

    func translateCurrentSelection() {
        switch selectedTextContext(promptForPermission: true) {
        case .success(let context):
            popupEngineOverride = nil
            translate(
                context.text,
                anchor: context.anchor,
                sentenceContext: context.sentenceContext,
                source: context.source
            )
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
                translate(
                    context.text,
                    anchor: context.anchor,
                    sentenceContext: context.sentenceContext,
                    source: context.source
                )
                showToast("阅读器正文不可替换，已改为划词翻译")
                return
            }

            let anchor = context.anchor
            popupEngineOverride = nil
            let generation = beginLookupTask()
            activeLookupTask = Task {
                defer { clearLookupTask(generation) }
                do {
                    let engineConfig = await popupEngineConfig()
                    guard isCurrentLookup(generation) else { return }
                    currentEngine = engineConfig
                    show(kind: .loading(text: context.text, isWord: false, engine: currentEngine.id), near: anchor)
                    let translated = try await translateText(context.text, sentenceContext: context.sentenceContext)
                    guard isCurrentLookup(generation) else { return }
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
                } catch is CancellationError {
                    return
                } catch {
                    guard isCurrentLookup(generation) else { return }
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
        if let window = readerWindow {
            if window.isVisible && window.isKeyWindow {
                window.orderOut(nil)
            } else {
                show(window)
            }
            return
        }

        openReaderWindow()
    }

    func openVocab() {
        hasPendingVocabOpenRequest = true
        if let window = readerWindow {
            show(window)
        } else {
            openReaderWindow()
        }
    }

    func consumePendingVocabOpenRequest() -> Bool {
        guard hasPendingVocabOpenRequest else {
            return false
        }

        hasPendingVocabOpenRequest = false
        return true
    }

    private var readerWindow: NSWindow? {
        NSApp.windows.first(where: { $0.title == "Lexi" || $0.title == "书架" || $0.title.contains(" · Chapter ") })
    }

    private func openReaderWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        openReaderAction?()
    }

    private func show(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func openSettings() {
        if let window = readerWindow {
            show(window)
        } else {
            openReaderWindow()
        }
        NotificationCenter.default.post(name: .lexiOpenSettings, object: nil)
    }

    private func selectedTextContext(promptForPermission: Bool) -> Result<SelectedTextContext, SelectionReadFailure> {
        SelectionMonitor.currentSelectionResult(promptForPermission: promptForPermission)
    }

    private func translate(
        _ text: String,
        anchor: CGRect,
        sentenceContext: SentenceContext? = nil,
        source: SelectionSource = .global
    ) {
        let trimmed = SelectionLookupClassifier.normalizedText(text)
        guard SelectionLookupClassifier.canTranslate(trimmed) else {
            showEmptySelection()
            return
        }

        activeSelectionSource = source
        activeVocabBookId = source == .reader ? activeReaderBookId : nil
        let word = SelectionLookupClassifier.isWord(trimmed)
        let generation = beginLookupTask()
        activeLookupTask = Task {
            defer { clearLookupTask(generation) }
            do {
                let engineConfig = await popupEngineConfig()
                guard isCurrentLookup(generation) else { return }
                currentEngine = engineConfig
                show(kind: .loading(text: trimmed, isWord: word, engine: currentEngine.id), near: anchor)
                let localEntry = word ? LocalDictionary.lookup(trimmed) : nil
                let enrichedContext = SentenceContext(
                    fullSentence: sentenceContext?.fullSentence,
                    bookTitle: sentenceContext?.bookTitle ?? (source == .reader ? activeReaderBookTitle : nil),
                    localDictionary: localEntry
                )
                guard isCurrentLookup(generation) else { return }
                activeSentenceContext = enrichedContext
                todayQueryCount += 1
                if word {
                    let result = try await lookupTask(.wordLookup(word: trimmed, context: enrichedContext))
                    guard isCurrentLookup(generation) else { return }
                    let masteredStatus = await vocabStatus(for: trimmed)
                    guard isCurrentLookup(generation) else { return }
                    let lookup = makeWordLookup(
                        word: trimmed,
                        result: result,
                        localEntry: localEntry,
                        masteredStatus: masteredStatus
                    )
                    remember(word: trimmed)
                    show(kind: .word(lookup), near: anchor)
                } else {
                    let translated = try await translateTask(.sentence(text: trimmed, context: enrichedContext))
                    guard isCurrentLookup(generation) else { return }
                    show(
                        kind: .sentence(SentenceLookup(text: trimmed, zh: translated, engine: currentEngine.id, model: currentEngine.model)),
                        near: anchor
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentLookup(generation) else { return }
                show(kind: .error(text: trimmed, reason: error.localizedDescription), near: anchor)
            }
        }
    }

    private func translateText(_ text: String, sentenceContext: SentenceContext? = nil) async throws -> String {
        try await translateTask(.sentence(text: text, context: sentenceContext))
    }

    private func translateTask(_ task: TranslationTask) async throws -> String {
        let engine = try EngineRegistry.shared.engine(for: currentEngine)
        var result = ""
        for try await chunk in engine.translate([task], model: currentEngine.model) {
            result += chunk.text
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func lookupTask(_ task: TranslationTask) async throws -> LookupResult {
        let engine = try EngineRegistry.shared.engine(for: currentEngine)
        return try await engine.lookup(task, model: currentEngine.model)
    }

    private func makeWordLookup(
        word: String,
        result: LookupResult,
        localEntry: LocalDictionaryEntry?,
        masteredStatus: MasteredStatus
    ) -> WordLookup {
        let senses = result.senses.map { sense in
            WordSense(partOfSpeech: sense.pos.displayLabel, en: word, zh: sense.zh)
        }
        let primaryMeaning = result.contextualMeaning ?? senses.first?.zh ?? word

        return WordLookup(
            word: word,
            primaryZh: primaryMeaning,
            ukIPA: localEntry?.ukIPA ?? "—",
            usIPA: localEntry?.usIPA ?? "—",
            senses: senses,
            lookupSenses: result.senses,
            example: WordExample(en: result.example?.en ?? word, zh: result.example?.zh ?? primaryMeaning),
            localDictionary: localEntry,
            related: relatedWords(for: word),
            engine: currentEngine.id,
            model: currentEngine.model,
            history: recentWords,
            masteredStatus: masteredStatus
        )
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
        cancelActiveLookup()
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
            translate(text, anchor: activeAnchor, sentenceContext: activeSentenceContext, source: activeSelectionSource)
        case .sentence(let lookup):
            translate(lookup.text, anchor: activeAnchor, sentenceContext: activeSentenceContext, source: activeSelectionSource)
        case .word(let lookup):
            translate(lookup.word, anchor: activeAnchor, sentenceContext: activeSentenceContext, source: activeSelectionSource)
        default:
            break
        }
    }

    private func beginLookupTask() -> UInt64 {
        activeLookupTask?.cancel()
        lookupGeneration &+= 1
        return lookupGeneration
    }

    private func cancelActiveLookup() {
        activeLookupTask?.cancel()
        activeLookupTask = nil
        lookupGeneration &+= 1
    }

    private func isCurrentLookup(_ generation: UInt64) -> Bool {
        generation == lookupGeneration && !Task.isCancelled
    }

    private func clearLookupTask(_ generation: UInt64) {
        if generation == lookupGeneration {
            activeLookupTask = nil
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
            let lookupResult = LookupResult(
                senses: lookup.lookupSenses,
                contextualMeaning: lookup.primaryZh,
                synonyms: nil,
                example: LookupExample(en: lookup.example?.en, zh: lookup.example?.zh)
            )
            let snapshot = VocabSnapshot.make(
                word: lookup.word,
                lookup: lookupResult,
                localEntry: lookup.localDictionary
            )
            let result = try? await database.upsertVocabEntry(
                word: lookup.word,
                context: activeSentenceContext?.fullSentence,
                primaryZh: snapshot.primaryZh,
                sensesJSON: snapshot.sensesJSON,
                ukIPA: snapshot.ukIPA,
                usIPA: snapshot.usIPA,
                exampleEN: snapshot.exampleEN,
                exampleZH: snapshot.exampleZH,
                bookId: activeVocabBookId
            )
            refreshVocabCount()
            switch result {
            case .inserted:
                updateActiveWordMasteredStatus(.inVocabUnmastered)
                showToast("已加入生词本")
            case .updated:
                let status = (try? await database.vocabEntry(normalizedWord: lookup.word))?.mastered == true
                    ? MasteredStatus.mastered
                    : .inVocabUnmastered
                updateActiveWordMasteredStatus(status)
                showToast("已在生词本，更新来源")
            case nil:
                showToast("加入生词本失败")
            }
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
        database = try? AppDatabase.sharedInstance()
    }

    private func refreshVocabCount() {
        ensureDatabase()
        guard let database else {
            return
        }
        Task {
            vocabCount = (try? await database.vocabCount()) ?? 0
            unmasteredCount = (try? await database.unmasteredVocabCount()) ?? 0
        }
    }

    func refreshCounts() {
        refreshVocabCount()
    }

    private func showPermissionError() {
        cancelActiveLookup()
        let reason = "需要在系统设置 → 隐私与安全 → 辅助功能中允许 Lexi。"
        show(kind: .permissionError(reason: reason), near: activeAnchor)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showEmptySelection() {
        cancelActiveLookup()
        showToast("请先选中要翻译的文字")
    }

    private func showToast(_ message: String) {
        toast.show(message)
        NotificationCenter.default.post(name: .lexiMenuBarToast, object: message)
    }

    private func vocabStatus(for word: String) async -> MasteredStatus {
        ensureDatabase()
        guard let database,
              let entry = try? await database.vocabEntry(normalizedWord: word) else {
            return .notInVocab
        }
        return entry.mastered ? .mastered : .inVocabUnmastered
    }

    private func updateActiveWordMasteredStatus(_ status: MasteredStatus) {
        guard case .word(var lookup) = activeKind else {
            return
        }
        lookup.masteredStatus = status
        show(kind: .word(lookup), near: activeAnchor)
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

private extension LookupPartOfSpeech {
    var displayLabel: String {
        switch self {
        case .v: "v."
        case .n: "n."
        case .adj: "adj."
        case .adv: "adv."
        case .prep: "prep."
        case .conj: "conj."
        case .phr: "phr."
        case .idiom: "idiom."
        }
    }
}

import AppKit
import SwiftUI

struct ReaderWindow: Scene {
    @ObservedObject var coordinator: LexiMenuBarCoordinator

    var body: some Scene {
        WindowGroup("Lexi", id: "reader") {
            ReaderWindowContent(coordinator: coordinator)
                .background(LexiMenuBarBootstrap(coordinator: coordinator))
        }
        .defaultSize(width: 1200, height: 760)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}

private enum ReaderSurface {
    case shelf
    case reader
}

private struct ScrollPersistenceContext: Sendable {
    let database: AppDatabase
    let bookId: String
    let chapterIndex: Int
    let paragraphIndex: Int
    let bookProgress: Double
}

struct ReaderResumeTarget: Equatable, Sendable {
    let chapterIndex: Int
    let paragraphIndex: Int?

    static func resolve(
        continueReading: Bool,
        progress: ProgressRecord?,
        chapters: [ReaderChapter]
    ) -> ReaderResumeTarget {
        guard continueReading,
              let progress,
              chapters.indices.contains(progress.chapterIdx) else {
            return ReaderResumeTarget(chapterIndex: 0, paragraphIndex: nil)
        }

        let paragraphIndex = ReaderScrollProgressResolver.validParagraphIndex(
            from: progress.scrollPct,
            paragraphCount: chapters[progress.chapterIdx].paragraphs.count
        )
        return ReaderResumeTarget(chapterIndex: progress.chapterIdx, paragraphIndex: paragraphIndex)
    }
}

struct ReaderScrollProgressResolver {
    static func validParagraphIndex(from rawValue: Double, paragraphCount: Int) -> Int? {
        guard rawValue.isFinite, rawValue >= 0 else {
            return nil
        }

        let index = Int(rawValue)
        guard (0..<paragraphCount).contains(index) else {
            return nil
        }

        return index
    }

    static func preferredParagraphIndex(
        visibleIndex: Int?,
        lastKnownIndex: Int?,
        pendingIndex: Int?,
        paragraphCount: Int
    ) -> Int {
        bestKnownParagraphIndex(
            visibleIndex: visibleIndex,
            lastKnownIndex: lastKnownIndex,
            pendingIndex: pendingIndex,
            paragraphCount: paragraphCount
        ) ?? 0
    }

    static func bestKnownParagraphIndex(
        visibleIndex: Int?,
        lastKnownIndex: Int?,
        pendingIndex: Int?,
        paragraphCount: Int
    ) -> Int? {
        guard paragraphCount > 0 else {
            return nil
        }

        for candidate in [visibleIndex, lastKnownIndex, pendingIndex] {
            guard let candidate, (0..<paragraphCount).contains(candidate) else {
                continue
            }
            return candidate
        }

        return nil
    }
}

private struct ReaderWindowContent: View {
    @ObservedObject var coordinator: LexiMenuBarCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var systemAppearance = SystemColorSchemeObserver()
    @State private var selectedChapterIndex = 2
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var surface = ReaderSurface.shelf
    @State private var database: AppDatabase?
    @State private var shelfBooks: [ReaderBook] = []
    @State private var book: ReaderBook?
    @State private var chapters: [ReaderChapter] = []
    @State private var controller: ChapterTranslationController?
    @State private var loadError: String?
    @State private var toast: ToastMessage?
    @State private var cacheClearCandidate: ReaderBook?
    @State private var cacheClearMB = "0.0"
    @State private var removeCandidate: ReaderBook?
    @State private var showsSettings = false
    @State private var showsVocab = false
    @State private var vocabBookFilter = VocabBookFilter.all
    @State private var visibleParagraphId: Int64?
    @State private var pendingScrollParagraphIdx: Int?
    @State private var lastKnownScrollParagraphIndex: Int?
    @State private var selectedTextContext: SelectedTextContext?
    @State private var scrollWriteTask: Task<Void, Never>?
    @AppStorage(LexiDefaultsKey.readerFontSize) private var fontSize = 17.0
    @AppStorage(LexiDefaultsKey.readerTranslationMode) private var transModeRaw = ReaderTranslationMode.both.rawValue
    @AppStorage(LexiDefaultsKey.readerPrefetch) private var prefetchCount = 1
    @AppStorage(LexiDefaultsKey.readerSerif) private var serif = "New York"
    @AppStorage(LexiDefaultsKey.readerLineHeight) private var lineHeight = "normal"
    @AppStorage(LexiDefaultsKey.readerTheme) private var theme = ReaderThemeMode.system.storageValue
    @AppStorage(LexiDefaultsKey.readerAccent) private var accent = "copper"
    @AppStorage(LexiDefaultsKey.readerTranslationStyle) private var translationStyle = ReaderTranslationStyle.demote.rawValue
    @AppStorage(LexiDefaultsKey.readerParagraphLayout) private var paragraphLayoutRaw = ReaderParagraphLayout.defaultValue.rawValue
    @AppStorage(LexiDefaultsKey.generalStartup) private var startupBehavior = "last"

    private var preferences: ReaderRuntimePreferences {
        ReaderRuntimePreferences(
            serif: serif,
            lineHeight: lineHeight,
            theme: themeMode.storageValue,
            accent: accent,
            translationStyle: translationStyle,
            paragraphLayout: paragraphLayoutRaw,
            systemColorScheme: systemAppearance.colorScheme
        )
    }

    private var themeMode: ReaderThemeMode {
        ReaderThemeMode(storageValue: theme)
    }

    private var transMode: ReaderTranslationMode {
        ReaderTranslationMode(rawValue: transModeRaw) ?? .both
    }

    private var paragraphLayout: ReaderParagraphLayout {
        ReaderParagraphLayout(storageValue: paragraphLayoutRaw)
    }

    private var transModeBinding: Binding<ReaderTranslationMode> {
        Binding {
            transMode
        } set: { next in
            transModeRaw = next.rawValue
        }
    }

    private var paragraphLayoutBinding: Binding<ReaderParagraphLayout> {
        Binding {
            paragraphLayout
        } set: { next in
            paragraphLayoutRaw = next.rawValue
        }
    }

    private var selectedChapter: ReaderChapter? {
        chapters[safe: selectedChapterIndex]
    }

    private var selectedChapterIndexBinding: Binding<Int> {
        Binding {
            selectedChapterIndex
        } set: { nextIndex in
            selectChapter(at: nextIndex)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            content
                .task(loadInitialData)
                .onChange(of: selectedChapterIndex) { _, _ in
                    visibleParagraphId = nil
                    translateSelectedChapter()
                }
                .readerShortcuts(
                    toggleTranslationMode: { transModeRaw = transMode.next.rawValue },
                    previousChapter: previousChapter,
                    nextChapter: nextChapter,
                    increaseFontSize: { fontSize = min(22, fontSize + 1) },
                    decreaseFontSize: { fontSize = max(14, fontSize - 1) },
                    toggleSidebar: toggleSidebar,
                    addWordToVocab: addSelectedWordToVocab
                )

            ToastView(message: toast, preferences: preferences)
        }
        .background(
            ReaderWindowTitleUpdater(
                title: windowTitle,
                isReaderSurface: surface == .reader
            )
        )
        .background(WindowAppearanceUpdater(colorScheme: themeMode.preferredColorScheme))
        .background(ReaderWindowCloseBehavior(willClose: flushVisibleScrollProgress))
        .background(preferences.theme.paper)
        .preferredColorScheme(themeMode.preferredColorScheme)
        .onChange(of: theme) { _, _ in
            systemAppearance.refresh()
        }
        .frame(minWidth: 920, minHeight: 620)
        .confirmationDialog(
            "清除翻译缓存？",
            isPresented: Binding(
                get: { cacheClearCandidate != nil },
                set: { if !$0 { cacheClearCandidate = nil } }
            ),
            presenting: cacheClearCandidate
        ) { candidate in
            Button("清除 \(cacheClearMB) MB", role: .destructive) {
                clearCache(for: candidate)
            }
            Button("取消", role: .cancel) {}
        } message: { candidate in
            Text("\(candidate.title) 的缓存译文会被删除。")
        }
        .confirmationDialog(
            "从书架移除？",
            isPresented: Binding(
                get: { removeCandidate != nil },
                set: { if !$0 { removeCandidate = nil } }
            ),
            presenting: removeCandidate
        ) { candidate in
            Button("移除", role: .destructive) {
                removeBook(candidate)
            }
            Button("取消", role: .cancel) {}
        } message: { candidate in
            Text("\(candidate.title) 会从本地书架移除，原 EPUB 文件不会被删除。")
        }
        .sheet(isPresented: $showsSettings) {
            SettingsSheet(
                database: database,
                close: { showsSettings = false },
                showToast: showToast
            )
        }
        .sheet(isPresented: $showsVocab) {
            VocabView(
                database: database,
                initialBookFilter: vocabBookFilter,
                close: { showsVocab = false },
                showToast: showToast,
                onChanged: { coordinator.refreshCounts() }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiOpenSettings)) { _ in
            showsSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiOpenVocab)) { _ in
            openGlobalVocab()
        }
        .onChange(of: coordinator.hasPendingVocabOpenRequest) { _, pending in
            guard pending else {
                return
            }
            presentPendingVocabIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiEngineSettingsChanged)) { _ in
            applyEngineSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiChapterEngineSettingsChanged)) { _ in
            applyEngineSettings()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else {
                return
            }
            flushVisibleScrollProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            flushVisibleScrollProgress()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text(loadError)
                .font(LexiFont.zh(13))
                .foregroundStyle(Color.lexiWarn)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch surface {
            case .shelf:
                ShelfView(
                    books: shelfBooks,
                    currentBookID: book?.id,
                    openBook: { openBook($0, continueReading: false) },
                    continueReading: { openBook($0, continueReading: true) },
                    openVocab: openVocab,
                    openAllVocab: openAllVocab,
                    revealInFinder: revealInFinder,
                    requestClearCache: requestClearCache,
                    requestRemove: { removeCandidate = $0 },
                    importEPUBs: importEPUBs
                )
                .toolbar {
                    ShelfTitleBar(
                        canReturnToReader: book != nil,
                        returnToReader: resumeReaderFromShelf
                    )
                }

            case .reader:
                readerContent
            }
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        if let book, let selectedChapter, let controller {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    HStack(spacing: 0) {
                        if columnVisibility != .detailOnly {
                            TOCSidebar(
                                book: book,
                                chapters: chapters,
                                selectedChapterIndex: selectedChapterIndexBinding,
                                chapterState: { chapterId in
                                    controller.chapterState(for: chapterId)
                                },
                                preferences: preferences,
                                openShelf: returnToShelf
                            )
                        }

                        ReadingColumn(
                            bookTitle: book.title,
                            chapter: selectedChapter,
                            previousChapter: chapters[safe: selectedChapterIndex - 1],
                            nextChapter: chapters[safe: selectedChapterIndex + 1],
                            fontSize: fontSize,
                            snapshot: controller.snapshot(for: selectedChapter.id),
                            transMode: transMode,
                            preferences: preferences,
                            visibleParagraphId: $visibleParagraphId,
                            selectedTextContext: $selectedTextContext,
                            goToPreviousChapter: previousChapter,
                            goToNextChapter: nextChapter,
                            onParagraphChange: handleVisibleParagraphChange
                        ) { paragraph in
                            controller.retryParagraph(paragraph, in: selectedChapter, bookTitle: book.title)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(preferences.theme.paper)
                        .tint(preferences.accent.primary)
                    }

                    ReaderChromeOverlay(
                        columnVisibility: $columnVisibility,
                        bookTitle: book.title,
                        transMode: transModeBinding,
                        paragraphLayout: paragraphLayoutBinding,
                        themeMode: themeMode,
                        preferences: preferences,
                        cycleThemeMode: cycleThemeMode,
                        openVocab: { openVocab(for: book) },
                        openSettings: { showsSettings = true },
                        sidebarVisible: columnVisibility != .detailOnly
                    )
                }
                .toolbar(removing: .sidebarToggle)

                ReaderProgressHairline(
                    progress: Double(chapterProgress) / 100,
                    preferences: preferences
                )

                ReaderStatusBar(
                    chapterProgress: chapterProgress,
                    bookProgress: bookProgress,
                    state: controller.chapterState(for: selectedChapter.id),
                    preferences: preferences
                )
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(preferences.theme.paper)
        }
    }

    private var windowTitle: String {
        switch surface {
        case .shelf:
            return "书架"
        case .reader:
            guard let book, let selectedChapter else {
                return "Lexi"
            }
            return "\(book.title) · Chapter \(selectedChapter.n) · \(selectedChapterIndex + 1) / \(chapters.count)"
        }
    }

    private var chapterProgress: Int {
        guard let selectedChapter, let controller else {
            return 0
        }
        let state = controller.chapterState(for: selectedChapter.id)
        let done = state == .cached ? selectedChapter.paragraphs.count : state.done
        guard !selectedChapter.paragraphs.isEmpty else {
            return 0
        }
        return Int((Double(done) / Double(selectedChapter.paragraphs.count) * 100).rounded())
    }

    private var bookProgress: Int {
        guard !chapters.isEmpty else {
            return 0
        }
        return Int((((Double(selectedChapterIndex) + Double(chapterProgress) / 100) / Double(chapters.count)) * 100).rounded())
    }

    private func loadInitialData() async {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        guard database == nil else {
            return
        }

        do {
            let sharedDatabase = try AppDatabase.makeShared()
            database = sharedDatabase
            try await reloadShelf(from: sharedDatabase)

            switch startupBehavior {
            case "shelf":
                surface = .shelf
            case "none":
                surface = .shelf
            default:
                if let lastBook = shelfBooks.first(where: { $0.lastReadAt != nil }) ?? shelfBooks.first {
                    await loadBook(lastBook, from: sharedDatabase, continueReading: true)
                } else {
                    surface = .shelf
                }
            }
            presentPendingVocabIfNeeded()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func reloadShelf(from database: AppDatabase) async throws {
        let books = try await database.books()
        shelfBooks = books.map(ReaderBook.init(book:))
    }

    private func openBook(_ nextBook: ReaderBook, continueReading: Bool) {
        guard let database else {
            return
        }

        Task {
            await loadBook(nextBook, from: database, continueReading: continueReading)
        }
    }

    private func loadBook(_ nextBook: ReaderBook, from database: AppDatabase, continueReading: Bool) async {
        do {
            let loaded = try await ReaderFixtureStore.loadExistingBook(bookId: nextBook.id, from: database)
            let engineConfig = await EnginePreferences.chapterConfig(database: database)
            let nextController = ChapterTranslationController(database: database, engineConfig: engineConfig)
            visibleParagraphId = nil
            pendingScrollParagraphIdx = nil
            lastKnownScrollParagraphIndex = nil
            book = loaded.0
            chapters = loaded.1
            controller = nextController
            coordinator.setActiveReaderBook(id: loaded.0.id, title: loaded.0.title)

            let target = ReaderResumeTarget.resolve(
                continueReading: continueReading,
                progress: try await database.progress(for: nextBook.id),
                chapters: loaded.1
            )
            selectedChapterIndex = target.chapterIndex
            pendingScrollParagraphIdx = target.paragraphIndex
            lastKnownScrollParagraphIndex = target.paragraphIndex

            try await database.touchBook(id: nextBook.id)
            await nextController.prepare(chapters: loaded.1)
            surface = .reader
            translateSelectedChapter()
            restorePendingScrollTarget()
            try await reloadShelf(from: database)
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func importEPUBs(_ urls: [URL]) {
        guard let database else {
            return
        }

        guard !urls.isEmpty else {
            showToast("EPUB 导入失败")
            return
        }

        Task {
            let parser = EPUBParser()
            for url in urls {
                do {
                    let payload = try await parser.parse(url)
                    try await database.importBook(payload)
                    try await reloadShelf(from: database)
                    showToast("已加入书架 · \(payload.book.title)")
                } catch {
                    showToast("导入失败 · \(error.localizedDescription)")
                }
            }
        }
    }

    private func revealInFinder(_ target: ReaderBook) {
        NSWorkspace.shared.activateFileViewerSelecting([target.fileURL])
    }

    private func openVocab(for target: ReaderBook) {
        vocabBookFilter = .specific(target.id)
        showsVocab = true
    }

    private func openAllVocab() {
        vocabBookFilter = .all
        showsVocab = true
    }

    private func openGlobalVocab() {
        vocabBookFilter = .global
        showsVocab = true
    }

    private func presentPendingVocabIfNeeded() {
        guard database != nil,
              coordinator.consumePendingVocabOpenRequest() else {
            return
        }
        openGlobalVocab()
    }

    private func requestClearCache(_ target: ReaderBook) {
        guard let database else {
            return
        }

        Task {
            let bytes = (try? await database.translationCacheBytes(bookId: target.id)) ?? 0
            cacheClearMB = String(format: "%.1f", Double(bytes) / 1024 / 1024)
            cacheClearCandidate = target
        }
    }

    private func clearCache(for target: ReaderBook) {
        guard let database else {
            return
        }

        Task {
            do {
                try await database.clearTranslationCache(bookId: target.id)
                cacheClearCandidate = nil
                showToast("已清除 · \(target.title)")
            } catch {
                showToast(error.localizedDescription)
            }
        }
    }

    private func removeBook(_ target: ReaderBook) {
        guard let database else {
            return
        }

        Task {
            do {
                try await database.deleteBook(id: target.id)
                if target.id == book?.id {
                    scrollWriteTask?.cancel()
                    visibleParagraphId = nil
                    pendingScrollParagraphIdx = nil
                    lastKnownScrollParagraphIndex = nil
                    book = nil
                    chapters = []
                    controller = nil
                    surface = .shelf
                }
                removeCandidate = nil
                try await reloadShelf(from: database)
                showToast("已移除 · \(target.title)")
            } catch {
                showToast(error.localizedDescription)
            }
        }
    }

    private func translateSelectedChapter() {
        guard surface == .reader, let selectedChapter, let controller else {
            return
        }
        controller.selectChapter(
            selectedChapter,
            chapters: chapters,
            prefetchCount: max(0, min(2, prefetchCount)),
            bookTitle: book?.title
        )

        guard let database, let book else {
            return
        }

        Task {
            let progress = chapters.isEmpty ? 0 : (Double(selectedChapterIndex) + Double(chapterProgress) / 100) / Double(chapters.count)
            try? await database.updateBookProgress(id: book.id, progress: progress)
            try? await database.upsertProgress(
                ProgressRecord(
                    bookId: book.id,
                    chapterIdx: selectedChapterIndex,
                    scrollPct: Double(pendingScrollParagraphIdx ?? currentParagraphIndex(in: selectedChapter)),
                    updatedAt: Date()
                )
            )
            try? await reloadShelf(from: database)
        }
    }

    private func handleVisibleParagraphChange(_ paragraphId: Int64) {
        scrollWriteTask?.cancel()
        guard let context = scrollPersistenceContext(paragraphId: paragraphId) else {
            return
        }
        lastKnownScrollParagraphIndex = context.paragraphIndex

        scrollWriteTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else {
                return
            }
            await persistScroll(context)
        }
    }

    private func flushVisibleScrollProgress() {
        flushVisibleScrollProgress {}
    }

    private func flushVisibleScrollProgress(completion: @escaping () -> Void) {
        scrollWriteTask?.cancel()
        guard let context = currentScrollPersistenceContext() else {
            completion()
            return
        }

        Task {
            await persistScroll(context)
            await MainActor.run {
                completion()
            }
        }
    }

    private func returnToShelf() {
        flushVisibleScrollProgress {
            surface = .shelf
            coordinator.clearActiveReaderBook()
        }
    }

    private func resumeReaderFromShelf() {
        if let book {
            coordinator.setActiveReaderBook(id: book.id, title: book.title)
        }
        guard let selectedChapter else {
            surface = .reader
            return
        }

        let visibleIndex = visibleParagraphId.flatMap { paragraphId in
            selectedChapter.paragraphs.firstIndex(where: { $0.id == paragraphId })
        }
        guard let paragraphIndex = ReaderScrollProgressResolver.bestKnownParagraphIndex(
            visibleIndex: visibleIndex,
            lastKnownIndex: lastKnownScrollParagraphIndex,
            pendingIndex: pendingScrollParagraphIdx,
            paragraphCount: selectedChapter.paragraphs.count
        ) else {
            surface = .reader
            return
        }

        pendingScrollParagraphIdx = paragraphIndex
        lastKnownScrollParagraphIndex = paragraphIndex
        visibleParagraphId = nil
        surface = .reader
        restorePendingScrollTarget()
    }

    private func scrollPersistenceContext(paragraphId: Int64) -> ScrollPersistenceContext? {
        guard let selectedChapter else {
            return nil
        }
        guard let paragraphIndex = selectedChapter.paragraphs.firstIndex(where: { $0.id == paragraphId }) else {
            return nil
        }

        return scrollPersistenceContext(paragraphIndex: paragraphIndex)
    }

    private func currentScrollPersistenceContext() -> ScrollPersistenceContext? {
        guard let selectedChapter else {
            return nil
        }

        let visibleIndex = visibleParagraphId.flatMap { paragraphId in
            selectedChapter.paragraphs.firstIndex(where: { $0.id == paragraphId })
        }
        let paragraphIndex = ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: visibleIndex,
            lastKnownIndex: lastKnownScrollParagraphIndex,
            pendingIndex: pendingScrollParagraphIdx,
            paragraphCount: selectedChapter.paragraphs.count
        )

        return scrollPersistenceContext(paragraphIndex: paragraphIndex)
    }

    private func scrollPersistenceContext(paragraphIndex: Int) -> ScrollPersistenceContext? {
        guard let database, let book, let selectedChapter else {
            return nil
        }
        guard selectedChapter.paragraphs.isEmpty || selectedChapter.paragraphs.indices.contains(paragraphIndex) else {
            return nil
        }

        let progress = chapters.isEmpty
            ? 0
            : (Double(selectedChapterIndex) + Double(paragraphIndex) / Double(max(1, selectedChapter.paragraphs.count))) / Double(chapters.count)

        return ScrollPersistenceContext(
            database: database,
            bookId: book.id,
            chapterIndex: selectedChapterIndex,
            paragraphIndex: paragraphIndex,
            bookProgress: progress
        )
    }

    private func persistScroll(_ context: ScrollPersistenceContext) async {
        let updatedAt = Date()
        try? await context.database.updateBookProgress(id: context.bookId, progress: context.bookProgress, at: updatedAt)
        try? await context.database.upsertProgress(
            ProgressRecord(
                bookId: context.bookId,
                chapterIdx: context.chapterIndex,
                scrollPct: Double(context.paragraphIndex),
                updatedAt: updatedAt
            )
        )
        updateInMemoryProgress(bookId: context.bookId, progress: context.bookProgress, at: updatedAt)
    }

    private func updateInMemoryProgress(bookId: String, progress: Double, at updatedAt: Date) {
        let clampedProgress = max(0, min(1, progress))
        if let currentBook = book, currentBook.id == bookId {
            book = currentBook.updatingProgress(clampedProgress, lastReadAt: updatedAt)
        }
        if let index = shelfBooks.firstIndex(where: { $0.id == bookId }) {
            shelfBooks[index] = shelfBooks[index].updatingProgress(clampedProgress, lastReadAt: updatedAt)
        }
    }

    private func currentParagraphIndex(in chapter: ReaderChapter) -> Int {
        let visibleIndex = visibleParagraphId.flatMap { paragraphId in
            chapter.paragraphs.firstIndex(where: { $0.id == paragraphId })
        }
        return ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: visibleIndex,
            lastKnownIndex: lastKnownScrollParagraphIndex,
            pendingIndex: pendingScrollParagraphIdx,
            paragraphCount: chapter.paragraphs.count
        )
    }

    private func restorePendingScrollTarget() {
        guard let pendingIndex = pendingScrollParagraphIdx,
              let chapter = chapters[safe: selectedChapterIndex],
              chapter.paragraphs.indices.contains(pendingIndex) else {
            pendingScrollParagraphIdx = nil
            return
        }

        lastKnownScrollParagraphIndex = pendingIndex
        let targetId = chapter.paragraphs[pendingIndex].id
        let targetChapterId = chapter.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard surface == .reader,
                  pendingScrollParagraphIdx == pendingIndex,
                  chapters[safe: selectedChapterIndex]?.id == targetChapterId else {
                return
            }
            visibleParagraphId = targetId
            lastKnownScrollParagraphIndex = pendingIndex
            pendingScrollParagraphIdx = nil
        }
    }

    private func applyEngineSettings() {
        guard let database, let selectedChapter, let controller else {
            return
        }

        Task {
            let config = await EnginePreferences.chapterConfig(database: database)
            controller.switchEngine(
                config,
                chapter: selectedChapter,
                chapters: chapters,
                prefetchCount: max(0, min(2, prefetchCount)),
                bookTitle: book?.title
            )
        }
    }

    private func previousChapter() {
        guard surface == .reader else {
            return
        }
        selectChapter(at: max(0, selectedChapterIndex - 1))
    }

    private func nextChapter() {
        guard surface == .reader else {
            return
        }
        selectChapter(at: min(max(0, chapters.count - 1), selectedChapterIndex + 1))
    }

    private func selectChapter(at index: Int) {
        let nextIndex = min(max(0, index), max(0, chapters.count - 1))
        guard nextIndex != selectedChapterIndex else {
            return
        }

        flushVisibleScrollProgress()
        visibleParagraphId = nil
        pendingScrollParagraphIdx = nil
        lastKnownScrollParagraphIndex = nil
        selectedChapterIndex = nextIndex
    }

    private func toggleSidebar() {
        guard surface == .reader else {
            return
        }
        withAnimation {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
        }
    }

    private func addSelectedWordToVocab() {
        guard surface == .reader, let database else {
            return
        }

        let context = selectedTextContext ?? SelectionMonitor.currentSelection(promptForPermission: false)
        guard let context else {
            showToast("请先选中要加入的单词")
            return
        }

        guard let candidate = ReaderAddWordCandidate(context: context) else {
            showToast("仅支持单词加入生词本")
            return
        }

        Task {
            do {
                let existing = try await database.vocabEntry(normalizedWord: candidate.word)
                if existing != nil {
                    _ = try await database.upsertVocabEntry(
                        word: candidate.word,
                        context: candidate.sentenceContext?.fullSentence,
                        primaryZh: "",
                        sensesJSON: "[]",
                        ukIPA: nil,
                        usIPA: nil,
                        exampleEN: nil,
                        exampleZH: nil,
                        bookId: book?.id
                    )
                    await MainActor.run {
                        coordinator.refreshCounts()
                        showToast("已在生词本，更新来源")
                    }
                    return
                }

                let localEntry = LocalDictionary.lookup(candidate.word)
                let sentenceContext = SentenceContext(
                    fullSentence: candidate.sentenceContext?.fullSentence,
                    bookTitle: book?.title,
                    localDictionary: localEntry
                )
                let config = await EnginePreferences.popupConfig(database: database)
                let engine = try EngineRegistry.shared.engine(for: config)
                let result = try await engine.lookup(.wordLookup(word: candidate.word, context: sentenceContext), model: config.model)
                let snapshot = VocabSnapshot.make(word: candidate.word, lookup: result, localEntry: localEntry)
                _ = try await database.upsertVocabEntry(
                    word: candidate.word,
                    context: sentenceContext.fullSentence,
                    primaryZh: snapshot.primaryZh,
                    sensesJSON: snapshot.sensesJSON,
                    ukIPA: snapshot.ukIPA,
                    usIPA: snapshot.usIPA,
                    exampleEN: snapshot.exampleEN,
                    exampleZH: snapshot.exampleZH,
                    bookId: book?.id
                )
                await MainActor.run {
                    coordinator.refreshCounts()
                    showToast("已加入生词本")
                }
            } catch {
                await MainActor.run {
                    showToast("加入生词本失败 · \(error.localizedDescription)")
                }
            }
        }
    }

    private func cycleThemeMode() {
        theme = themeMode.next.storageValue
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.16)) {
            toast = ToastMessage(text: text)
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation(.easeIn(duration: 0.16)) {
                if toast?.text == text {
                    toast = nil
                }
            }
        }
    }
}

struct ReaderAddWordCandidate: Equatable {
    let word: String
    let sentenceContext: SentenceContext?

    init?(context: SelectedTextContext) {
        let word = SelectionLookupClassifier.normalizedText(context.text)
        guard SelectionLookupClassifier.isWord(word) else {
            return nil
        }

        self.word = word
        sentenceContext = context.sentenceContext
    }
}

private struct ReaderWindowTitleUpdater: NSViewRepresentable {
    let title: String
    let isReaderSurface: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.title = title
            window.titleVisibility = isReaderSurface ? .hidden : .visible
        }
    }
}

private struct ReaderWindowCloseBehavior: NSViewRepresentable {
    let willClose: (@escaping () -> Void) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(willClose: willClose)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }
            context.coordinator.willClose = willClose
            guard window.delegate !== context.coordinator else {
                return
            }
            window.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var willClose: (@escaping () -> Void) -> Void
        private var isClosingAfterFlush = false
        private var isTerminatingAfterFlush = false

        init(willClose: @escaping (@escaping () -> Void) -> Void) {
            self.willClose = willClose
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if isClosingAfterFlush || isTerminatingAfterFlush {
                isClosingAfterFlush = false
                return true
            }

            if UserDefaults.standard.string(forKey: LexiDefaultsKey.generalOnClose) == "quit" {
                willClose {
                    self.isTerminatingAfterFlush = true
                    NSApp.terminate(nil)
                }
            } else {
                willClose { [weak sender] in
                    guard let sender else {
                        return
                    }
                    self.isClosingAfterFlush = true
                    sender.performClose(nil)
                }
            }

            return false
        }

        func windowWillClose(_ notification: Notification) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

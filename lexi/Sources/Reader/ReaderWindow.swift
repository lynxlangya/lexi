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

private struct ReaderWindowContent: View {
    @ObservedObject var coordinator: LexiMenuBarCoordinator
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var visibleParagraphId: Int64?
    @State private var pendingScrollParagraphIdx: Int?
    @State private var scrollWriteTask: Task<Void, Never>?
    @AppStorage("reader.fontSize") private var fontSize = 17.0
    @AppStorage("reader.transMode") private var transModeRaw = ReaderTranslationMode.both.rawValue
    @AppStorage("reader.prefetch") private var prefetchCount = 1
    @AppStorage("reader.serif") private var serif = "New York"
    @AppStorage("reader.lineHeight") private var lineHeight = "normal"
    @AppStorage("reader.theme") private var theme = ReaderThemeMode.system.storageValue
    @AppStorage("reader.accent") private var accent = "copper"
    @AppStorage("reader.translationStyle") private var translationStyle = ReaderTranslationStyle.demote.rawValue
    @AppStorage("general.startup") private var startupBehavior = "last"

    private var preferences: ReaderRuntimePreferences {
        ReaderRuntimePreferences(
            serif: serif,
            lineHeight: lineHeight,
            theme: themeMode.storageValue,
            accent: accent,
            translationStyle: translationStyle,
            systemColorScheme: systemColorScheme
        )
    }

    private var themeMode: ReaderThemeMode {
        ReaderThemeMode(storageValue: theme)
    }

    private var transMode: ReaderTranslationMode {
        ReaderTranslationMode(rawValue: transModeRaw) ?? .both
    }

    private var transModeBinding: Binding<ReaderTranslationMode> {
        Binding {
            transMode
        } set: { next in
            transModeRaw = next.rawValue
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
                    toggleSidebar: toggleSidebar
                )

            ToastView(message: toast, preferences: preferences)
        }
        .background(
            ReaderWindowTitleUpdater(
                title: windowTitle,
                isReaderSurface: surface == .reader
            )
        )
        .background(ReaderWindowCloseBehavior(willClose: flushVisibleScrollProgress))
        .background(preferences.theme.paper)
        .preferredColorScheme(themeMode.preferredColorScheme)
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
                close: { showsVocab = false },
                showToast: showToast,
                onChanged: { coordinator.refreshCounts() }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiOpenSettings)) { _ in
            showsSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiOpenVocab)) { _ in
            showsVocab = true
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
                    revealInFinder: revealInFinder,
                    requestClearCache: requestClearCache,
                    requestRemove: { removeCandidate = $0 },
                    importEPUBs: importEPUBs
                )
                .toolbar {
                    ShelfTitleBar(
                        canReturnToReader: book != nil,
                        returnToReader: { surface = .reader }
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
                                openShelf: { surface = .shelf }
                            )
                        }

                        ReadingColumn(
                            chapter: selectedChapter,
                            previousChapter: chapters[safe: selectedChapterIndex - 1],
                            nextChapter: chapters[safe: selectedChapterIndex + 1],
                            fontSize: fontSize,
                            snapshot: controller.snapshot(for: selectedChapter.id),
                            transMode: transMode,
                            preferences: preferences,
                            visibleParagraphId: $visibleParagraphId,
                            goToPreviousChapter: previousChapter,
                            goToNextChapter: nextChapter,
                            onParagraphChange: handleVisibleParagraphChange
                        ) { paragraph in
                            controller.retryParagraph(paragraph, in: selectedChapter)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(preferences.theme.paper)
                    }

                    ReaderChromeOverlay(
                        columnVisibility: $columnVisibility,
                        bookTitle: book.title,
                        transMode: transModeBinding,
                        themeMode: themeMode,
                        preferences: preferences,
                        cycleThemeMode: cycleThemeMode,
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
            book = loaded.0
            chapters = loaded.1
            controller = nextController

            if !continueReading {
                selectedChapterIndex = 0
            } else if continueReading,
               let progress = try await database.progress(for: nextBook.id),
               loaded.1.indices.contains(progress.chapterIdx) {
                selectedChapterIndex = progress.chapterIdx
                pendingScrollParagraphIdx = validParagraphIndex(from: progress.scrollPct, in: loaded.1[progress.chapterIdx])
            } else if selectedChapterIndex >= loaded.1.count {
                selectedChapterIndex = max(0, loaded.1.count - 1)
            }

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
            prefetchCount: max(0, min(2, prefetchCount))
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
        guard let visibleParagraphId,
              let context = scrollPersistenceContext(paragraphId: visibleParagraphId) else {
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

    private func scrollPersistenceContext(paragraphId: Int64) -> ScrollPersistenceContext? {
        guard let database, let book, let selectedChapter else {
            return nil
        }
        guard let paragraphIndex = selectedChapter.paragraphs.firstIndex(where: { $0.id == paragraphId }) else {
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
        try? await context.database.updateBookProgress(id: context.bookId, progress: context.bookProgress)
        try? await context.database.upsertProgress(
            ProgressRecord(
                bookId: context.bookId,
                chapterIdx: context.chapterIndex,
                scrollPct: Double(context.paragraphIndex),
                updatedAt: Date()
            )
        )
        try? await reloadShelf(from: context.database)
    }

    private func currentParagraphIndex(in chapter: ReaderChapter) -> Int {
        guard let visibleParagraphId,
              let paragraphIndex = chapter.paragraphs.firstIndex(where: { $0.id == visibleParagraphId }) else {
            return 0
        }

        return paragraphIndex
    }

    private func validParagraphIndex(from rawValue: Double, in chapter: ReaderChapter) -> Int? {
        guard rawValue.isFinite, rawValue >= 0 else {
            return nil
        }

        let index = Int(rawValue)
        guard chapter.paragraphs.indices.contains(index) else {
            return nil
        }

        return index
    }

    private func restorePendingScrollTarget() {
        guard let pendingIndex = pendingScrollParagraphIdx,
              let chapter = chapters[safe: selectedChapterIndex],
              chapter.paragraphs.indices.contains(pendingIndex) else {
            pendingScrollParagraphIdx = nil
            return
        }

        let targetId = chapter.paragraphs[pendingIndex].id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard pendingScrollParagraphIdx != nil else {
                return
            }
            visibleParagraphId = targetId
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
                prefetchCount: max(0, min(2, prefetchCount))
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

            if UserDefaults.standard.string(forKey: "general.onClose") == "quit" {
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

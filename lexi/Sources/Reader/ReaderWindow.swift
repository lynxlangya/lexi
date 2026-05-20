import SwiftUI
import AppKit

struct ReaderWindow: Scene {
    var body: some Scene {
        WindowGroup("Lexi") {
            ReaderWindowContent()
        }
        .defaultSize(width: 1200, height: 760)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

private struct ReaderWindowContent: View {
    @State private var selectedChapterIndex = 2
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var book: ReaderBook?
    @State private var chapters: [ReaderChapter] = []
    @State private var controller: ChapterTranslationController?
    @State private var loadError: String?
    @AppStorage("reader.fontSize") private var fontSize = 17.0
    @AppStorage("reader.transMode") private var transModeRaw = ReaderTranslationMode.both.rawValue
    @AppStorage("reader.prefetch") private var prefetchCount = 1

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

    var body: some View {
        content
            .task(loadReaderData)
            .onChange(of: selectedChapterIndex) { _, _ in
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
        .background(
            ReaderWindowTitleUpdater(
                title: windowTitle
            )
        )
        .background(Color.lexiPaper)
        .frame(minWidth: 920, minHeight: 620)
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text(loadError)
                .font(LexiFont.zh(13))
                .foregroundStyle(Color.lexiWarn)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let book, let selectedChapter, let controller {
            VStack(spacing: 0) {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    TOCSidebar(
                        book: book,
                        chapters: chapters,
                        selectedChapterIndex: $selectedChapterIndex
                    ) { chapterId in
                        controller.chapterState(for: chapterId)
                    }
                    .navigationSplitViewColumnWidth(min: 232, ideal: 232, max: 232)
                    .toolbar(removing: .sidebarToggle)
                } detail: {
                    ReadingColumn(
                        chapter: selectedChapter,
                        fontSize: fontSize,
                        snapshot: controller.snapshot(for: selectedChapter.id),
                        transMode: transMode
                    ) { paragraph in
                        controller.retryParagraph(paragraph, in: selectedChapter)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.lexiPaper)
                }
                .navigationSplitViewStyle(.balanced)
                .toolbar {
                    ReaderToolbar(
                        columnVisibility: $columnVisibility,
                        bookTitle: book.title,
                        chapter: selectedChapter,
                        chapterIndex: selectedChapterIndex,
                        chapterCount: chapters.count,
                        fontSize: $fontSize,
                        transMode: transModeBinding
                    )
                }
                .toolbar(removing: .sidebarToggle)

                ReaderProgressHairline(progress: Double(chapterProgress) / 100)

                ReaderStatusBar(
                    chapterProgress: chapterProgress,
                    bookProgress: bookProgress,
                    state: controller.chapterState(for: selectedChapter.id),
                    engineLabel: controller.engineLabel,
                    total: selectedChapter.paragraphs.count
                )
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var windowTitle: String {
        guard let book, let selectedChapter else {
            return "Lexi"
        }
        return "\(book.title) · Chapter \(selectedChapter.n) · \(selectedChapterIndex + 1) / \(chapters.count)"
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

    private func loadReaderData() async {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        guard book == nil, chapters.isEmpty else {
            return
        }

        do {
            let database = try AppDatabase.makeShared()
            let loaded = try await ReaderFixtureStore.loadBook(from: database)
            let engineConfig = ReaderFixtureStore.defaultConfig()
            let nextController = ChapterTranslationController(database: database, engineConfig: engineConfig)
            book = loaded.0
            chapters = loaded.1
            controller = nextController
            if selectedChapterIndex >= loaded.1.count {
                selectedChapterIndex = max(0, loaded.1.count - 1)
            }
            await nextController.prepare(chapters: loaded.1)
            translateSelectedChapter()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func translateSelectedChapter() {
        guard let selectedChapter, let controller else {
            return
        }
        controller.selectChapter(
            selectedChapter,
            chapters: chapters,
            prefetchCount: max(0, min(2, prefetchCount))
        )
    }

    private func previousChapter() {
        selectedChapterIndex = max(0, selectedChapterIndex - 1)
    }

    private func nextChapter() {
        selectedChapterIndex = min(max(0, chapters.count - 1), selectedChapterIndex + 1)
    }

    private func toggleSidebar() {
        withAnimation {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
        }
    }
}

private struct ReaderWindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.title = title
            window.titleVisibility = .visible
        }
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

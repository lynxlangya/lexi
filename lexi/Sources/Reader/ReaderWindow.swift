import SwiftUI

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
    @AppStorage("reader.fontSize") private var fontSize = 17.0

    private var selectedChapter: DemoChapter {
        DemoData.chapters[selectedChapterIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                TOCSidebar(
                    chapters: DemoData.chapters,
                    selectedChapterIndex: $selectedChapterIndex
                )
                .navigationSplitViewColumnWidth(min: 232, ideal: 232, max: 232)
                .toolbar(removing: .sidebarToggle)
            } detail: {
                ReadingColumn(chapter: selectedChapter, fontSize: fontSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.lexiPaper)
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ReaderToolbar(
                    columnVisibility: $columnVisibility,
                    bookTitle: DemoData.bookTitle,
                    chapter: selectedChapter,
                    chapterIndex: selectedChapterIndex,
                    chapterCount: DemoData.chapters.count,
                    fontSize: $fontSize
                )
            }
            .toolbar(removing: .sidebarToggle)

            ReaderProgressHairline(progress: 0.34)

            ReaderStatusBar(
                chapterProgress: 34,
                bookProgress: bookProgress
            )
        }
        .background(Color.lexiPaper)
        .frame(minWidth: 920, minHeight: 620)
    }

    private var bookProgress: Int {
        Int((((Double(selectedChapterIndex) + 0.34) / Double(DemoData.chapters.count)) * 100).rounded())
    }
}

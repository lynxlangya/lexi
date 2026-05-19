import AppKit
import SwiftUI

struct ReaderWindow: Scene {
    var body: some Scene {
        WindowGroup("Lexi") {
            ReaderWindowContent()
                .background(ReaderWindowConfigurator())
        }
        .defaultSize(width: 1200, height: 760)
    }
}

private struct ReaderWindowContent: View {
    @State private var selectedChapterIndex = 2
    @AppStorage("reader.fontSize") private var fontSize = 17.0

    private var selectedChapter: DemoChapter {
        DemoData.chapters[selectedChapterIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            ReaderToolbar(
                bookTitle: DemoData.bookTitle,
                chapter: selectedChapter,
                chapterIndex: selectedChapterIndex,
                chapterCount: DemoData.chapters.count,
                fontSize: $fontSize
            )

            NavigationSplitView {
                TOCSidebar(
                    chapters: DemoData.chapters,
                    selectedChapterIndex: $selectedChapterIndex
                )
                .navigationSplitViewColumnWidth(min: 232, ideal: 232, max: 232)
            } detail: {
                ReadingColumn(chapter: selectedChapter, fontSize: fontSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.lexiPaper)
            }
            .navigationSplitViewStyle(.balanced)
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

private struct ReaderWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, !context.coordinator.didConfigure else {
                return
            }

            window.title = "Lexi"
            window.styleMask.insert([.titled, .fullSizeContentView])
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbar = nil
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 920, height: 620)
            window.setContentSize(NSSize(width: 1200, height: 760))

            context.coordinator.didConfigure = true
        }
    }

    final class Coordinator {
        var didConfigure = false
    }
}

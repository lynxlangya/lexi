import SwiftUI

struct ReaderToolbar: ToolbarContent {
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let bookTitle: String
    let chapter: ReaderChapter
    let chapterIndex: Int
    let chapterCount: Int
    @Binding var fontSize: Double
    @Binding var transMode: ReaderTranslationMode

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                withAnimation {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                }
            } label: {
                Image(systemName: "sidebar.leading")
            }
            .help("切换侧栏 (⌘0)")
            .focusable(false)
        }

        ToolbarSpacer(.flexible, placement: .primaryAction)

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                fontSize = max(14, fontSize - 1)
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .help("缩小字号")
            .focusable(false)

            Button {
                fontSize = min(22, fontSize + 1)
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .help("放大字号")
            .focusable(false)

            Button {
                transMode = transMode.next
            } label: {
                Image(systemName: "character.bubble")
            }
            .help(transModeHelp)
            .focusable(false)

            Button(action: {}) {
                Image(systemName: "gearshape")
            }
            .help("翻译引擎")
            .focusable(false)

            Button(action: {}) {
                Image(systemName: "moon")
            }
            .help("主题")
            .focusable(false)

            Button(action: {}) {
                Image(systemName: "ellipsis")
            }
            .help("更多")
            .focusable(false)
        }
    }

    private var transModeHelp: String {
        switch transMode {
        case .both:
            return "原文 + 译文 (⌘B)"
        case .en:
            return "仅原文 (⌘B)"
        case .zh:
            return "仅译文 (⌘B)"
        }
    }
}

import SwiftUI

struct ReaderChromeOverlay: View {
    private let sidebarWidth: CGFloat = 232
    private let chromeTop: CGFloat = 4
    private let trafficLightTrailing: CGFloat = 82

    @Binding var columnVisibility: NavigationSplitViewVisibility
    let bookTitle: String
    let chapter: ReaderChapter
    let chapterIndex: Int
    let chapterCount: Int
    @Binding var fontSize: Double
    @Binding var transMode: ReaderTranslationMode
    let preferences: ReaderRuntimePreferences
    let openSettings: () -> Void
    let sidebarVisible: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                sidebarToggle
                    .padding(.top, chromeTop)
                    .padding(.leading, trafficLightTrailing)

                contentTitle
                    .padding(.top, 15)
                    .padding(.leading, titleLeading(in: proxy.size.width))

                HStack {
                    Spacer()
                    controlCluster
                }
                .padding(.top, chromeTop)
                .padding(.trailing, 13)
            }
            .frame(width: proxy.size.width, height: 58, alignment: .topLeading)
        }
        .frame(height: 58)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
    }

    private func titleLeading(in width: CGFloat) -> CGFloat {
        let sidebarOffset = sidebarVisible ? sidebarWidth : 0
        let detailWidth = max(0, width - sidebarOffset)
        let readableWidth = max(0, detailWidth - LexiSpacing.windowPad * 2)
        let centeredInset = max(0, (readableWidth - LexiSpacing.contentMax) / 2)
        let leading = sidebarOffset + LexiSpacing.windowPad + centeredInset
        return max(leading, trafficLightTrailing + 34)
    }

    private var sidebarToggle: some View {
        ChromeIconButton(
            systemName: "sidebar.leading",
            help: "切换侧栏 (⌘0)",
            preferences: preferences
        ) {
            withAnimation(.easeInOut(duration: 0.16)) {
                columnVisibility = columnVisibility == .all ? .detailOnly : .all
            }
        }
    }

    private var contentTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bookTitle)
                .font(LexiFont.sans(12.5))
                .fontWeight(.semibold)
                .foregroundStyle(preferences.theme.ink)
                .lineLimit(1)

            Text("Chapter \(chapter.n) · \(chapterIndex + 1) / \(chapterCount)")
                .font(LexiFont.mono(10.5))
                .foregroundStyle(preferences.theme.ink3)
                .lineLimit(1)
        }
        .padding(.top, 1)
    }

    private var controlCluster: some View {
        HStack(spacing: 1) {
            chromeButton("textformat.size.smaller", help: "缩小字号") {
                fontSize = max(14, fontSize - 1)
            }

            chromeButton("textformat.size.larger", help: "放大字号") {
                fontSize = min(22, fontSize + 1)
            }

            chromeButton("translate", help: transModeHelp) {
                transMode = transMode.next
            }

            chromeButton("moon", help: "主题") {}

            chromeButton("gearshape", help: "设置", action: openSettings)
        }
    }

    private func chromeButton(
        _ systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        ChromeIconButton(
            systemName: systemName,
            help: help,
            preferences: preferences,
            action: action
        )
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

private struct ChromeIconButton: View {
    let systemName: String
    let help: String
    let preferences: ReaderRuntimePreferences
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? preferences.theme.ink : preferences.theme.ink2)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? preferences.theme.raised : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isHovering ? preferences.theme.rule : Color.clear, lineWidth: 1)
        }
        .help(help)
        .focusable(false)
        .onHover { isHovering = $0 }
    }
}

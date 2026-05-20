import SwiftUI

struct ReaderChromeOverlay: View {
    private let sidebarWidth: CGFloat = 232
    private let chromeTop: CGFloat = 7
    private let headerHeight: CGFloat = 48
    private let trafficLightTrailing: CGFloat = 82

    @Binding var columnVisibility: NavigationSplitViewVisibility
    let bookTitle: String
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
            .frame(width: proxy.size.width, height: headerHeight, alignment: .topLeading)
        }
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(preferences.theme.rule.opacity(0.72))
                .frame(height: 1)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
    }

    private func titleLeading(in width: CGFloat) -> CGFloat {
        let sidebarOffset = sidebarVisible ? sidebarWidth : 0
        let leading = sidebarOffset + 18
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
        Text(bookTitle)
            .font(LexiFont.sans(13.5))
            .fontWeight(.semibold)
            .foregroundStyle(preferences.theme.ink)
            .lineLimit(1)
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
                .font(.system(size: 12.5, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 26, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? preferences.accent.primary : preferences.theme.ink)
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

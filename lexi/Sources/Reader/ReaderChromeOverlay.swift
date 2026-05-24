import SwiftUI

struct ReaderChromeOverlay: View {
    private let sidebarWidth: CGFloat = 232
    private let chromeTop: CGFloat = 5
    private let headerHeight: CGFloat = 42
    private let trafficLightTrailing: CGFloat = 82

    @Binding var columnVisibility: NavigationSplitViewVisibility
    let bookTitle: String
    @Binding var transMode: ReaderTranslationMode
    @Binding var paragraphLayout: ReaderParagraphLayout
    let themeMode: ReaderThemeMode
    let preferences: ReaderRuntimePreferences
    let readAloudStatus: ReadAloudPlaybackStatus
    let cycleThemeMode: () -> Void
    let openReadAloud: () -> Void
    let openVocab: () -> Void
    let openSettings: () -> Void
    let sidebarVisible: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(preferences.theme.paper)
                    .frame(width: max(0, proxy.size.width - contentLeading), height: headerHeight)
                    .padding(.leading, contentLeading)

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

                Rectangle()
                    .fill(preferences.theme.rule.opacity(0.72))
                    .frame(width: max(0, proxy.size.width - contentLeading), height: 1)
                    .padding(.top, headerHeight - 1)
                    .padding(.leading, contentLeading)
            }
            .frame(width: proxy.size.width, height: headerHeight, alignment: .topLeading)
        }
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
    }

    private var contentLeading: CGFloat {
        sidebarVisible ? sidebarWidth : 0
    }

    private func titleLeading(in width: CGFloat) -> CGFloat {
        let leading = contentLeading + 18
        return max(leading, trafficLightTrailing + 34)
    }

    private var sidebarToggle: some View {
        ChromeIconButton(
            systemName: "sidebar.leading",
            help: "切换侧栏 (⌘0)",
            preferences: preferences,
            iconSize: 11,
            buttonSize: 22,
            normalColor: preferences.theme.ink2
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
            readAloudButton

            chromeButton("translate", help: transModeHelp) {
                transMode = transMode.next
            }

            chromeButton(paragraphLayout.iconName, help: paragraphLayoutHelp) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    paragraphLayout = paragraphLayout.next
                }
            }

            chromeButton(themeMode.iconName, help: themeModeHelp, action: cycleThemeMode)

            chromeButton("text.book.closed", help: "生词本", action: openVocab)

            chromeButton("gearshape", help: "设置", action: openSettings)
        }
    }

    private var readAloudButton: some View {
        ChromeIconButton(
            systemName: readAloudIcon,
            help: readAloudHelp,
            preferences: preferences,
            iconSize: 13,
            isActive: readAloudStatus.isActive,
            isError: readAloudStatus.isError,
            action: openReadAloud
        )
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

    private var readAloudIcon: String {
        if readAloudStatus.isError {
            return "exclamationmark.triangle.fill"
        }
        if readAloudStatus.isLoading {
            return "waveform"
        }
        if readAloudStatus.canPause {
            return "speaker.wave.2.fill"
        }
        if readAloudStatus.canResume {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.2"
    }

    private var readAloudHelp: String {
        if readAloudStatus.canPause {
            return "朗读中，点击暂停"
        }
        if readAloudStatus.canResume {
            return "继续朗读"
        }
        if readAloudStatus.isLoading {
            return readAloudStatus.label
        }
        if readAloudStatus.isError {
            return readAloudStatus.label
        }
        return "从当前位置开始朗读"
    }

    private var themeModeHelp: String {
        "主题：\(themeMode.label)，点击切换到 \(themeMode.next.label)"
    }

    private var paragraphLayoutHelp: String {
        "段落布局：\(paragraphLayout.label)，点击切换到 \(paragraphLayout.nextLabel)"
    }
}

private struct ChromeIconButton: View {
    let systemName: String
    let help: String
    let preferences: ReaderRuntimePreferences
    let action: () -> Void
    var iconSize: CGFloat = 12.5
    var buttonSize: CGFloat = 26
    var normalColor: Color?
    var isActive = false
    var isError = false
    @State private var isHovering = false

    init(
        systemName: String,
        help: String,
        preferences: ReaderRuntimePreferences,
        iconSize: CGFloat = 12.5,
        buttonSize: CGFloat = 26,
        normalColor: Color? = nil,
        isActive: Bool = false,
        isError: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.help = help
        self.preferences = preferences
        self.iconSize = iconSize
        self.buttonSize = buttonSize
        self.normalColor = normalColor
        self.isActive = isActive
        self.isError = isError
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isHovering ? preferences.theme.rule : Color.clear, lineWidth: 1)
        }
        .help(help)
        .focusable(false)
        .onHover { isHovering = $0 }
    }

    private var foregroundColor: Color {
        if isError {
            return .red
        }
        if isHovering || isActive {
            return preferences.accent.primary
        }
        return normalColor ?? preferences.theme.ink
    }

    private var backgroundColor: Color {
        if isActive {
            return preferences.accent.primary.opacity(isHovering ? 0.20 : 0.14)
        }
        return isHovering ? preferences.theme.raised : Color.clear
    }
}

private extension ReadAloudPlaybackStatus {
    var isLoading: Bool {
        switch self {
        case .planning, .preparingStyle, .generating:
            return true
        case .idle, .playing, .paused, .fallback, .error:
            return false
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

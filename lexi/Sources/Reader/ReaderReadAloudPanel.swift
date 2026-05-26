import SwiftUI

enum ReaderReadAloudPanelMode: Equatable {
    case nowReading
    case chapters
}

struct ReaderReadAloudPanel: View {
    let book: ReaderBook
    let chapter: ReaderChapter
    let chapters: [ReaderChapter]
    let selectedChapterIndex: Int
    @Binding var language: TTSAudioLanguage
    @Binding var showsText: Bool
    @Binding var mode: ReaderReadAloudPanelMode
    @Binding var showsReadingPane: Bool
    let status: ReadAloudPlaybackStatus
    let progress: ReadAloudPlaybackProgress
    let currentHighlight: ReadAloudHighlightTarget?
    let canMoveToPreviousChapter: Bool
    let canMoveToNextChapter: Bool
    let preferences: ReaderRuntimePreferences
    let providerName: String
    let primaryAction: () -> Void
    let previousChunk: () -> Void
    let nextChunk: () -> Void
    let previousChapter: () -> Void
    let nextChapter: () -> Void
    let chapterState: (ReaderChapter) -> ChapterTranslationState
    let selectChapter: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            fixedControls

            ScrollView {
                contentBlock
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(ReaderScrollViewStyler(preferences: preferences, background: panelBackground))
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.automatic)
            .background(panelBackground)
        }
        .frame(width: panelWidth)
        .frame(maxWidth: panelMaxWidth, maxHeight: .infinity)
        .background(panelBackground)
        .overlay(alignment: .leading) {
            if showsReadingPane {
                Rectangle()
                    .fill(preferences.theme.rule)
                    .frame(width: 1)
            }
        }
    }

    private var panelWidth: CGFloat? {
        showsReadingPane ? 336 : nil
    }

    private var panelMaxWidth: CGFloat? {
        showsReadingPane ? nil : .infinity
    }

    private var contentMaxWidth: CGFloat? {
        showsReadingPane ? nil : 392
    }

    private var panelBackground: Color {
        showsReadingPane ? preferences.theme.raised : preferences.theme.paper
    }

    private var fixedControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            progressBlock
            playbackControls
            toolRow
        }
        .frame(maxWidth: contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 18)
        .padding(.top, 58)
        .padding(.bottom, 12)
        .background(panelBackground)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            BookCover(
                book: book,
                width: 82,
                height: 122,
                cornerRadius: 3,
                shadowRadius: 0,
                shadowYOffset: 0
            )
            .shadow(color: .black.opacity(preferences.theme.isDark ? 0.26 : 0.12), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 8) {
                Text("朗读")
                    .font(LexiFont.zh(11))
                    .foregroundStyle(preferences.theme.ink3)
                    .textCase(.uppercase)

                Text(book.title)
                    .font(LexiFont.sans(15))
                    .fontWeight(.semibold)
                    .foregroundStyle(preferences.theme.ink)
                    .lineLimit(2)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(LexiFont.serif(12))
                        .italic()
                        .foregroundStyle(preferences.theme.ink2)
                        .lineLimit(1)
                }

                Text("Chapter \(chapter.n) · \(chapter.title)")
                    .font(LexiFont.zh(11.5))
                    .foregroundStyle(preferences.theme.ink3)
                    .lineLimit(2)

                statusBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(LexiFont.zh(11))
                .foregroundStyle(preferences.theme.ink2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(preferences.theme.paper.opacity(preferences.theme.isDark ? 0.52 : 0.68))
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(preferences.theme.rule)
                    Capsule(style: .continuous)
                        .fill(preferences.accent.primary)
                        .frame(width: proxy.size.width * progressValue)
                }
            }
            .frame(height: 4)

            HStack {
                Text(progressLeadingLabel)
                Spacer()
                Text(progressTrailingLabel)
            }
            .font(LexiFont.mono(10.5))
            .foregroundStyle(preferences.theme.ink3)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 14) {
            panelIconButton(
                "backward.end",
                help: "上一章并开始朗读",
                isEnabled: canMoveToPreviousChapter,
                action: previousChapter
            )
            panelIconButton(
                "backward.fill",
                help: "上一段",
                isEnabled: progress.canMovePrevious,
                action: previousChunk
            )

            Button(action: primaryAction) {
                Image(systemName: primaryIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(preferences.theme.paper)
                    .background {
                        Circle()
                            .fill(preferences.accent.primary)
                    }
            }
            .buttonStyle(.plain)
            .help(primaryHelp)
            .accessibilityLabel(primaryHelp)
            .focusable(false)

            panelIconButton(
                "forward.fill",
                help: "下一段",
                isEnabled: progress.canMoveNext,
                action: nextChunk
            )
            panelIconButton(
                "forward.end",
                help: "下一章并开始朗读",
                isEnabled: canMoveToNextChapter,
                action: nextChapter
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            panelToggleButton(
                "textformat.abc",
                help: "朗读原文",
                isSelected: language == .source
            ) {
                language = .source
            }

            panelToggleButton(
                "translate",
                help: "朗读译文",
                isSelected: language == .target
            ) {
                language = .target
            }

            Spacer(minLength: 4)

            panelToggleButton(
                showsText ? "eye" : "eye.slash",
                help: showsText ? "隐藏朗读文字" : "显示朗读文字",
                isSelected: showsText
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    showsText.toggle()
                }
            }

            panelToggleButton(
                showsReadingPane ? "sidebar.right" : "sidebar.left",
                help: showsReadingPane ? "关闭阅读面板" : "显示阅读面板",
                isSelected: !showsReadingPane
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showsReadingPane.toggle()
                }
            }

            panelToggleButton(
                mode == .chapters ? "list.bullet.circle.fill" : "list.bullet",
                help: "章节列表",
                isSelected: mode == .chapters
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    mode = mode == .chapters ? .nowReading : .chapters
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(preferences.theme.paper.opacity(preferences.theme.isDark ? 0.42 : 0.68))
        }
    }

    @ViewBuilder
    private var contentBlock: some View {
        switch mode {
        case .nowReading:
            nowReadingBlock
        case .chapters:
            chaptersBlock
        }
    }

    private var nowReadingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("正在朗读")
                .font(LexiFont.zh(12))
                .foregroundStyle(preferences.theme.ink3)

            if showsText {
                Text(currentText)
                    .font(currentTextFont)
                    .fontWeight(.semibold)
                    .lineSpacing(6)
                    .foregroundStyle(preferences.theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 14)
                    .padding(.leading, 14)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(preferences.accent.faint)
                    }
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(preferences.accent.primary)
                            .frame(width: 3)
                            .padding(.vertical, 10)
                    }
            } else {
                Text("文字已隐藏，朗读会继续。")
                    .font(LexiFont.zh(12))
                    .foregroundStyle(preferences.theme.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(preferences.theme.paper.opacity(preferences.theme.isDark ? 0.36 : 0.62))
                    }
            }
        }
    }

    private var chaptersBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("章节")
                    .font(LexiFont.zh(12))
                    .foregroundStyle(preferences.theme.ink3)

                Spacer()

                Text(language == .source ? "朗读原文" : "朗读译文")
                    .font(LexiFont.zh(10.5))
                    .foregroundStyle(preferences.theme.ink3)
            }

            LazyVStack(spacing: 6) {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, item in
                    chapterRow(item, index: index)
                }
            }
        }
    }

    private func chapterRow(_ item: ReaderChapter, index: Int) -> some View {
        let state = readAloudChapterStatus(for: item, index: index)
        let isSelected = index == selectedChapterIndex

        return Button {
            selectChapter(index)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(item.n)
                    .font(LexiFont.mono(11))
                    .foregroundStyle(isSelected ? preferences.accent.primary : preferences.theme.ink3)
                    .frame(width: 24, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(LexiFont.zh(12.5))
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? preferences.theme.ink : preferences.theme.ink2)
                        .lineLimit(1)

                    Text(state.label)
                        .font(LexiFont.zh(10.5))
                        .foregroundStyle(state.foregroundColor(preferences: preferences))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Circle()
                    .fill(state.color(preferences: preferences))
                    .frame(width: isSelected ? 7 : 5, height: isSelected ? 7 : 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? preferences.accent.soft : preferences.theme.paper.opacity(preferences.theme.isDark ? 0.32 : 0.58))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? preferences.accent.primary.opacity(0.28) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("从 Chapter \(item.n) 开始朗读")
        .accessibilityLabel("从 Chapter \(item.n) 开始朗读，\(state.label)")
        .focusable(false)
    }

    private func panelIconButton(
        _ systemName: String,
        help: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? preferences.theme.ink : preferences.theme.ink4)
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
        .focusable(false)
    }

    private func panelToggleButton(
        _ systemName: String,
        help: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? preferences.accent.primary : preferences.theme.ink2)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? preferences.accent.primary.opacity(0.14) : Color.clear)
        }
        .help(help)
        .accessibilityLabel(help)
        .focusable(false)
    }

    private var statusText: String {
        switch status {
        case .idle:
            return "\(providerName) · 就绪 · \(languageLabel)"
        case .planning, .preparingStyle, .generating:
            return "\(providerName) · 准备中 · \(languageLabel)"
        case .playing:
            return "\(providerName) · 自然清晰 · \(languageLabel)"
        case .paused:
            return "\(providerName) · 已暂停 · \(languageLabel)"
        case .fallback(_, let reason):
            return "\(reason) · 系统朗读 · \(languageLabel)"
        case .error:
            return "朗读失败 · \(languageLabel)"
        }
    }

    private var statusColor: Color {
        switch status {
        case .error:
            return Color.red
        case .idle:
            return preferences.theme.ink4
        case .planning, .preparingStyle, .generating:
            return Color.orange
        case .playing, .fallback:
            return Color.green
        case .paused:
            return preferences.accent.primary
        }
    }

    private var progressValue: CGFloat {
        CGFloat(progress.fraction)
    }

    private var progressLeadingLabel: String {
        if let currentRange = progress.currentRange, status.isActive {
            return currentRange
        }
        return status.isActive ? "朗读中" : "未开始"
    }

    private var progressTrailingLabel: String {
        progress.displayText
    }

    private var primaryIcon: String {
        if status.canPause {
            return "pause.fill"
        }
        return "play.fill"
    }

    private var primaryHelp: String {
        if status.canPause {
            return "暂停朗读"
        }
        if status.canResume {
            return "继续朗读"
        }
        return "开始朗读"
    }

    private var languageLabel: String {
        language == .source ? "原文" : "译文"
    }

    private var currentText: String {
        guard let currentHighlight,
              currentHighlight.chapterId == chapter.id,
              currentHighlight.language == language,
              !currentHighlight.text.isEmpty else {
            return emptyText
        }
        return currentHighlight.text
    }

    private var emptyText: String {
        language == .source
            ? "点击播放后，这里会显示正在朗读的原文。"
            : "点击播放后，这里会显示正在朗读的译文。"
    }

    private var currentTextFont: Font {
        switch language {
        case .source:
            return preferences.sourceFont.serif(18)
        case .target:
            return Font(preferences.targetFont.nsFont(16))
        }
    }

    private func readAloudChapterStatus(for item: ReaderChapter, index: Int) -> ReadAloudChapterRowStatus {
        if index == selectedChapterIndex, status.isActive {
            return .current
        }
        switch language {
        case .source:
            return item.paragraphs.isEmpty ? .unavailable("无可朗读原文") : .available("可朗读原文")
        case .target:
            switch chapterState(item) {
            case .cached:
                return .available("译文已缓存")
            case .translating:
                return .pending("译文缓存中")
            case .error:
                return .unavailable("译文缓存失败")
            case .idle:
                return .unavailable("译文未缓存")
            }
        }
    }
}

private enum ReadAloudChapterRowStatus {
    case current
    case available(String)
    case pending(String)
    case unavailable(String)

    var label: String {
        switch self {
        case .current:
            return "正在朗读"
        case .available(let label), .pending(let label), .unavailable(let label):
            return label
        }
    }

    func color(preferences: ReaderRuntimePreferences) -> Color {
        switch self {
        case .current:
            return preferences.accent.primary
        case .available:
            return Color.green.opacity(0.82)
        case .pending:
            return Color.orange.opacity(0.82)
        case .unavailable:
            return preferences.theme.ink4
        }
    }

    func foregroundColor(preferences: ReaderRuntimePreferences) -> Color {
        switch self {
        case .current:
            return preferences.accent.primary
        case .available, .pending:
            return preferences.theme.ink3
        case .unavailable:
            return preferences.theme.ink4
        }
    }
}

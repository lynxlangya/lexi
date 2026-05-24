import SwiftUI

enum ReaderReadAloudPanelMode: Equatable {
    case nowReading
    case chapters
}

struct ReaderReadAloudPanel: View {
    let book: ReaderBook
    let chapter: ReaderChapter
    @Binding var language: TTSAudioLanguage
    @Binding var showsText: Bool
    @Binding var mode: ReaderReadAloudPanelMode
    let status: ReadAloudPlaybackStatus
    let preferences: ReaderRuntimePreferences
    let close: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    progressBlock
                    playbackControls
                    toolRow
                    contentBlock
                }
                .padding(.horizontal, 18)
                .padding(.top, 58)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 362)
        .frame(maxHeight: .infinity)
        .background(preferences.theme.raised)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(preferences.theme.rule)
                .frame(width: 1)
        }
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
            panelIconButton("backward.end", help: "上一章", isEnabled: false) {}
            panelIconButton("backward.fill", help: "上一段", isEnabled: false) {}

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
            .focusable(false)

            panelIconButton("forward.fill", help: "下一段", isEnabled: false) {}
            panelIconButton("forward.end", help: "下一章", isEnabled: false) {}
        }
        .frame(maxWidth: .infinity)
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            panelToggleButton(
                language == .source ? "textformat.abc.circle.fill" : "textformat.abc",
                help: "朗读原文",
                isSelected: language == .source
            ) {
                language = .source
            }

            panelToggleButton(
                language == .target ? "translate.circle.fill" : "translate",
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

            panelToggleButton("xmark", help: "关闭朗读器", isSelected: false, action: close)

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
            chaptersPlaceholder
        }
    }

    private var nowReadingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("正在朗读")
                .font(LexiFont.zh(12))
                .foregroundStyle(preferences.theme.ink3)

            if showsText {
                Text(sampleText)
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

    private var chaptersPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("章节")
                .font(LexiFont.zh(12))
                .foregroundStyle(preferences.theme.ink3)

            VStack(alignment: .leading, spacing: 8) {
                Text("章节列表将在下一步接入。")
                    .font(LexiFont.zh(12))
                    .foregroundStyle(preferences.theme.ink2)

                Text("当前章节 · Chapter \(chapter.n)")
                    .font(LexiFont.mono(11))
                    .foregroundStyle(preferences.accent.primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(preferences.theme.paper.opacity(preferences.theme.isDark ? 0.36 : 0.62))
            }
        }
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
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? preferences.accent.primary : preferences.theme.ink2)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? preferences.accent.soft : Color.clear)
        }
        .help(help)
        .focusable(false)
    }

    private var statusText: String {
        switch status {
        case .idle:
            return "豆包语音 · 就绪 · \(languageLabel)"
        case .planning, .preparingStyle, .generating:
            return "豆包语音 · 准备中 · \(languageLabel)"
        case .playing:
            return "豆包语音 · 自然清晰 · \(languageLabel)"
        case .paused:
            return "豆包语音 · 已暂停 · \(languageLabel)"
        case .fallback:
            return "系统朗读 · \(languageLabel)"
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
        status.isActive ? 0.26 : 0
    }

    private var progressLeadingLabel: String {
        status.isActive ? "朗读中" : "未开始"
    }

    private var progressTrailingLabel: String {
        status.isActive ? "本章" : "等待"
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

    private var sampleText: String {
        switch language {
        case .source:
            return chapter.paragraphs.first?.en ?? "Open a chapter to start reading aloud."
        case .target:
            return "译文朗读将在下一步接入当前段落。"
        }
    }

    private var currentTextFont: Font {
        switch language {
        case .source:
            return preferences.sourceFont.serif(18)
        case .target:
            return Font(preferences.targetFont.nsFont(16))
        }
    }
}

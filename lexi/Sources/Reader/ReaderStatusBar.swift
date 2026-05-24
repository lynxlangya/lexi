import SwiftUI

struct ReaderProgressHairline: View {
    let progress: Double
    let preferences: ReaderRuntimePreferences

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                preferences.theme.rule
                preferences.accent.primary
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 1)
    }
}

struct ReaderStatusBar: View {
    let chapterProgress: Int
    let bookProgress: Int
    let state: ChapterTranslationState
    let readAloudStatus: ReadAloudPlaybackStatus
    let preferences: ReaderRuntimePreferences

    var body: some View {
        HStack {
            Text("全书 \(bookProgress)%")
                .font(LexiFont.mono(11))
                .foregroundStyle(preferences.theme.ink3)

            Spacer()

            if readAloudStatus != .idle {
                Text(readAloudStatus.label)
                    .font(LexiFont.zh(11))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .padding(.trailing, 10)
            }

            ChapterCacheDot(state: state, preferences: preferences)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(preferences.theme.chrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(preferences.theme.rule)
                .frame(height: 1)
        }
    }

    private var statusColor: Color {
        switch readAloudStatus {
        case .error:
            return Color.lexiWarn
        case .fallback:
            return preferences.theme.ink2
        case .idle, .planning, .generating, .playing, .paused:
            return preferences.accent.primary
        }
    }
}

private struct ChapterCacheDot: View {
    let state: ChapterTranslationState
    let preferences: ReaderRuntimePreferences
    @State private var isDimmed = false
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor.opacity(dotOpacity))
                .frame(width: 7, height: 7)
        }
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
        .help(helpText)
        .accessibilityLabel(helpText)
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Text(helpText)
                    .font(LexiFont.zh(11))
                    .foregroundStyle(preferences.theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(preferences.theme.raised)
                            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(preferences.theme.rule, lineWidth: 1)
                    }
                    .fixedSize()
                    .offset(y: -28)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .onAppear(perform: updateAnimation)
        .onChange(of: animationKey) { _, _ in
            updateAnimation()
        }
    }

    private var dotColor: Color {
        switch state {
        case .idle:
            return preferences.theme.ink4
        case .translating:
            return Color.green
        case .cached:
            return Color.green
        case .error:
            return Color.red
        }
    }

    private var dotOpacity: Double {
        if case .translating = state {
            return isDimmed ? 0.35 : 1
        }
        return 1
    }

    private var helpText: String {
        switch state {
        case .idle:
            return "等待翻译"
        case .translating:
            return "正在缓存"
        case .cached:
            return "本章已缓存"
        case .error:
            return "缓存失败"
        }
    }

    private var animationKey: String {
        switch state {
        case .idle:
            return "idle"
        case .translating:
            return "translating"
        case .cached:
            return "cached"
        case .error:
            return "error"
        }
    }

    private func updateAnimation() {
        if case .translating = state {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isDimmed = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.12)) {
                isDimmed = false
            }
        }
    }
}

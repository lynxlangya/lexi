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
    let engineLabel: String
    let total: Int
    let preferences: ReaderRuntimePreferences

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if case .translating = state {
                    SpinnerDot(size: 10, accent: preferences.accent.primary)
                }

                Text(statusText)
                    .font(LexiFont.sans(11.5))
                    .foregroundStyle(preferences.theme.ink3)
            }

            Spacer()

            Text("\(chapterProgress)% · 全书 \(bookProgress)%")
                .font(LexiFont.mono(11))
                .foregroundStyle(preferences.theme.ink3)
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

    private var statusText: String {
        switch state {
        case .idle:
            return "等待翻译 · \(engineLabel)"
        case .translating(let done):
            return "正在翻译 · \(engineLabel) · \(done)/\(total)"
        case .cached:
            return "本章已缓存 · \(engineLabel)"
        case .error:
            return "翻译失败 · \(engineLabel)"
        }
    }
}

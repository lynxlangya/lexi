import SwiftUI

struct ReaderProgressHairline: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.lexiRule
                Color.lexiAccent
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

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if case .translating = state {
                    SpinnerDot(size: 10)
                }

                Text(statusText)
                    .font(LexiFont.sans(11.5))
                    .foregroundStyle(Color.lexiInk3)
            }

            Spacer()

            Text("\(chapterProgress)% · 全书 \(bookProgress)%")
                .font(LexiFont.mono(11))
                .foregroundStyle(Color.lexiInk3)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(Color.lexiChrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.lexiRule)
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

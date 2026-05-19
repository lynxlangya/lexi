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

    var body: some View {
        HStack {
            Text("本章已缓存 · GPT-4")
                .font(LexiFont.sans(11.5))
                .foregroundStyle(Color.lexiInk3)

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
}

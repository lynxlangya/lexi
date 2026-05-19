import SwiftUI

struct ChapterHeader: View {
    let chapter: DemoChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chapter \(chapter.n)")
                .font(LexiFont.mono(11))
                .foregroundStyle(Color.lexiAccent)
                .textCase(.uppercase)

            Text(chapter.title)
                .font(LexiFont.serif(24))
                .foregroundStyle(Color.lexiInk)
                .lineSpacing(24 * 0.32)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

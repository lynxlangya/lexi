import SwiftUI

struct ChapterHeader: View {
    let chapter: ReaderChapter
    let preferences: ReaderRuntimePreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chapter \(chapter.n)")
                .font(LexiFont.mono(11))
                .foregroundStyle(preferences.accent.primary)
                .textCase(.uppercase)

            Text(chapter.title)
                .font(preferences.font.serif(24))
                .foregroundStyle(preferences.theme.ink)
                .lineSpacing(24 * 0.32)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
